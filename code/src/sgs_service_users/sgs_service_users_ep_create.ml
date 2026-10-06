let src = Logs.Src.create "ep_create"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common

module Sql = struct
  let insert_user_with_password () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ [%blob "./sql/insert_user_with_password.sql"]
      /% Var.(text "name")
      /% Var.(option (text "email"))
      /% Var.(text "type")
      /% Var.(option (text "password_hash"))
      /% Var.json "capability_trie")
end

let run' db ~actor_caps admin_user name email password is_instance_admin =
  let open Fc.Infix_result_monad in
  (* Validate password (now required) *)
  (Abb.Future.return
  @@
  match Sgs_user_password.validate_strength password with
  | Ok () -> Ok (Sgs_user_password.hash password)
  | Error msg -> Error (`Msg msg))
  >>= fun password_hash ->
  Sgs_user.caps_for ~admin:(if is_instance_admin then `Instance else `No) db
  >>= fun capabilities ->
  (* The new user joins the creator's tenants, less any the creator's grant does not reach.  Without
     the filter a confined creator would put users into tenants it cannot then act on, since the
     authority test holds it to the tenants its grant covers.

     Settled before the insert, because [run'] holds no transaction of its own: refusing afterwards
     would leave the user row behind with no tenant at all -- which is the very thing being refused,
     and a user nobody's grant is confined to, so anyone holding [users-manage] could act on it. *)
  Sgs_tenant.list_by_user admin_user db
  >>= fun tenants ->
  (match
     CCList.filter
       (fun tenant ->
         let tenant_id = Uuidm.to_string (Sgs_tenant.id tenant) in
         Sg_caps_ops.grants_tenant actor_caps `Admin ~tenant:tenant_id
         || Sg_caps_ops.grants_tenant actor_caps `Users_manage ~tenant:tenant_id)
       tenants
   with
    | [] -> Abbs_fc.return_err `Forbidden_no_tenant_in_scope_err
    | tenants -> Abbs_fc.return_ok tenants)
  >>= fun tenants ->
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.insert_user_with_password ())
    ~f:CCFun.id
    name
    email
    "user"
    (Some password_hash)
    (Sg_caps_json.to_json capabilities)
  >>= function
  | id :: _ ->
      let new_user = Sgs_user.make ~id () in
      Fc.List_result.iter ~f:(fun tenant -> Sgs_tenant.add_user tenant new_user db) tenants
      >>| fun () ->
      let response =
        {
          Sgs_api_components_user_create_response.id = Uuidm.to_string id;
          name;
          email;
          is_instance_admin;
        }
      in
      let body =
        Yojson.Safe.to_string @@ Sgs_api_components_user_create_response.to_yojson response
      in
      body
  | [] -> Abbs_fc.return_err `Internal_user_creation_failed_err

let run _config storage =
  Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.users_manage_some ~f:(fun session ->
      let user = Sgs_user_session.Session.user session in
      let actor_caps = Sgs_user_session.Session.capabilities session in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let body = Brtl_ctx.body ctx in
          match Yojson.Safe.from_string body with
          | exception _ ->
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"INVALID_REQUEST_BODY"
                   ~data:"Invalid JSON"
                   ctx)
          | json -> (
              match Sgs_api_components_user_create_request.of_yojson json with
              | Ok
                  {
                    Sgs_api_components_user_create_request.name;
                    email;
                    password;
                    is_instance_admin;
                  } -> (
                  let is_instance_admin = CCOption.get_or ~default:false is_instance_admin in
                  let admin_check =
                    if is_instance_admin then Common.instance_admin_check session
                    else Sgs_user_session.Caps.Allowed
                  in
                  match admin_check with
                  | Sgs_user_session.Caps.Denied reasons ->
                      Logs.warn (fun m ->
                          m
                            "%s : ADMIN_REQUIRED : Refused to create user %s as an installation \
                             admin"
                            (Brtl_ctx.token ctx)
                            name);
                      Abb.Future.return
                        (Brtl_ctx.set_response
                           (Brtl_rspnc.create
                              ~status:`Forbidden
                              (Sgs_user_session.Caps.denied_body reasons))
                           ctx)
                  | Sgs_user_session.Caps.Allowed -> (
                      Pgsql_pool.with_conn storage ~f:(fun db ->
                          run' db ~actor_caps user name email password is_instance_admin)
                      >>= function
                      | Ok body ->
                          Logs.info (fun m ->
                              m "%s : USER_CREATED Created user %s" (Brtl_ctx.token ctx) name);
                          Abb.Future.return
                            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Created body) ctx)
                      | Error (`Msg msg) ->
                          Logs.warn (fun m ->
                              m
                                "%s : VALIDATION_FAILED Validation failed: %s"
                                (Brtl_ctx.token ctx)
                                msg);
                          Abb.Future.return
                            (Sgs_eplib.respond_error
                               ~status:`Bad_request
                               ~id:"PASSWORD_VALIDATION_FAILED"
                               ~data:msg
                               ctx)
                      | Error (`Forbidden_no_tenant_in_scope_err as err) ->
                          Logs.warn (fun m ->
                              m
                                "%s : NO_TENANT_IN_SCOPE : Refused to create user %s in no tenant"
                                (Brtl_ctx.token ctx)
                                name);
                          Abb.Future.return (Common.respond_no_authority ~err ctx)
                      | Error `Internal_user_creation_failed_err ->
                          Logs.err (fun m ->
                              m
                                "%s : USER_CREATION_FAILED Failed to create user"
                                (Brtl_ctx.token ctx));
                          Abb.Future.return
                            (Common.respond_internal_error ~data:"Failed to create user" ctx)
                      | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                          Abb.Future.return
                            (Sgs_eplib.respond_db_err
                               ~src
                               ~body:
                                 (Sgs_eplib.error_response_body
                                    ~id:"INTERNAL_SERVER_ERROR"
                                    ~data:"Failed to create user")
                               ctx
                               err)))
              | Error msg ->
                  Abb.Future.return
                    (Sgs_eplib.respond_error
                       ~status:`Bad_request
                       ~id:"INVALID_REQUEST_BODY"
                       ~data:msg
                       ctx))))

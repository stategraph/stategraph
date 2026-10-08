let src = Logs.Src.create "ep_update"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common

module Sql = struct
  let update_user () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      //
      (* name *)
      Ret.text
      //
      (* email *)
      Ret.(option text)
      //
      (* type *)
      Ret.text
      //
      (* avatar_url *)
      Ret.(option text)
      //
      (* auth_origin *)
      Ret.(option text)
      //
      (* capability_trie *)
      Sgs_user.caps_ret
      //
      (* created_at *)
      Ret.text
      /^ [%blob "./sql/update_user.sql"]
      /% Var.(option (text "name"))
      /% Var.(option (text "email"))
      /% Var.(option (text "avatar_url"))
      /% Var.uuid "user_id")
end

let run' db ~actor_caps ~user target_user_id name email avatar_url is_instance_admin =
  let open Fc.Infix_result_monad in
  Common.unless_self ~user target_user_id (fun () ->
      Common.authority_over ~actor:actor_caps db target_user_id)
  >>= fun () ->
  let update () =
    (* [authority_over] above already requires reaching every tenant, so this normally answers the
       whole list with the flag up; a concurrent membership change in between can still leave a
       tenant outside the caller's reach, which is then answered truthfully as a partial list
       rather than asserted complete. The list is read rather than written so the two cannot
       disagree. *)
    Common.visible_tenants ~actor:actor_caps ~user db target_user_id
    >>= fun visibility ->
    let tenants, tenants_complete =
      match visibility with
      | Common.Complete tenants -> (tenants, true)
      | Common.Partial { visible; withheld_count = _ } -> (visible, false)
    in
    Pgsql_io.Prepared_stmt.fetch
      db
      (Sql.update_user ())
      ~f:(fun id name email type_ avatar_url auth_origin capabilities created_at ->
        (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at))
      name
      email
      avatar_url
      target_user_id
    >>? function
    | [] -> Error `Not_found_user_err
    | (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at) :: _ ->
        let response =
          {
            Sgs_api_components_user_update_response.id = Uuidm.to_string id;
            name;
            email;
            type_;
            avatar_url;
            auth_origin;
            admin_rights = Common.admin_rights capabilities;
            capabilities = Sg_caps_json.to_wire capabilities;
            tenants = CCList.map Sgs_tenant.to_api tenants;
            tenants_complete;
            created_at;
          }
        in
        Ok (Yojson.Safe.to_string @@ Sgs_api_components_user_update_response.to_yojson response)
  in
  (* [is_instance_admin] here writes exactly what [/users/set-instance-admin] writes, and so answers
     to the same last-admin guard. The grant is written first and [update] runs in its transaction, so the row it
     returns reports the grant that was just made, and a refusal discards [name], [email] and
     [avatar_url] with it. *)
  match is_instance_admin with
  | None -> update ()
  | Some is_instance_admin ->
      Sgs_user.set_instance_admin is_instance_admin ~f:update db target_user_id

let run _config storage target_user_id =
  Sgs_user_session.with_session
    ~caps:Sgs_user_session.Caps.(or_ users_manage_some (is_user target_user_id))
    ~f:(fun session ->
      let actor_caps = Sgs_user_session.Session.capabilities session in
      let user = Sgs_user_session.Session.user session in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let body = Brtl_ctx.body ctx in
          match Sgs_api_components_user_update_request.of_yojson (Yojson.Safe.from_string body) with
          | Ok { Sgs_api_components_user_update_request.name; email; avatar_url; is_instance_admin }
            -> (
              let is_instance_admin =
                CCOption.map (fun b -> if b then `Instance_admin else `No_admin) is_instance_admin
              in
              (* [email] and [is_instance_admin] are an installation admin's to write. A caller
                 without that grant is refused the whole request. *)
              let admin_check =
                match (email, is_instance_admin) with
                | None, None -> Sgs_user_session.Caps.Allowed
                | Some _, _ | _, Some _ -> Common.instance_admin_check session
              in
              match admin_check with
              | Sgs_user_session.Caps.Denied reasons ->
                  Logs.warn (fun m ->
                      m
                        "%s : ADMIN_REQUIRED : Refused to write an admin-only field on user %s"
                        (Brtl_ctx.token ctx)
                        (Uuidm.to_string target_user_id));
                  Abb.Future.return
                    (Brtl_ctx.set_response
                       (Brtl_rspnc.create
                          ~status:`Forbidden
                          (Sgs_user_session.Caps.denied_body reasons))
                       ctx)
              | Sgs_user_session.Caps.Allowed -> (
                  Pgsql_pool.with_conn storage ~f:(fun db ->
                      run'
                        db
                        ~actor_caps
                        ~user
                        target_user_id
                        name
                        email
                        avatar_url
                        is_instance_admin)
                  >>= function
                  | Ok body ->
                      Logs.info (fun m ->
                          m
                            "%s : USER_UPDATED Updated user %s"
                            (Brtl_ctx.token ctx)
                            (Uuidm.to_string target_user_id));
                      Abb.Future.return
                        (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
                  | Error `Would_remove_last_instance_admin_err ->
                      Logs.warn (fun m ->
                          m
                            "%s : LAST_ADMIN_PROTECTED Refused to demote the last installation \
                             admin %s"
                            (Brtl_ctx.token ctx)
                            (Uuidm.to_string target_user_id));
                      Abb.Future.return
                        (Common.respond_last_admin_protected ~action:Common.Demote ctx)
                  | Error
                      (( `Forbidden_peer_or_greater_err
                       | `Forbidden_tenant_scope_err
                       | `Forbidden_no_tenant_visible_err ) as err) ->
                      Logs.warn (fun m ->
                          m
                            "%s : USER_AUTHORITY_DENIED : Refused to update user %s"
                            (Brtl_ctx.token ctx)
                            (Uuidm.to_string target_user_id));
                      Abb.Future.return (Common.respond_no_authority ~err ctx)
                  | Error `Not_found_user_err ->
                      Abb.Future.return (Common.respond_user_not_found ctx)
                  | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                      Abb.Future.return
                        (Sgs_eplib.respond_db_err
                           ~src
                           ~body:
                             (Sgs_eplib.error_response_body
                                ~id:"INTERNAL_SERVER_ERROR"
                                ~data:"Failed to update user")
                           ctx
                           err)))
          | Error err ->
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"INVALID_REQUEST_BODY"
                   ~data:err
                   ctx)))

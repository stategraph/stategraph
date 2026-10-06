let src = Logs.Src.create "ep_detail"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common

module Sql = struct
  let select_user_detail () =
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
      /^ [%blob "./sql/select_user_detail.sql"]
      /% Var.uuid "user_id")
end

let run _config storage target_user_id =
  Sgs_user_session.with_session
    ~caps:Sgs_user_session.Caps.(or_ users_manage_some (is_user target_user_id))
    ~f:(fun session ->
      let actor_caps = Sgs_user_session.Session.capabilities session in
      let user = Sgs_user_session.Session.user session in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              let open Fc.Infix_result_monad in
              Common.visible_tenants ~actor:actor_caps ~user db target_user_id
              >>= fun visibility ->
              let tenants, tenants_complete =
                match visibility with
                | Common.Complete tenants -> (tenants, true)
                | Common.Partial { visible; withheld_count = _ } -> (visible, false)
              in
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.select_user_detail ())
                ~f:(fun id name email type_ avatar_url auth_origin capabilities created_at ->
                  (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at))
                target_user_id
              >>? function
              | [] -> Error `Not_found_user_err
              | (id, name, email, type_, avatar_url, auth_origin, capabilities, created_at) :: _ ->
                  let response =
                    {
                      Sgs_api_components_user_detail_response.id = Uuidm.to_string id;
                      name;
                      email;
                      type_;
                      avatar_url;
                      auth_origin;
                      admin_rights = Common.admin_rights capabilities;
                      tenants = CCList.map Sgs_tenant.to_api tenants;
                      tenants_complete;
                      created_at;
                    }
                  in
                  Ok
                    (Yojson.Safe.to_string
                    @@ Sgs_api_components_user_detail_response.to_yojson response))
          >>= function
          | Ok body ->
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error (`Forbidden_no_tenant_visible_err as err) ->
              Logs.warn (fun m ->
                  m
                    "%s : USER_AUTHORITY_DENIED : Refused the details of user %s"
                    (Brtl_ctx.token ctx)
                    (Uuidm.to_string target_user_id));
              Abb.Future.return (Common.respond_no_authority ~err ctx)
          | Error `Not_found_user_err -> Abb.Future.return (Common.respond_user_not_found ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Abb.Future.return
                (Sgs_eplib.respond_db_err
                   ~src
                   ~body:
                     (Sgs_eplib.error_response_body
                        ~id:"INTERNAL_SERVER_ERROR"
                        ~data:"Failed to retrieve user details")
                   ctx
                   err)))

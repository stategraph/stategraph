let src = Logs.Src.create "ep_delete"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common

module Sql = struct
  let delete_user_soft () =
    Pgsql_io.Typed_sql.(
      sql // Ret.uuid /^ [%blob "./sql/delete_user_soft.sql"] /% Var.uuid "user_id")
end

let run' ~actor_caps db user target_user_id =
  let open Fc.Infix_result_monad in
  let delete () =
    Pgsql_io.Prepared_stmt.fetch db (Sql.delete_user_soft ()) ~f:CCFun.id target_user_id
    >>? function
    | [] -> Error `Not_found_user_err
    | id :: _ ->
        let response =
          { Sgs_api_components_user_delete_response.id = Uuidm.to_string id; deleted = true }
        in
        let body =
          Yojson.Safe.to_string @@ Sgs_api_components_user_delete_response.to_yojson response
        in
        Ok body
  in
  (* Cannot delete yourself *)
  (Abb.Future.return
  @@
  if Uuidm.equal (Sgs_user.id user) target_user_id then
    Error `Bad_request_cannot_delete_own_account_err
  else Ok ())
  >>= fun () ->
  Common.authority_over ~actor:actor_caps db target_user_id
  >>= fun () -> Sgs_user.guard_last_instance_admin ~f:delete db target_user_id

let run _config storage target_user_id =
  Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.users_manage_some ~f:(fun session ->
      let user = Sgs_user_session.Session.user session in
      let actor_caps = Sgs_user_session.Session.capabilities session in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db -> run' ~actor_caps db user target_user_id)
          >>= function
          | Ok body ->
              Logs.info (fun m ->
                  m
                    "%s : USER_DELETED Deleted user %s"
                    (Brtl_ctx.token ctx)
                    (Uuidm.to_string target_user_id));
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error ((`Forbidden_peer_or_greater_err | `Forbidden_tenant_scope_err) as err) ->
              Logs.warn (fun m ->
                  m
                    "%s : USER_AUTHORITY_DENIED : Refused to delete user %s"
                    (Brtl_ctx.token ctx)
                    (Uuidm.to_string target_user_id));
              Abb.Future.return (Common.respond_no_authority ~err ctx)
          | Error `Bad_request_cannot_delete_own_account_err ->
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"CANNOT_DELETE_OWN_ACCOUNT"
                   ~data:"Cannot delete your own account"
                   ctx)
          | Error `Would_remove_last_instance_admin_err ->
              Logs.warn (fun m ->
                  m
                    "%s : LAST_ADMIN_PROTECTED Refused to delete the last installation admin %s"
                    (Brtl_ctx.token ctx)
                    (Uuidm.to_string target_user_id));
              Abb.Future.return (Common.respond_last_admin_protected ~action:Common.Delete ctx)
          | Error `Not_found_user_err -> Abb.Future.return (Common.respond_user_not_found ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Abb.Future.return
                (Sgs_eplib.respond_db_err
                   ~src
                   ~body:
                     (Sgs_eplib.error_response_body
                        ~id:"INTERNAL_SERVER_ERROR"
                        ~data:"Failed to delete user")
                   ctx
                   err)))

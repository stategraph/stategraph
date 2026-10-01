let src = Logs.Src.create "service_orchestration_ep_github_app_delete"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage body =
  let module B = Sgs_api_components_github_app_delete_request in
  let app_id = Int64.of_int body.B.app_id in
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let token = Brtl_ctx.token ctx in
          if not (Sgs_service_orchestration_github_app.channel_available config) then (
            Logs.warn (fun m -> m "%s : GITHUB_APP_DELETE_UNAVAILABLE" token);
            Abb.Future.return (Sgs_service_orchestration_github_app_common.respond_unavailable ctx))
          else
            (* The id in the body is the confirmation: this destroys the only
               copy of the App's private key, and GitHub never shows a key
               twice. *)
            Pgsql_pool.with_conn storage ~f:(Sgs_service_orchestration_github_app.delete ~app_id)
            >>= function
            | Ok `Written ->
                Logs.info (fun m -> m "%s : GITHUB_APP_DELETED : app_id=%Ld" token app_id);
                Abb.Future.return
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`No_content "") ctx)
            | Ok (`Not_found | `Mismatch) ->
                Logs.warn (fun m -> m "%s : GITHUB_APP_DELETE_STALE : app_id=%Ld" token app_id);
                Abb.Future.return (Sgs_service_orchestration_github_app_common.respond_stale ctx)
            | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                Sgs_eplib.log_db_err ~src ctx err;
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))

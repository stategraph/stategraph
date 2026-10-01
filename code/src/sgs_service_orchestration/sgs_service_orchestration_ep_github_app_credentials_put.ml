let src = Logs.Src.create "service_orchestration_ep_github_app_credentials_put"

module Logs = (val Logs.src_log src : Logs.LOG)

(* The names of the fields the caller supplied, for the log line. The values
   never reach it. *)
let supplied { Sgs_service_orchestration_github_app.pem; client_secret; webhook_secret } =
  CCString.concat
    ","
    (CCList.filter_map
       (fun (name, value) -> CCOption.map (fun _ -> name) value)
       [ ("pem", pem); ("client_secret", client_secret); ("webhook_secret", webhook_secret) ])

let run config storage body =
  let module B = Sgs_api_components_github_app_credentials_request in
  let trimmed = CCOption.map CCString.trim in
  let credentials =
    {
      Sgs_service_orchestration_github_app.pem = trimmed body.B.pem;
      client_secret = trimmed body.B.client_secret;
      webhook_secret = trimmed body.B.webhook_secret;
    }
  in
  let app_id = Int64.of_int body.B.app_id in
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let token = Brtl_ctx.token ctx in
          if not (Sgs_service_orchestration_github_app.channel_available config) then (
            Logs.warn (fun m -> m "%s : GITHUB_APP_CREDENTIALS_UNAVAILABLE" token);
            Abb.Future.return (Sgs_service_orchestration_github_app_common.respond_unavailable ctx))
          else
            Pgsql_pool.with_conn
              storage
              ~f:(Sgs_service_orchestration_github_app.update_credentials ~app_id ~credentials)
            >>= function
            | Ok `Written ->
                Logs.info (fun m ->
                    m
                      "%s : GITHUB_APP_CREDENTIALS_SET : app_id=%Ld : fields=%s"
                      token
                      app_id
                      (supplied credentials));
                Abb.Future.return
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`No_content "") ctx)
            | Ok (`Not_found | `Mismatch) ->
                Logs.warn (fun m -> m "%s : GITHUB_APP_CREDENTIALS_STALE : app_id=%Ld" token app_id);
                Abb.Future.return (Sgs_service_orchestration_github_app_common.respond_stale ctx)
            | Error `No_credential_err ->
                Logs.warn (fun m -> m "%s : GITHUB_APP_CREDENTIALS_EMPTY" token);
                Abb.Future.return
                  (Sgs_eplib.respond_error
                     ~status:`Bad_request
                     ~id:"GITHUB_APP_CREDENTIALS_EMPTY"
                     ~data:"Supply the private key, the client secret or the webhook secret."
                     ctx)
            (* Decoded before the write, so a key the engine could not load never
               reaches the row. *)
            | Error `Bad_pem_err ->
                Logs.warn (fun m -> m "%s : GITHUB_APP_PEM_INVALID" token);
                Abb.Future.return
                  (Sgs_eplib.respond_error
                     ~status:`Bad_request
                     ~id:"GITHUB_APP_PEM_INVALID"
                     ~data:
                       "Paste the whole RSA private key file that GitHub generated, in PEM form."
                     ctx)
            | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                Sgs_eplib.log_db_err ~src ctx err;
                Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))

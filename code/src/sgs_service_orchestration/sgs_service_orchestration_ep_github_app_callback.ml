let src = Logs.Src.create "service_orchestration_ep_github_app_callback"

module Logs = (val Logs.src_log src : Logs.LOG)

(* A full-page navigation from GitHub, so every outcome is a redirect to the
   console with a machine-readable reason. No ~caps gate: the state token is the
   authority, bound to the instance admin who asked for the manifest. *)
let run config storage code state =
  Brtl_ep.run_json ~f:(fun ctx ->
      let open Abb.Future.Infix_monad in
      let token = Brtl_ctx.token ctx in
      (* Where the operator started: the wizard by default, or whatever console
         page the manifest signed into the state, re-checked where the Location
         is written. *)
      let redirect ?rd value =
        let location =
          Sgs_service_orchestration_github_claim_common.return_location
            ~config
            ~param:"github_app"
            ~rd
            ~value
            ctx
        in
        Abb.Future.return (Sgs_service_orchestration_common.respond_found ~location ctx)
      in
      match (code, state) with
      | None, _ | _, None ->
          Logs.warn (fun m -> m "%s : GITHUB_APP_CALLBACK_INCOMPLETE" token);
          redirect "error"
      | Some code, Some state -> (
          Pgsql_pool.with_conn storage ~f:(fun db ->
              let open Abbs_fc.Infix_result_monad in
              Sgs_user_session.Session.fetch_key db
              >>= fun keys ->
              Sgs_service_orchestration_github_app.create_from_code
                ~convert:
                  (Sgs_service_orchestration_github_app.convert
                     ~api_base:(Sgs_config.github_api_base config))
                ~keys
                ~now:(Unix.gettimeofday ())
                ~state
                ~code
                db)
          >>= function
          | Ok { Sgs_service_orchestration_github_app.user_id; app_id; slug; rd } ->
              Logs.info (fun m ->
                  m "%s : GITHUB_APP_CREATED : user=%s app_id=%Ld slug=%s" token user_id app_id slug);
              redirect ?rd "created"
          | Error (`Bad_state_err err) ->
              Logs.warn (fun m ->
                  m
                    "%s : GITHUB_APP_BAD_STATE : %a"
                    token
                    Sgs_service_orchestration_github_claim_token.pp_verify_err
                    err);
              redirect "expired"
          (* The state did not ask to replace and this server has an App, or two
             writes raced. Either way nothing here changed. *)
          | Error `Conflict_err ->
              Logs.warn (fun m -> m "%s : GITHUB_APP_CONFLICT" token);
              redirect "conflict"
          | Error (`Convert_err err) ->
              Logs.err (fun m ->
                  m
                    "%s : GITHUB_APP_CONVERSION_FAILED : %a"
                    token
                    Sgs_service_orchestration_github_app.pp_convert_err
                    err);
              redirect "error"
          | Error ((`Key_not_found_err | `Bad_signing_key_err _) as err) ->
              Sgs_eplib.log_signing_key_err ctx err;
              redirect "error"
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Sgs_eplib.log_db_err ~src ctx err;
              redirect "error"))

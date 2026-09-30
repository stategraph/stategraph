let src = Logs.Src.create "service_orchestration_ep_github_claim_start"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage tenant rd =
  (* The strongest grant a hosted self-serve user can hold. Membership of the
     tenant is enforced below; the capability alone does not prove it. *)
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          (* The console's button is a full-page navigation, so a claim that
             cannot start goes back to the console with a github_claim result
             instead of a JSON error rendered in a browser tab. *)
          let rd =
            Some (Sgs_service_orchestration_github_claim_common.redirect_target ~config ctx rd)
          in
          let redirect result =
            Sgs_service_orchestration_github_claim_common.redirect_with ~config ~rd ~result ctx
          in
          if not (Sgs_config.orchestration_enabled config) then (
            Sgs_service_orchestration_github_claim_common.log_unavailable
              ~src
              ctx
              `Orchestration_disabled;
            redirect `Unavailable)
          else
            Pgsql_pool.with_conn storage ~f:(fun db ->
                let open Abbs_fc.Infix_result_monad in
                Sgs_tenant.enforce_user user tenant db
                >>= fun () -> Sgs_service_orchestration_github_claim_common.keys_and_oauth config db)
            >>= function
            | Ok (_, None) ->
                Sgs_service_orchestration_github_claim_common.log_unavailable
                  ~src
                  ctx
                  `Oauth_not_configured;
                redirect `Unavailable
            | Ok (keys, Some github_oauth) ->
                let state =
                  Sgs_service_orchestration_github_claim_token.State.mint
                    ~signer:(Sgs_user_session.Session.Keys.signer keys)
                    ~now:(Unix.gettimeofday ())
                    ~user_id:(Uuidm.to_string (Sgs_user.id user))
                    ~tenant_id:(Uuidm.to_string (Sgs_tenant.id tenant))
                    ~rd
                    ()
                in
                (* No scope parameter: this is a GitHub App user-to-server
                   authorization, so what the token may read is fixed by the
                   App's declared permissions, not by anything we ask for
                   here. The host comes from configuration, never from the
                   request. *)
                let location =
                  Printf.sprintf
                    "%s/login/oauth/authorize?client_id=%s&redirect_uri=%s&state=%s"
                    (Sgs_config.github_oauth_web_base github_oauth)
                    (Uri.pct_encode
                       ~component:`Query_value
                       (Sgs_config.github_oauth_client_id github_oauth))
                    (Uri.pct_encode
                       ~component:`Query_value
                       (Sgs_config.public_callback_base config
                       ^ Sgs_service_orchestration_github_app.claim_callback_path))
                    (Uri.pct_encode ~component:`Query_value state)
                in
                Logs.info (fun m ->
                    m
                      "%s : GITHUB_CLAIM_START : tenant=%a user=%a"
                      (Brtl_ctx.token ctx)
                      Uuidm.pp
                      (Sgs_tenant.id tenant)
                      Uuidm.pp
                      (Sgs_user.id user));
                Abb.Future.return (Sgs_service_orchestration_common.respond_found ~location ctx)
            | Error (`User_not_in_tenant_err _ as err) ->
                Sgs_eplib.log_tenant_access_denied ctx err;
                redirect `Not_member
            | Error (#Sgs_service_orchestration_github_claim_common.fault_err as err) ->
                Sgs_service_orchestration_github_claim_common.redirect_fault
                  ~src
                  ~config
                  ~rd
                  ctx
                  err))

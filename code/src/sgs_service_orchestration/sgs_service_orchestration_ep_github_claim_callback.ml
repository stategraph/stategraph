let src = Logs.Src.create "service_orchestration_ep_github_claim_callback"

module Logs = (val Logs.src_log src : Logs.LOG)

let run' config storage ctx code state =
  let open Abb.Future.Infix_monad in
  let redirect ?proof ~rd result =
    Sgs_service_orchestration_github_claim_common.redirect_with ?proof ~config ~rd ~result ctx
  in
  let fault ~rd err =
    Sgs_service_orchestration_github_claim_common.redirect_fault ~src ~config ~rd ctx err
  in
  if not (Sgs_config.orchestration_enabled config) then (
    Sgs_service_orchestration_github_claim_common.log_unavailable ~src ctx `Orchestration_disabled;
    redirect ~rd:None `Unavailable)
  else
    match (code, state) with
    (* GitHub sends the user here after an app installation too, with
       installation_id and setup_action but no state. There is no handshake
       to finish and the code that may ride along is bound to nobody, so it
       is ignored: the browser is put back on the claim screen, which offers
       to start a real handshake. Answered without a read, so an install
       still lands well while the database is unreachable. *)
    | _, None ->
        Logs.info (fun m -> m "%s : GITHUB_CLAIM_NO_STATE" (Brtl_ctx.token ctx));
        redirect ~rd:None `Installed
    (* A state without a code is not something GitHub produces; treat it as
       a mangled return rather than trying to make sense of it. *)
    | None, Some _ ->
        Logs.warn (fun m -> m "%s : GITHUB_CLAIM_NO_CODE" (Brtl_ctx.token ctx));
        redirect ~rd:None `Error
    | Some code, Some state -> (
        Pgsql_pool.with_conn
          storage
          ~f:(Sgs_service_orchestration_github_claim_common.keys_and_oauth config)
        >>= function
        | Ok (_, None) ->
            Sgs_service_orchestration_github_claim_common.log_unavailable
              ~src
              ctx
              `Oauth_not_configured;
            redirect ~rd:None `Unavailable
        | Ok (keys, Some github_oauth) -> (
            match
              Sgs_service_orchestration_github_claim_token.State.verify
                ~verifiers:(Sgs_user_session.Session.Keys.rs256_verifiers keys)
                ~now:(Unix.gettimeofday ())
                state
            with
            | Ok
                {
                  Sgs_service_orchestration_github_claim_token.State.user_id;
                  tenant_id;
                  rd;
                  exp = _;
                } -> (
                Sgs_service_orchestration_github_identity.prove ~config:github_oauth code
                >>= function
                | Ok [] ->
                    Logs.info (fun m ->
                        m "%s : GITHUB_CLAIM_NO_ADMIN : user=%s" (Brtl_ctx.token ctx) user_id);
                    redirect ~rd `No_admin
                | Ok github_installation_ids -> (
                    Pgsql_pool.with_conn storage ~f:(fun db ->
                        Sgs_service_orchestration_github_installations.list_claimable
                          ~github_installation_ids
                          db)
                    >>= function
                    | Ok claimable ->
                        let core_ids =
                          CCList.map
                            (fun c ->
                              Uuidm.to_string
                                c
                                  .Sgs_service_orchestration_github_installations
                                   .installation_core_id)
                            claimable
                        in
                        let proof =
                          Sgs_service_orchestration_github_claim_token.Proof.mint
                            ~signer:(Sgs_user_session.Session.Keys.signer keys)
                            ~now:(Unix.gettimeofday ())
                            ~user_id
                            ~tenant_id
                            ~installation_core_ids:core_ids
                            ()
                        in
                        Logs.info (fun m ->
                            m
                              "%s : GITHUB_CLAIM_PROVEN : user=%s tenant=%s proven=%d claimable=%d"
                              (Brtl_ctx.token ctx)
                              user_id
                              tenant_id
                              (CCList.length github_installation_ids)
                              (CCList.length core_ids));
                        redirect ~proof ~rd `Ready
                    | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) -> fault ~rd err)
                (* Reads GitHub could not answer: most often the App is
                   missing organization members:read, which no user action
                   can fix. Distinct result so the console can say so. *)
                | Error `Forbidden_err ->
                    Logs.err (fun m ->
                        m "%s : GITHUB_CLAIM_FORBIDDEN : user=%s" (Brtl_ctx.token ctx) user_id);
                    redirect ~rd `Forbidden
                | Error (#Sgs_service_orchestration_github_identity.err as err) ->
                    Logs.err (fun m ->
                        m
                          "%s : GITHUB_CLAIM_GITHUB_ERROR : %a"
                          (Brtl_ctx.token ctx)
                          Sgs_service_orchestration_github_identity.pp_err
                          err);
                    redirect ~rd `Error)
            (* A bad state is the signature of a forged or replayed
               handshake, so it is logged as such and tells the user nothing
               beyond "start again". *)
            | Error err ->
                Logs.warn (fun m ->
                    m
                      "%s : GITHUB_CLAIM_BAD_STATE : %a"
                      (Brtl_ctx.token ctx)
                      Sgs_service_orchestration_github_claim_token.pp_verify_err
                      err);
                redirect ~rd:None `Expired)
        | Error (#Sgs_service_orchestration_github_claim_common.fault_err as err) ->
            fault ~rd:None err)

let run config storage code state =
  (* No ~caps gate: the state token is the authority here, and it is bound to
     the user and tenant that started the handshake. *)
  Brtl_ep.run_json ~f:(fun ctx -> run' config storage ctx code state)

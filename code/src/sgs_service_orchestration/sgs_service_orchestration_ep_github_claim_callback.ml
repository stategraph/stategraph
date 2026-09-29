let src = Logs.Src.create "service_orchestration_ep_github_claim_callback"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage code state =
  (* No ~caps gate: the state token is the authority here, and it is bound to
     the user and tenant that started the handshake. *)
  Brtl_ep.run_json ~f:(fun ctx ->
      let open Abb.Future.Infix_monad in
      match (Sgs_service_orchestration_github_claim_common.availability config, code, state) with
      | ((`Orchestration_disabled | `Oauth_not_configured) as reason), _, _ ->
          Sgs_service_orchestration_github_claim_common.log_unavailable ~src ctx reason;
          Sgs_service_orchestration_github_claim_common.redirect_with
            ~config
            ~rd:None
            ~result:`Unavailable
            ctx
      | _, _, None ->
          (* GitHub sends the user here after an app installation too, with
             installation_id and setup_action but no state. There is no
             handshake to finish and the code that may ride along is bound to
             nobody, so it is ignored: the browser is put back on the claim
             screen, which offers to start a real handshake. *)
          Logs.info (fun m -> m "%s : GITHUB_CLAIM_NO_STATE" (Brtl_ctx.token ctx));
          Sgs_service_orchestration_github_claim_common.redirect_with
            ~config
            ~rd:None
            ~result:`Installed
            ctx
      | _, None, Some _ ->
          (* A state without a code is not something GitHub produces; treat it
             as a mangled return rather than trying to make sense of it. *)
          Logs.warn (fun m -> m "%s : GITHUB_CLAIM_NO_CODE" (Brtl_ctx.token ctx));
          Sgs_service_orchestration_github_claim_common.redirect_with
            ~config
            ~rd:None
            ~result:`Error
            ctx
      | `Available github_oauth, Some code, Some state -> (
          Pgsql_pool.with_conn storage ~f:(fun db -> Sgs_user_session.Session.fetch_key db)
          >>= function
          | Ok keys -> (
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
                      Sgs_service_orchestration_github_claim_common.redirect_with
                        ~config
                        ~rd
                        ~result:`No_admin
                        ctx
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
                                "%s : GITHUB_CLAIM_PROVEN : user=%s tenant=%s proven=%d \
                                 claimable=%d"
                                (Brtl_ctx.token ctx)
                                user_id
                                tenant_id
                                (CCList.length github_installation_ids)
                                (CCList.length core_ids));
                          Sgs_service_orchestration_github_claim_common.redirect_with
                            ~proof
                            ~config
                            ~rd
                            ~result:`Ready
                            ctx
                      | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                          Sgs_service_orchestration_github_claim_common.redirect_fault
                            ~src
                            ~config
                            ~rd
                            ctx
                            err)
                  | Error `Forbidden_err ->
                      (* Reads GitHub could not answer: most often the App is
                         missing organization members:read, which no user action
                         can fix. Distinct result so the console can say so. *)
                      Logs.err (fun m ->
                          m "%s : GITHUB_CLAIM_FORBIDDEN : user=%s" (Brtl_ctx.token ctx) user_id);
                      Sgs_service_orchestration_github_claim_common.redirect_with
                        ~config
                        ~rd
                        ~result:`Forbidden
                        ctx
                  | Error (#Sgs_service_orchestration_github_identity.err as err) ->
                      Logs.err (fun m ->
                          m
                            "%s : GITHUB_CLAIM_GITHUB_ERROR : %a"
                            (Brtl_ctx.token ctx)
                            Sgs_service_orchestration_github_identity.pp_err
                            err);
                      Sgs_service_orchestration_github_claim_common.redirect_with
                        ~config
                        ~rd
                        ~result:`Error
                        ctx)
              | Error err ->
                  (* A bad state is the signature of a forged or replayed
                     handshake, so it is logged as such and tells the user
                     nothing beyond "start again". *)
                  Logs.warn (fun m ->
                      m
                        "%s : GITHUB_CLAIM_BAD_STATE : %a"
                        (Brtl_ctx.token ctx)
                        Sgs_service_orchestration_github_claim_token.pp_verify_err
                        err);
                  Sgs_service_orchestration_github_claim_common.redirect_with
                    ~config
                    ~rd:None
                    ~result:`Expired
                    ctx)
          | Error (#Sgs_service_orchestration_github_claim_common.fault_err as err) ->
              Sgs_service_orchestration_github_claim_common.redirect_fault
                ~src
                ~config
                ~rd:None
                ctx
                err))

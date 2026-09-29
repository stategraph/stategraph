let src = Logs.Src.create "service_orchestration_ep_github_claim"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage tenant body =
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let { Sgs_api_components.Github_claim_request.installation_core_id } = body in
          match (Sgs_config.orchestration_enabled config, Uuidm.of_string installation_core_id) with
          | false, _ ->
              Abb.Future.return
                (Sgs_service_orchestration_common.respond_orchestration_unavailable ~src ctx)
          | true, None ->
              Logs.warn (fun m -> m "%s : GITHUB_CLAIM_BAD_INSTALLATION_ID" (Brtl_ctx.token ctx));
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"VCS_INSTALLATION_INVALID_ID"
                   ~data:"installation_core_id must be a uuid."
                   ctx)
          | true, Some installation_core_uuid -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  let open Abbs_fc.Infix_result_monad in
                  Sgs_tenant.enforce_user user tenant db
                  >>= fun () ->
                  Sgs_user_session.Session.fetch_key db
                  >>= fun keys ->
                  Abb.Future.return
                    (Sgs_service_orchestration_github_claim_proof.of_ctx
                       ~verifiers:(Sgs_user_session.Session.Keys.rs256_verifiers keys)
                       ~now:(Unix.gettimeofday ())
                       ~user
                       ~tenant
                       ctx)
                  >>= fun proof ->
                  (* The proof holds Uuidm.to_string's lowercase ids, so the
                     body's id is compared in that form, whatever its case. *)
                  match
                    Sgs_service_orchestration_github_claim_token.Proof.covers
                      proof
                      ~installation_core_id:(Uuidm.to_string installation_core_uuid)
                  with
                  | `Covered ->
                      (* Link only when currently unlinked, in one
                         statement, so two callers racing for the same
                         installation cannot both win. *)
                      Sgs_service_orchestration_tenant_vcs_installations.link_if_unlinked
                        ~tenant_id:(Sgs_tenant.id tenant)
                        ~provider:"github"
                        ~installation_core_id:installation_core_uuid
                        db
                  | `Not_covered ->
                      (* The proof is over a set. Asking for something
                         outside it is the attack this endpoint exists to
                         stop, so it is a denial, not a 412. *)
                      Abbs_fc.return_err `Not_proven_err)
              >>| function
              | Ok (`Linked installation) ->
                  Logs.info (fun m ->
                      m
                        "%s : GITHUB_CLAIM_LINKED : tenant=%a installation=%s user=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        installation_core_id
                        Uuidm.pp
                        (Sgs_user.id user));
                  Sgs_service_orchestration_common.respond_installation ctx installation
              | Ok (`Already_linked_here installation) ->
                  (* A double click, a second tab, or a retry after a dropped
                     response: the link this caller asked for is in place, so
                     they are shown it rather than told another tenant won. *)
                  Logs.info (fun m ->
                      m
                        "%s : GITHUB_CLAIM_ALREADY_LINKED_HERE : tenant=%a installation=%s user=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        installation_core_id
                        Uuidm.pp
                        (Sgs_user.id user));
                  Sgs_service_orchestration_common.respond_installation ctx installation
              | Ok `Linked_elsewhere ->
                  (* Claimed by another tenant between the proof and this
                     request. Not an error the caller can fix, but they must
                     be told rather than shown a link that does not exist. *)
                  Logs.warn (fun m ->
                      m
                        "%s : GITHUB_CLAIM_ALREADY_LINKED : installation=%s"
                        (Brtl_ctx.token ctx)
                        installation_core_id);
                  Sgs_eplib.respond_error
                    ~status:`Conflict
                    ~id:"VCS_INSTALLATION_ALREADY_LINKED"
                    ~data:"That installation is already linked to a tenant."
                    ctx
              | Error `Not_proven_err ->
                  Logs.warn (fun m ->
                      m
                        "%s : GITHUB_CLAIM_NOT_PROVEN : tenant=%a installation=%s user=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        installation_core_id
                        Uuidm.pp
                        (Sgs_user.id user));
                  Sgs_eplib.respond_error
                    ~status:`Forbidden
                    ~id:"GITHUB_INSTALLATION_NOT_PROVEN"
                    ~data:"You have not proven access to that installation."
                    ctx
              | Error (#Sgs_service_orchestration_github_claim_common.proof_access_err as err) ->
                  Sgs_service_orchestration_github_claim_common.respond_proof_access_err
                    ~src
                    ctx
                    err)))

let src = Logs.Src.create "service_orchestration_ep_github_claimable_list"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage tenant =
  (* Unlike the instance-admin unclaimed listing, this enumerates nothing: it
     reports back the set the caller's own proof names, minus anything claimed in
     the meantime. A tenant admin therefore still cannot discover other
     organizations' pending installations. *)
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          if not (Sgs_config.orchestration_enabled config) then
            Abb.Future.return
              (Sgs_service_orchestration_common.respond_orchestration_unavailable ~src ctx)
          else
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
                (* The proof's ids were printed by Uuidm.to_string and
                   signed, so every one of them parses. *)
                Sgs_service_orchestration_github_installations.list_claimable_by_core_ids
                  ~installation_core_ids:
                    (CCList.filter_map
                       Uuidm.of_string
                       proof
                         .Sgs_service_orchestration_github_claim_token.Proof.installation_core_ids)
                  db)
            >>| function
            | Ok claimable ->
                Logs.info (fun m ->
                    m
                      "%s : GITHUB_CLAIMABLE_LIST : tenant=%a count=%d"
                      (Brtl_ctx.token ctx)
                      Uuidm.pp
                      (Sgs_tenant.id tenant)
                      (CCList.length claimable));
                let body =
                  Yojson.Safe.to_string
                  @@ Sgs_api_components.Github_claimable_installations.to_yojson
                       {
                         Sgs_api_components.Github_claimable_installations.results =
                           CCList.map
                             Sgs_service_orchestration_github_installations.to_api
                             claimable;
                       }
                in
                Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx
            | Error (#Sgs_service_orchestration_github_claim_common.proof_access_err as err) ->
                Sgs_service_orchestration_github_claim_common.respond_proof_access_err ~src ctx err))

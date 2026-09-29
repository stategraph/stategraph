let src = Logs.Src.create "service_orchestration_ep_gitlab_rotate"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage tenant group_id body =
  let module B = Sgs_api_components.Gitlab_rotate_request in
  let { B.access_token; regenerate_webhook_secret } = body in
  let access_token = CCOption.map CCString.trim access_token in
  let webhook_secret =
    match regenerate_webhook_secret with
    | None | Some false -> `Keep
    | Some true -> `Regenerate
  in
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          match Sgs_service_orchestration_common.provisioning_availability config with
          | (`Orchestration_disabled | `Provisioner_not_configured) as reason ->
              Abb.Future.return
                (Sgs_service_orchestration_common.respond_provisioning_unavailable ~src ctx reason)
          | `Available
            when group_id <= 0
                 || CCOption.map_or ~default:false CCString.is_empty access_token
                 ||
                 match (access_token, webhook_secret) with
                 | None, `Keep -> true
                 | Some _, (`Keep | `Regenerate) | None, `Regenerate -> false ->
              Logs.warn (fun m -> m "%s : GITLAB_ROTATE_INVALID" (Brtl_ctx.token ctx));
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"GITLAB_ROTATE_INVALID"
                   ~data:
                     "Provide a non-empty access_token, regenerate_webhook_secret, or both, for a \
                      positive group_id."
                   ctx)
          | `Available -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  let open Abbs_fc.Infix_result_monad in
                  Sgs_tenant.enforce_user user tenant db
                  >>= fun () ->
                  Sgs_service_orchestration_gitlab_rotate.rotate
                    ~tenant_id:(Sgs_tenant.id tenant)
                    ~group_id
                    ~access_token
                    ~webhook_secret
                    db)
              >>= function
              | Ok rotated ->
                  Logs.info (fun m ->
                      m
                        "%s : GITLAB_ROTATE_OK : group_id=%d : token=%b : secret=%s"
                        (Brtl_ctx.token ctx)
                        group_id
                        (CCOption.is_some access_token)
                        (match webhook_secret with
                        | `Keep -> "keep"
                        | `Regenerate -> "regenerate"));
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components.Gitlab_rotate_response.to_yojson
                    @@ Sgs_service_orchestration_gitlab_rotate.to_api rotated
                  in
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Error `Not_found_err ->
                  (* Unprovisioned and owned-by-another-tenant are deliberately
                     the same answer. *)
                  Logs.warn (fun m ->
                      m "%s : GITLAB_ROTATE_NOT_FOUND : group_id=%d" (Brtl_ctx.token ctx) group_id);
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
              | Error `Rotated_row_missing_err ->
                  Logs.err (fun m ->
                      m
                        "%s : GITLAB_ROTATE_READ_BACK_MISSING : group_id=%d"
                        (Brtl_ctx.token ctx)
                        group_id);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))

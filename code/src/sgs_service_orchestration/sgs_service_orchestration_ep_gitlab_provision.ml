let src = Logs.Src.create "service_orchestration_ep_gitlab_provision"

module Logs = (val Logs.src_log src : Logs.LOG)

let run config storage tenant body =
  let module B = Sgs_api_components.Gitlab_provision_request in
  let { B.group_id; name; access_token } = body in
  let name = CCString.trim name in
  let access_token = CCString.trim access_token in
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
            when group_id <= 0 || CCString.is_empty name || CCString.is_empty access_token ->
              Logs.warn (fun m -> m "%s : GITLAB_PROVISION_INVALID" (Brtl_ctx.token ctx));
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"GITLAB_PROVISION_INVALID"
                   ~data:"group_id must be a positive integer; name and access_token are required."
                   ctx)
          | `Available -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  let open Abbs_fc.Infix_result_monad in
                  Sgs_tenant.enforce_user user tenant db
                  >>= fun () ->
                  Sgs_service_orchestration_gitlab_provision.provision
                    ~tenant_id:(Sgs_tenant.id tenant)
                    ~group_id
                    ~name
                    ~access_token
                    db)
              >>= function
              | Ok provision ->
                  Logs.info (fun m ->
                      m "%s : GITLAB_PROVISION_CREATED : group_id=%d" (Brtl_ctx.token ctx) group_id);
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components.Gitlab_provision_response.to_yojson
                    @@ Sgs_service_orchestration_gitlab_provision.to_api provision
                  in
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Created body) ctx)
              | Error `Already_provisioned_err ->
                  Logs.warn (fun m -> m "%s : GITLAB_PROVISION_CONFLICT" (Brtl_ctx.token ctx));
                  Abb.Future.return
                    (Sgs_eplib.respond_error
                       ~status:`Conflict
                       ~id:"GITLAB_ALREADY_PROVISIONED"
                       ~data:"This GitLab group already has an installation."
                       ctx)
              | Error `Tenant_not_found_err ->
                  Logs.warn (fun m ->
                      m "%s : GITLAB_PROVISION_TENANT_NOT_FOUND" (Brtl_ctx.token ctx));
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
              | Error `Provisioned_row_missing_err ->
                  Logs.err (fun m ->
                      m
                        "%s : GITLAB_PROVISION_READ_BACK_MISSING : group_id=%d"
                        (Brtl_ctx.token ctx)
                        group_id);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))

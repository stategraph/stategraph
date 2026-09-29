let src = Logs.Src.create "service_orchestration_ep_vcs_installation_delete"

module Logs = (val Logs.src_log src : Logs.LOG)

let run' storage tenant user provider installation_core_id =
  Abbs_fc.Infix_result_monad.(
    Abb.Future.return (Sgs_service_orchestration_common.check_provider provider)
    >>= fun () ->
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Sgs_tenant.enforce_user user tenant db
        >>= fun () ->
        Sgs_service_orchestration_tenant_vcs_installations.delete
          ~tenant_id:(Sgs_tenant.id tenant)
          ~provider
          ~installation_core_id
          db))

let run _config storage tenant provider installation_core_id =
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          run' storage tenant user provider installation_core_id
          >>= function
          | Ok `Deleted ->
              Logs.info (fun m ->
                  m
                    "%s : VCS_INSTALLATION_UNLINKED : tenant=%a provider=%s core_id=%a"
                    (Brtl_ctx.token ctx)
                    Uuidm.pp
                    (Sgs_tenant.id tenant)
                    provider
                    Uuidm.pp
                    installation_core_id);
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`No_content "") ctx)
          | Ok `Not_found ->
              Logs.warn (fun m ->
                  m
                    "%s : VCS_INSTALLATION_NOT_FOUND : tenant=%a provider=%s core_id=%a"
                    (Brtl_ctx.token ctx)
                    Uuidm.pp
                    (Sgs_tenant.id tenant)
                    provider
                    Uuidm.pp
                    installation_core_id);
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
          | Error `Invalid_provider_err ->
              Abb.Future.return
                (Sgs_service_orchestration_common.respond_invalid_provider ~src ~provider ctx)
          | Error (#Sgs_eplib.tenant_access_err as err) ->
              Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err)))

module Tests = struct
  let run' = run'
end

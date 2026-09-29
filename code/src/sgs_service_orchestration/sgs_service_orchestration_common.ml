let src = Logs.Src.create "service_orchestration_common"

let log_orchestration_unavailable ?(src = src) ctx =
  Logs.warn ~src (fun m -> m "%s : ORCHESTRATION_UNAVAILABLE" (Brtl_ctx.token ctx))

let respond_orchestration_unavailable ?src ctx =
  log_orchestration_unavailable ?src ctx;
  Sgs_eplib.respond_error
    ~status:`Service_unavailable
    ~id:"ORCHESTRATION_UNAVAILABLE"
    ~data:"Orchestration is not enabled on this server."
    ctx

let provisioning_availability config =
  match (Sgs_config.orchestration_enabled config, Sgs_config.fdw_provisioner_password config) with
  | false, _ -> `Orchestration_disabled
  | true, None -> `Provisioner_not_configured
  | true, Some _ -> `Available

let respond_provisioning_unavailable ?(src = src) ctx = function
  | `Orchestration_disabled -> respond_orchestration_unavailable ~src ctx
  | `Provisioner_not_configured ->
      Logs.warn ~src (fun m -> m "%s : PROVISIONING_UNAVAILABLE" (Brtl_ctx.token ctx));
      Sgs_eplib.respond_error
        ~status:`Service_unavailable
        ~id:"PROVISIONING_UNAVAILABLE"
        ~data:"Provisioning is not enabled on this server."
        ctx

let check_provider provider =
  if Sgs_service_orchestration_tenant_vcs_installations.valid_vcs_provider provider then Ok ()
  else Error `Invalid_provider_err

let respond_invalid_provider ?(src = src) ~provider ctx =
  Logs.warn ~src (fun m ->
      m "%s : VCS_INSTALLATION_INVALID_PROVIDER : provider=%s" (Brtl_ctx.token ctx) provider);
  Sgs_eplib.respond_error
    ~status:`Bad_request
    ~id:"VCS_INSTALLATION_INVALID_PROVIDER"
    ~data:"provider must be github or gitlab"
    ctx

let respond_installation ctx installation =
  Brtl_ctx.set_response
    (Brtl_rspnc.create
       ~status:`OK
       (Sgs_service_orchestration_tenant_vcs_installations.to_body installation))
    ctx

let respond_found ?(headers = Cohttp.Header.init ()) ~location ctx =
  Brtl_ctx.set_response
    (Brtl_rspnc.create ~status:`Found ~headers:(Cohttp.Header.add headers "Location" location) "")
    ctx

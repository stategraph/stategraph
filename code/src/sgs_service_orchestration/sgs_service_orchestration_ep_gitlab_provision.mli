(** POST [/api/v1/tenants/{tenant_id}/vcs-installations/gitlab]. Provision a GitLab group
    installation in terrateam through the narrow admin FDW channel and link it to the tenant. Admin
    only. Returns the once-only webhook secret. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  Sgs_api_tenants.Provision_gitlab_installation.Request_body.t ->
  Brtl_rtng.Handler.t

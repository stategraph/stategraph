(** PUT [/api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}]. Rotate a provisioned
    GitLab installation's credentials -- new access token and/or regenerated webhook secret
    (returned once) -- only when the group is linked to this tenant. Admin only. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  int ->
  Sgs_api_tenants.Rotate_gitlab_installation.Request_body.t ->
  Brtl_rtng.Handler.t

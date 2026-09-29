(** PUT [/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}]. Link a
    terrateam VCS installation to a tenant, moving it if it was linked to another tenant (an
    installation belongs to exactly one tenant). Instance admin: linking decides which tenant sees
    the installation's orchestration data, a cross-tenant decision. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  string ->
  Uuidm.t ->
  Brtl_rtng.Handler.t

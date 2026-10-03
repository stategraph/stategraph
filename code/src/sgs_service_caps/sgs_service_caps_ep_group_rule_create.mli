(** [POST /api/v1/tenants/{tenant_id}/caps/group-rules] — create a capability group rule owned by
    the tenant. Requires admin of the tenant (an installation-wide admin qualifies). The request
    body carries the [condition], optional [description], and [grant]; the grant must be scoped to
    this tenant and no wider (installation-level capabilities, grants naming other tenants, and
    states owned by another tenant are rejected with [422]). The response returns the new rule's id.
*)
val run : Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Brtl_rtng.Handler.t

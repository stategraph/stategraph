(** [GET /api/v1/tenants/{tenant_id}/caps/group-rules] — list the tenant's capability group rules
    that have not been soft-deleted. Requires admin of the tenant (an installation-wide admin
    qualifies). *)
val run : Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Brtl_rtng.Handler.t

(** [DELETE /api/v1/tenants/{tenant_id}/caps/group-rules/{id}] — soft-delete one of the tenant's
    capability group rules. Requires admin of the tenant (an installation-wide admin qualifies).
    [200] when a matching alive rule owned by this tenant was deleted; [404] when no such rule
    exists here (unknown id, a rule owned by another tenant, or one already deleted). *)
val run :
  Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Uuidm.t -> Brtl_rtng.Handler.t

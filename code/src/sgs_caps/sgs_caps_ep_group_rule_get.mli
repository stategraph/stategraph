(** [GET /api/v1/tenants/{tenant_id}/caps/group-rules/{id}] — read one of the tenant's capability
    group rules, with the grant it confers on matching users at login. Requires admin of the tenant
    (an installation-wide admin qualifies). [200] with the rule when an alive rule owned by this
    tenant has this id; [404] when no such rule exists here (unknown id, a rule owned by another
    tenant, or one soft-deleted). *)
val run :
  Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Uuidm.t -> Brtl_rtng.Handler.t

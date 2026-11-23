(** POST [/api/v1/tenants/{tenant_id}/close]. Close a tenant: from then on it refuses every request
    but its reopen, and its data is deleted after the retention days.

    Requires administering the tenant, plus membership. 409 [TENANT_CLOSED] when it is closed
    already. *)
val run : Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Brtl_rtng.Handler.t

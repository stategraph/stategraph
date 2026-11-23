(** POST [/api/v1/tenants/{tenant_id}/reopen]. Reopen a closed tenant and take it off the deletion
    schedule.

    Requires administering the tenant, plus membership; the membership of a closed tenant counts.
    409 [TENANT_NOT_CLOSED] when it is not closed. *)
val run : Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Brtl_rtng.Handler.t

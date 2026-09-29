(** GET /api/v1/tenants/{tenant_id}/vcs-installations/github/claimable

    The installations the caller proved control of that are still linked to no tenant (#1795).
    Requires the proof cookie the claim callback set; 412 without it. *)
val run : Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Brtl_rtng.Handler.t

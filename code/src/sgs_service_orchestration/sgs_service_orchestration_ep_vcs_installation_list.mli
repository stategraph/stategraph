(** GET [/api/v1/tenants/{tenant_id}/vcs-installations]. List the terrateam VCS installations mapped
    to a tenant. Tenant admin (or wider) -- deliberately more permissive than link/unlink, which
    require instance admin. Reading a tenant's own mappings is scoped to that tenant and changes no
    cross-tenant boundary, so it does not need the installation-wide grant; do not "tighten" this to
    instance admin. *)
val run : Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> Brtl_rtng.Handler.t

(** GET [/api/v1/tenants/{tenant_id}/members]. Page a tenant's active members, oldest membership
    first, with each member's [admin] and [users-manage] coverage over this tenant.

    Requires administering the tenant or holding [users-manage] scoped to it, plus membership.

    After the tenant come the [search] and [role] filters, then the cursor and the limit. Both
    filters are accepted and ignored: the API reserves them, but they are not honored yet. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  string option ->
  string option ->
  string option ->
  int ->
  Brtl_rtng.Handler.t

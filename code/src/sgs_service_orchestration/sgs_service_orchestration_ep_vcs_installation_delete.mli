(** DELETE [/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}]. Unlink
    a terrateam VCS installation from a tenant. Requires administering the tenant and being a member
    of it, as rotation does; linking (the PUT) stays instance-admin, since attaching an installation
    decides which tenant sees its data. [204] once unlinked, [404] when the installation is not
    linked to this tenant, [403] [TENANT_MEMBERSHIP_REQUIRED] for an admin who is not a member. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  string ->
  Uuidm.t ->
  Brtl_rtng.Handler.t

module Tests : sig
  val run' :
    Sgs_storage.t ->
    Sgs_tenant.minted Sgs_tenant.t ->
    'a Sgs_user.t ->
    string ->
    Uuidm.t ->
    ([ `Deleted | `Not_found ], [> `Invalid_provider_err | Sgs_eplib.tenant_access_err ]) result
    Abb.Future.t
end

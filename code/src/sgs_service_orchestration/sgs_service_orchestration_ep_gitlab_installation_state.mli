(* The uninstall and restore routes of a GitLab installation. *)

(** POST [/api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}/uninstall]. Mark a
    provisioned GitLab installation uninstalled, only when the group is linked to this tenant. Admin
    only. *)
val uninstall :
  Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> int -> Brtl_rtng.Handler.t

(** POST [/api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}/restore]. Take an
    uninstalled GitLab installation back to [pending], only when the group is linked to this tenant.
    Admin only. *)
val restore :
  Sgs_config.t -> Sgs_storage.t -> Sgs_tenant.minted Sgs_tenant.t -> int -> Brtl_rtng.Handler.t

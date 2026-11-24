(** GET [/api/v1/user/closed-tenants]. The closed tenants the user is a member of, so a tenant
    administrator can reopen one. *)
val run : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t

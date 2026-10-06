(** Users Detail Endpoint

    One user's record by id: name, email, type, avatar, authentication origin, creation time, the
    two admin scopes, and the tenants the user belongs to.

    Readable by the subject itself, and by a caller holding users-manage authority over some tenant
    the subject belongs to. Containment only: reading who someone is does not ask for the authority
    editing them does. A caller reaching only some of the subject's tenants sees only those
    memberships, with [tenants_complete] saying whether the list is whole; only a caller reaching
    none of them is refused. *)

(** GET /api/v1/users/detail?user_id= - Get user details *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t

(** Users Detail Endpoint

    One user's record by id: name, email, type, avatar, authentication origin, creation time, the
    two admin scopes, the tenants the user belongs to, and its capabilities.

    Readable by the subject itself, and by a caller holding users-manage authority over some tenant
    the subject belongs to. Containment only: reading who someone is does not ask for the authority
    editing them does. A caller reaching only some of the subject's tenants sees only those
    memberships, with [tenants_complete] saying whether the list is whole; only a caller reaching
    none of them is refused.

    The capabilities are the exception to containment: they are in the answer for the subject
    itself, and for a caller {!Sgs_service_users_common.authority} lets act on the subject, and
    absent otherwise. Such a caller can reset the subject's password, so they show it nothing it
    could not already use. *)

(** GET /api/v1/users/detail?user_id= - Get user details *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t

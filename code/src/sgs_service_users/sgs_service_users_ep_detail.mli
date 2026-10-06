(** Users Detail Endpoint

    One user's record by id: name, email, type, avatar, authentication origin, creation time, and
    the two admin scopes.

    Readable by the subject itself, and by a caller holding authority over users that reaches every
    tenant the subject belongs to. Containment only: reading who someone is does not ask for the
    authority editing them does. *)

(** GET /api/v1/users/detail?user_id= - Get user details *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t

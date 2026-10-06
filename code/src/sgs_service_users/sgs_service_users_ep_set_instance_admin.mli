(** Users Set Installation Admin Endpoint

    Sets a user's installation-wide [admin] grant to the value the request asks for: [true] writes
    an unrestricted grant, replacing a tenant-scoped one; [false] clears an unrestricted grant and
    leaves a tenant-scoped one as it is. It is a set, not a toggle — the current value is never read
    to invert it — so repeating a call is a no-op rather than a flip.

    Requires an installation-wide [admin] grant: an unscoped [users-manage] grant does not suffice,
    because this endpoint is how someone becomes an installation admin.

    Refuses to clear the grant of the last installation admin, because granting it back requires
    holding it. Refuses to clear the caller's own grant, whoever else holds one: stepping down is
    not something to do from the screen it removes you from. *)

(** [POST /api/v1/users/set-instance-admin?user_id=] — set the installation-wide admin grant. *)
val run : Sgs_config.t -> Sgs_storage.t -> Uuidm.t -> Brtl_rtng.Handler.t

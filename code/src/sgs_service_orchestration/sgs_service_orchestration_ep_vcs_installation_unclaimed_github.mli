(** GET [/api/v1/vcs-installations/github/unclaimed?cursor=&limit=]. List GitHub installations
    linked to no tenant, newest first, so an admin can claim one. Instance admin only.

    The page is keyset-paginated on [(created_at, installation_core_id)]: the response carries
    [has_more] and, when there is one, the [next_cursor] to pass back. Nothing is silently dropped,
    however many installations are waiting. [503] when orchestration is disabled, since the
    terrateam read FDW this reads through is only built when it is on. *)
val run : cursor:string option -> limit:int -> Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t

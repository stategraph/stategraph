(** GET /api/v1/setup/github-app: the GitHub App the orchestration engine uses, and where it comes
    from. Instance admin only. *)

val run : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t

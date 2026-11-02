(** Scheduler handler for the singleton ['gc_expired_oauth2_sessions'] schedule: it deletes every
    OAuth2 session row whose expiration has passed and logs how many it deleted. Never raises and
    never returns an error: a failure is logged. *)
val run : Sgs_config.t -> Sgs_storage.t -> Pgsql_io.t -> Yojson.Safe.t -> unit Abb.Future.t

(** The task id this handler runs under; the [kind] of its schedule row. *)
val kind : string

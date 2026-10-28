(** The terrat config service: the {!Terrat_config.t} that every terrat service runs with and the
    pool of the terrateam database, {!Terrat_storage.t}, as a service in the manager. Its start
    reads the config from the Stategraph environment ({!Sgs_terrat_config.create}), creates the pool
    from it, and settles the GitHub App in the config, which reads the pool.

    The GitHub App of the environment wins, and it must have a webhook secret that is not empty.
    Without one, the App stored in the database is used and marked loaded; a row that cannot be
    used, or no row, leaves the config without GitHub. With a stored App, or with none, a watcher
    polls the row until the service stops and ends the process when the row changes, so the
    supervisor starts it again on the new App.

    A config that fails to load, an App without a webhook secret, a database that does not answer
    and a database error refuse the start with [`Start_fatal_err]: a retry cannot fix them. It has
    no routes. *)

include Sgs_service.S with type opt = Sgs_svc_mngr.t

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

(** The config, with the GitHub App the process runs. *)
val config : t -> Terrat_config.t

(** The pool of the terrateam database. *)
val storage : t -> Terrat_storage.t

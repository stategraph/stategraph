(** Manages services and their interaction *)

type t
type start_err = [ `Start_err ] [@@deriving show]
type register_err = [ `Register_err ] [@@deriving show]
type config_err = [ `Config_err ] [@@deriving show]
type storage_err = [ `Storage_err ] [@@deriving show]

type get_err =
  [ `Service_not_found_err
  | `Chan_closed
  ]
[@@deriving show]

val start : Sgs_config.t -> Sgs_storage.t -> (t, start_err) result Abb.Future.t

(** Stop every service the manager started, then the manager itself. The services stop in the
    reverse of the order they started. *)
val stop : t -> unit Abb.Future.t

(** Register a service with the manager. The service is started inside of the service manager. If
    the service fails to start, it is retried forever with a wait of 1 second between tries.

    A service should use {!Sgs_svc_mngr.get} to load any other service dependencies on startup and
    fail with [`Start_missing_deps_err] if the required services cannot be found. The service
    manager has no dependency ordering management, It's restart strategy will brute-force the
    startup order by via the restarts.

    The service is not started again if it fails after a successful start. *)
val register :
  t -> (module Sgs_service.S with type opt = t) -> (unit, [> register_err ]) result Abb.Future.t

(** Record a service that was started outside the manager, so [get] can find it. *)
val add : t -> Sgs_service.started -> (unit, [> register_err ]) result Abb.Future.t

(** Start every service the build asks for. Each start runs on a task of its own and is retried one
    second later when it fails, so a service whose dependency is not up yet neither holds up the
    other services nor fails this call. This returns once every service has started, with them in
    list order. *)
val start_services :
  t ->
  (module Sgs_service.S with type opt = t) list ->
  (Sgs_service.started list, Sgs_service.start_err) result Abb.Future.t

val config : t -> (Sgs_config.t, [> config_err ]) result Abb.Future.t
val storage : t -> (Sgs_storage.t, [> storage_err ]) result Abb.Future.t

(** Return a matching service if it exists, otherwise [`Service_not_found_err] if not found. *)
val get : t -> 'a Sgs_service.ty -> ('a, [> get_err ]) result Abb.Future.t

(** Manages services and their interaction *)

type t
type start_err = [ `Start_err ] [@@deriving show]
type register_err = [ `Register_err ] [@@deriving show]

type get_err =
  [ `Service_not_found_err
  | `Chan_closed
  ]
[@@deriving show]

type routes_err = [ `Routes_err ] [@@deriving show]

(** Start the manager with no services. Config and storage are services like any other: the boot
    records them with [add], and a service loads them with [get]. *)
val start : unit -> (t, [> start_err ]) result Abb.Future.t

(** Stop every service the manager started, then the manager itself. The services stop in the
    reverse of the order they started. *)
val stop : t -> unit Abb.Future.t

(** Register every service in the list, in list order, and stop at the first failure. *)
val register' :
  t ->
  (module Sgs_service.S with type opt = t) list ->
  (unit, [> register_err ]) result Abb.Future.t

(** Register a service with the manager. The service is started inside of the service manager. If
    the service fails to start, it is retried forever with a wait of 1 second between tries.

    A service should use {!Sgs_svc_mngr.get} to load any other service dependencies on startup and
    fail with [`Start_missing_deps_err] if the required services cannot be found. The service
    manager has no dependency ordering management, It's restart strategy will brute-force the
    startup order by via the restarts.

    The service is not started again if it fails after a successful start. *)
val register :
  t -> (module Sgs_service.S with type opt = t) -> (unit, [> register_err ]) result Abb.Future.t

(** Record a service that was started outside the manager, so [get] can find it. The config and
    storage services ({!Sgs_service_config} and {!Sgs_service_storage}) are recorded this way: the
    manager keeps no special state for them. *)
val add : t -> Sgs_service.started -> (unit, [> register_err ]) result Abb.Future.t

(** Wait until every service registered with the manager has started. A service whose start never
    succeeds keeps this future undetermined. A service registered while this waits is included in
    the wait. Any number of callers can wait at the same time; each gets its own future. *)
val started : t -> unit Abb.Future.t

(** Return a matching service if it exists, otherwise [`Service_not_found_err] if not found. *)
val get : t -> 'a Sgs_service.ty -> ('a, [> get_err ]) result Abb.Future.t

(** [load mgr ~name ty] is the value of the service with witness [ty], or a start refusal when the
    manager does not have it: a missing service is [`Start_missing_deps_err] naming [name], a closed
    manager is [`Start_err]. *)
val load :
  name:string -> 'a Sgs_service.ty -> t -> ('a, [> Sgs_service.start_err ]) result Abb.Future.t

(** Collect the routes of every service the manager runs, in registration order: the order the
    services were added and registered. [collect] turns one started service into its routes. A
    closed manager gives [`Routes_err]. *)
val routes :
  t ->
  (Sgs_service.started -> Sgs_service.route list) ->
  (Sgs_service.route list, [> routes_err ]) result Abb.Future.t

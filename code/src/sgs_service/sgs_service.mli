(** A service: a part of the server with a lifetime of its own around the HTTP listener and routes
    of its own. The core starts each service of the build before the listener, appends its routes to
    the shared route table, and stops it after the listener. An edition is a choice of services, and
    a service that exists in several editions is built by a functor over what differs. *)

(** One route-table entry: the HTTP method and the route with its handler. *)
type route = Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t

(** Why a service refuses to start, told to the operator: the server logs it and exits. *)
type start_err =
  [ `Start_err of string
  | `Start_missing_deps_err of string list
  ]
[@@deriving show]

(** A service's witness at the type level: each service adds its own constructor, indexed at its own
    [t]. A match on the witness of a started service tells which service it is. *)
type 'a ty = ..

(** Type equality proved by a witness match. [Refl] exists only when both indexes are the same type.
*)
type (_, _) eq = Refl : ('a, 'a) eq

module type S = sig
  (** The running service. *)
  type t

  (** Options passed into configuration at startup *)
  type opt

  (** The service's name. *)
  val name : string

  (** The witness of the service: its constructor is indexed at [t]. *)
  val ty : t ty

  (** [matches q] is [Some Refl] when [q] is this service's witness. [Refl] then proves that the
      query's type is [t]. *)
  val matches : 'a ty -> (t, 'a) eq option

  (** Start the service. The service should load all dependencies it requires on start and fail with
      [`Start_missing_deps_err] on failure. *)
  val start : opt -> (t, [> start_err ]) result Abb.Future.t

  (** The routes appended to the shared route table. *)
  val routes : t -> Sgs_config.t -> Sgs_storage.t -> route list

  (** Stop the service after the listener. *)
  val stop : t -> unit Abb.Future.t
end

(** A started service together with its module, so a list can hold services of different types. *)
type started = Started : (module S with type t = 'a) * 'a -> started

(** Start the service and pair it with its module. [opt] is the options the service asked for. *)
val start : (module S with type opt = 'opt) -> 'opt -> (started, start_err) result Abb.Future.t

(** The routes appended to the shared route table. *)
val routes : started -> Sgs_config.t -> Sgs_storage.t -> route list

(** Stop the service. *)
val stop : started -> unit Abb.Future.t

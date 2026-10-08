(** The license service: the license status and the setup endpoints that enforce the license.

    Routes: [GET /api/v1/license/status], [POST /api/v1/setup/complete], [POST /api/v1/setup/admin].
    All are unauthenticated: they run before the first user exists. Entering a key
    ([POST /api/v1/license]) and the Aegis magic-link claim ([POST /api/v1/setup/magic-claim]) are
    the enterprise build's alone and live in {!Sgs_ee_service}. *)

(** What an edition requires before setup may proceed. *)
type requirement =
  [ `Not_required  (** No license: setup always proceeds. *)
  | `Required of Sgs_config.t -> Pgsql_io.t -> (bool, Pgsql_io.err) result Abb.Future.t
    (** A license, where the function tells whether the instance holds one. *)
  ]

(** [passes_license_gate ~requirement config db] is what the setup endpoints gate on: [true]
    outright when [requirement] is [`Not_required], otherwise what the edition's check answers. *)
val passes_license_gate :
  requirement:requirement ->
  Sgs_config.t ->
  Pgsql_io.t ->
  (bool, [> Pgsql_io.err ]) result Abb.Future.t

(** [may_start ~requirement config db] is what the server gates its start on: [true] outright when
    [requirement] is [`Not_required] or the installation has no human user yet, otherwise what the
    edition's check answers. Setup only gates the first user, so users that came another way (an
    edition that needs no license, the command line) are caught when the server starts. *)
val may_start :
  requirement:requirement ->
  Sgs_config.t ->
  Pgsql_io.t ->
  (bool, [> Pgsql_io.err ]) result Abb.Future.t

(** The license of an edition. *)
module type LICENSE = sig
  (** What this edition requires before setup may proceed. *)
  val requirement : requirement

  (** [POST /api/v1/setup/complete]: mark setup complete. *)
  val setup_complete : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t

  (** [POST /api/v1/setup/admin]: create the first admin user. *)
  val setup_admin : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t

  (** [GET /api/v1/license/status]: report whether the instance is licensed and whether this edition
      requires it to be. *)
  val license_status : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
end

(** The service refuses to start when {!may_start} answers [false]. *)
module Make (_ : LICENSE) : sig
  include Sgs_service.S with type opt = Sgs_svc_mngr.t

  (** Names this service in a match on {!Sgs_service.ty}. *)
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty
end

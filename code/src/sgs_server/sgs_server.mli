type route = Sgs_service.route

(** The server, given the Cloud abstraction of the edition. *)
module Make (_ : Sgs_cloud.S) : sig
  (** Run the HTTP server until it stops. [routes] are appended to the shared route table: the
      routes of the build's services. The router matches whole paths, so no shared route can shadow
      an appended one. *)
  val run : routes:route list -> Sgs_config.t -> Sgs_storage.t -> unit Abb.Future.t
end

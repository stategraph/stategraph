type route = Sgs_service.route

(** Run the HTTP server until it stops. [routes] are appended to the shared route table: the routes
    of the build's services. The router matches whole paths, so no shared route can shadow an
    appended one. *)
val run : routes:route list -> Sgs_config.t -> Sgs_storage.t -> unit Abb.Future.t

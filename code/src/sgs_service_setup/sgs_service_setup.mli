(** The setup service: [GET /api/v1/setup/status], whether the deployment still needs its in-app
    setup, and its mode. Every edition runs it. [Make] takes the Cloud abstraction, which decides
    both. The setup endpoints that enforce the license belong to the license service. *)

module Make (_ : Sgs_cloud.S) : Sgs_service.S with type opt = Sgs_svc_mngr.t

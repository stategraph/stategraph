(** The capabilities service: the installation's default capabilities, and the capability group
    rules of each tenant. Every edition runs it. *)

include Sgs_service.S with type opt = Sgs_svc_mngr.t

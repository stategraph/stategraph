(** The tenants service: tenants, their members and their invitations, and the tenants of the
    signed-in user. Every edition runs it, since the console and orchestration rely on tenants.
    [Make] takes the Cloud abstraction, through which invitations are emailed. *)

module Make (_ : Sgs_cloud.S) : Sgs_service.S with type opt = Sgs_svc_mngr.t

(** The terrat API service: the routes of terrat's API that neither a VCS nor terrat's console
    needs. *)

include Sgs_service.S with type opt = Sgs_svc_mngr.t

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

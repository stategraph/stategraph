(** The orchestration service: the VCS installation routes through which Terrateam, fronted by
    Stategraph, is claimed and provisioned. Every build runs it. *)

include Sgs_service.S with type opt = Sgs_svc_mngr.t

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

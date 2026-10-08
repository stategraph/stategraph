(** The orchestration service: the VCS installation routes through which Terrateam, fronted by
    Stategraph, is claimed and provisioned. Every build runs it. *)

include Sgs_service.S

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

(** [of_started s] is the state of [s] when [s] is this service, and [None] when [s] is any other
    service. *)
val of_started : Sgs_service.started -> t option

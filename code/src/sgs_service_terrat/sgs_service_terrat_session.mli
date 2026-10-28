(** The terrat session service: terrat's session, as a wrapper of the handlers of terrat's routes
    only, as a service in the manager. The terrat services that serve routes declare it as their
    wrapper ({!Sgs_service.S.wrap}). Its start creates the wrapper from the terrat config service;
    it refuses with [`Start_fatal_err] when the terrateam database has no encryption keys, which its
    migrations create. It has no routes and nothing to stop. *)

include
  Sgs_service.S
    with type t = Brtl_rtng.Handler.t -> Brtl_rtng.Handler.t
     and type opt = Sgs_svc_mngr.t

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

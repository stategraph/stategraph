(** The storage service: {!Sgs_storage.t} as a service in the manager, found with [Sgs_svc_mngr.get]
    and loaded by consumers with [Sgs_svc_mngr.load]. Its start creates the storage from the config
    service, so it refuses with [`Start_missing_deps_err] until the config service is up. It has no
    routes and nothing to stop. *)

include Sgs_service.S with type t = Sgs_storage.t and type opt = Sgs_svc_mngr.t

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

module type READER = sig
  val make : Pgsql_pool.t -> Terrat_stategraph.t
end

module type S = sig
  include Sgs_service.S with type t = Terrat_stategraph.t and type opt = Sgs_svc_mngr.t

  type 'a Sgs_service.ty += Ty : t Sgs_service.ty
end

let name = "terrat_stategraph"

module Standalone = struct
  let make _ = (module Terrat_stategraph.Standalone : Terrat_stategraph.S)
end

module Make (Reader : READER) = struct
  type t = Terrat_stategraph.t
  type opt = Sgs_svc_mngr.t
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = name

  let start mgr =
    let open Abbs_fc.Infix_result_monad in
    Sgs_svc_mngr.load ~name:Sgs_service_storage.name Sgs_service_storage.Ty mgr >>| Reader.make

  let routes _ = []
  let wrap _ = CCFun.id
  let stop _ = Abb.Future.return ()
end

module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let setup_status () = Brtl_rtng.Route.(api_v1 () / "setup" / "status")
end

module Make (Cloud : Sgs_cloud.S) = struct
  module Ep_setup_status = Sgs_setup_ep_status.Make (Cloud)

  type t = Sgs_storage.t
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = "setup"

  type opt = Sgs_svc_mngr.t

  (* The route needs the storage, so start loads it like any other dependency. *)
  let start mgr = Sgs_svc_mngr.load ~name:Sgs_service_storage.name Sgs_service_storage.Ty mgr

  let routes storage =
    Brtl_rtng.Route.[ (`GET, Rt.setup_status () --> Ep_setup_status.run storage) ]

  let stop _ = Abb.Future.return ()
end

type t = Sgs_storage.t
type opt = Sgs_svc_mngr.t
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let ty = Ty

let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
  match q with
  | Ty -> Some Sgs_service.Refl
  | _ -> None

let name = "storage"

let start mgr =
  let open Abbs_fc.Infix_result_monad in
  Sgs_svc_mngr.load ~name:Sgs_service_config.name Sgs_service_config.Ty mgr
  >>= fun config -> Sgs_storage.create config |> Abb.Future.map (fun v -> Ok v)

let routes _ = []
let stop _ = Abb.Future.return ()

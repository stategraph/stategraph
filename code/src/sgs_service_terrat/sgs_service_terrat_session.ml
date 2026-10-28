type t = Brtl_rtng.Handler.t -> Brtl_rtng.Handler.t
type opt = Sgs_svc_mngr.t
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let ty = Ty

let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
  match q with
  | Ty -> Some Sgs_service.Refl
  | _ -> None

let name = "terrat_session"

let start mgr =
  let open Abbs_fc.Infix_result_monad in
  Sgs_svc_mngr.load ~name:Sgs_service_terrat_config.name Sgs_service_terrat_config.Ty mgr
  >>= fun config ->
  let storage = Sgs_service_terrat_config.storage config
  and config = Sgs_service_terrat_config.config config in
  Abbs_fc.Result.map_err
    ~f:(fun err -> `Start_fatal_err (Terrat_session.show_err err))
    (Terrat_session.try_create_wrapper
       ~cookie_name:(Terrat_config.session_cookie_name config)
       storage)

let routes _ = []
let wrap _ = CCFun.id
let stop _ = Abb.Future.return ()

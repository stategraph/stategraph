module Provider = Sgs_service_oauth2_provider

type t = { provider : Provider.t option }
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let ty = Ty

let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
  match q with
  | Ty -> Some Sgs_service.Refl
  | _ -> None

let name = "oauth2"

type opt = Sgs_svc_mngr.t

let start mgr =
  let open Abbs_fc.Infix_result_monad in
  Sgs_svc_mngr.load ~name:Sgs_service_config.name Sgs_service_config.Ty mgr
  >>= fun config ->
  let open Abb.Future.Infix_monad in
  Provider.create config
  >>| function
  | Ok provider -> Ok { provider = Some provider }
  | Error `No_oauth_config -> Ok { provider = None }
  | Error (`Invalid_config msg) -> Error (`Start_fatal_err ("OAUTH2_CONFIG : " ^ msg))
  | Error err -> Error (`Start_err ("OAUTH2_SETUP : " ^ Provider.show_create_err err))

let routes _ = []
let wrap _ = CCFun.id
let stop _ = Abb.Future.return ()
let provider t = t.provider

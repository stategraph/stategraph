type t = {
  config : Terrat_config.t;
  storage : Terrat_storage.t;
  infracost : Terrat_ep_infracost.backend option;
  nginx_metrics : unit Abb.Future.t option;
  session : Sgs_service_terrat_session.t;
}

type opt = Sgs_svc_mngr.t
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let ty = Ty

let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
  match q with
  | Ty -> Some Sgs_service.Refl
  | _ -> None

let name = "terrat_api"

let nginx_metrics config =
  match Terrat_config.nginx_status_uri config with
  | Some uri -> Abb.Future.fork (Terrat_nginx_metrics.start uri) |> Abb.Future.map CCOption.return
  | None -> Abb.Future.return None

let start mgr =
  let open Abbs_fc.Infix_result_monad in
  Sgs_svc_mngr.load ~name:Sgs_service_terrat_config.name Sgs_service_terrat_config.Ty mgr
  >>= fun config ->
  let storage = Sgs_service_terrat_config.storage config
  and config = Sgs_service_terrat_config.config config in
  Sgs_svc_mngr.load ~name:Sgs_service_terrat_session.name Sgs_service_terrat_session.Ty mgr
  >>= fun session ->
  let open Abb.Future.Infix_monad in
  Terrat_ep_infracost.create_backend config
  >>= fun infracost ->
  Terrat_server.start_telemetry config
  >>= fun () ->
  nginx_metrics config
  >>= fun nginx_metrics -> Abbs_fc.return_ok { config; storage; infracost; nginx_metrics; session }

let routes { config; storage; infracost; nginx_metrics = _; session = _ } =
  Terrat_server.api_routes ~infracost config storage

let wrap { config = _; storage = _; infracost = _; nginx_metrics = _; session } = session

let stop { config = _; storage = _; infracost = _; nginx_metrics; session = _ } =
  CCOption.map_or ~default:(Abb.Future.return ()) Abb.Future.abort nginx_metrics

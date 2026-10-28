module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let terrateam () = Brtl_rtng.Route.(api_v1 () / "terrateam")
  let whoami () = Brtl_rtng.Route.(terrateam () / "whoami")
  let task () = Brtl_rtng.Route.(terrateam () / "tasks" /% Path.ud Uuidm.of_string)
  let logout () = Brtl_rtng.Route.(api_v1 () / "logout")
  let server_config () = Brtl_rtng.Route.(api_v1 () / "server" / "config")
end

module Make (Github : Sgs_service_terrat_vcs.S) (Gitlab : Sgs_service_terrat_vcs.S) = struct
  type t = {
    config : Terrat_config.t;
    storage : Terrat_storage.t;
    services : Terrat_vcs_service.service list;
    session : Sgs_service_terrat_session.t;
  }

  type opt = Sgs_svc_mngr.t
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = "terrat_ui"

  let start mgr =
    let open Abbs_fc.Infix_result_monad in
    Sgs_svc_mngr.load ~name:Sgs_service_terrat_config.name Sgs_service_terrat_config.Ty mgr
    >>= fun config ->
    let storage = Sgs_service_terrat_config.storage config
    and config = Sgs_service_terrat_config.config config in
    Abbs_fc.Result.all3
      (Sgs_svc_mngr.load ~name:Github.name Github.Ty mgr)
      (Sgs_svc_mngr.load ~name:Gitlab.name Gitlab.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_terrat_session.name Sgs_service_terrat_session.Ty mgr)
    >>| fun (github, gitlab, session) ->
    {
      config;
      storage;
      services = CCList.filter_map CCFun.id [ Github.service github; Gitlab.service gitlab ];
      session;
    }

  let routes { config; storage; services; session = _ } =
    Brtl_rtng.Route.
      [
        (`GET, Rt.whoami () --> Terrat_ep_whoami.get config storage services);
        (`GET, Rt.task () --> Terrat_ep_tasks.get storage);
        (`POST, Rt.logout () --> Terrat_ep_logout.post config storage);
        (`GET, Rt.server_config () --> Terrat_ep_server.Config.get config);
      ]

  let wrap { config = _; storage = _; services = _; session } = session
  let stop _ = Abb.Future.return ()
end

module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let whoami () = Brtl_rtng.Route.(api_v1 () / "whoami")

  (* OAuth2 flow - /oauth2/{provider}/* paths *)
  let oauth2_start () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "start")
  let oauth2_callback () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "callback")

  (* Login endpoints. The provider is a literal segment. *)
  let login provider =
    Brtl_rtng.Route.(api_v1 () / "login" / provider /? Query.(option (string "rd")))

  let login_options () = Brtl_rtng.Route.(api_v1 () / "login" / "options")
  let login_password () = Brtl_rtng.Route.(api_v1 () / "login" / "password")
  let logout () = Brtl_rtng.Route.(api_v1 () / "logout" /? Query.(option (string "rd")))

  let set_cookie () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "auth"
      / "set-cookie"
      /? Query.string "session-id"
      /? Query.(option (string "redirect")))
end

module Make (Cloud : Sgs_cloud.S) = struct
  module Ep_oauth2_callback = Sgs_service_auth_ep_oauth2_callback.Make (Cloud)

  type t = {
    config : Sgs_config.t;
    storage : Sgs_storage.t;
    (* The OAuth2 provider, when OAuth is configured. *)
    oauth2 : Sgs_service_oauth2.Provider.t option;
  }

  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty

  let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
    match q with
    | Ty -> Some Sgs_service.Refl
    | _ -> None

  let name = "auth"

  type opt = Sgs_svc_mngr.t

  let start mgr =
    let open Abbs_fc.Infix_result_monad in
    Abbs_fc.Result.all4
      (Sgs_svc_mngr.load ~name:Sgs_service_config.name Sgs_service_config.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_storage.name Sgs_service_storage.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_scheduler.name Sgs_service_scheduler.Ty mgr)
      (Sgs_svc_mngr.load ~name:Sgs_service_oauth2.name Sgs_service_oauth2.Ty mgr)
    >>= fun (config, storage, scheduler, oauth2) ->
    Sgs_service_scheduler.register_scheduled_kind
      scheduler
      ~kind:(Sgs_service_scheduler.Id.of_string Sgs_service_auth_login_session_gc.kind)
      Sgs_service_scheduler.Schedule.Hourly
      Sgs_service_auth_login_session_gc.run
    |> Abb.Future.map (fun () -> Ok ())
    >>= fun () ->
    Sgs_service_scheduler.register_scheduled_kind
      scheduler
      ~kind:(Sgs_service_scheduler.Id.of_string Sgs_service_auth_oauth2_session_gc.kind)
      Sgs_service_scheduler.Schedule.Hourly
      Sgs_service_auth_oauth2_session_gc.run
    |> Abb.Future.map (fun () ->
        Ok { config; storage; oauth2 = Sgs_service_oauth2.provider oauth2 })

  let oauth2_routes config storage oauth2 =
    match oauth2 with
    | None -> []
    | Some oauth2 ->
        Brtl_rtng.Route.
          [
            (`GET, Rt.oauth2_start () --> Sgs_service_auth_ep_oauth2_start.run oauth2);
            (`GET, Rt.oauth2_callback () --> Ep_oauth2_callback.run config storage oauth2);
          ]

  (* The login route answers for the configured provider only. *)
  let login_routes config oauth2 =
    match Sgs_config.oauth2 config with
    | None -> []
    | Some oauth_config ->
        let provider = oauth_config.Sgs_config.oauth2_provider_name in
        Brtl_rtng.Route.
          [ (`GET, Rt.login provider --> Sgs_service_auth_ep_login.run config oauth2 provider) ]

  let routes { config; storage; oauth2 } =
    Brtl_rtng.Route.
      [
        (`GET, Rt.whoami () --> Sgs_service_auth_ep_whoami.run config storage);
        (`GET, Rt.set_cookie () --> Sgs_service_auth_ep_set_cookie.run config storage);
        (* Login endpoints *)
        (`GET, Rt.login_options () --> Sgs_service_auth_ep_login.options config);
        (`POST, Rt.login_password () --> Sgs_service_auth_ep_login_password.run config storage);
        (`GET, Rt.logout () --> Sgs_service_auth_ep_login.logout config);
      ]
    @ login_routes config oauth2
    @ oauth2_routes config storage oauth2

  let wrap _ = CCFun.id
  let stop _ = Abb.Future.return ()
end

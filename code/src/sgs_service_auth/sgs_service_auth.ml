let src = Logs.Src.create "service_auth"

module Logs = (val Logs.src_log src : Logs.LOG)

module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let whoami () = Brtl_rtng.Route.(api_v1 () / "whoami")

  (* OAuth2 proxy routes - catch all /oauth2/{provider}/* paths *)
  let oauth2_start () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "start")
  let oauth2_callback () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "callback")
  let oauth2_sign_in () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "sign_in")
  let oauth2_sign_out () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "sign_out")
  let oauth2_auth () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "auth")
  let oauth2_userinfo () = Brtl_rtng.Route.(rel / "oauth2" /% Path.string / "userinfo")

  (* OAuth2 complete - StateGraph callback after oauth2-proxy authentication *)
  let oauth2_complete () =
    Brtl_rtng.Route.(
      api_v1 () / "oauth2" /% Path.string / "complete" /? Query.(option (string "rd")))

  (* Login endpoints *)
  let login () =
    Brtl_rtng.Route.(api_v1 () / "login" /% Path.string /? Query.(option (string "rd")))

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

  (* OAuth2 Session Storage - internal endpoints for oauth2-proxy *)
  let oauth2_session_rt () =
    Brtl_rtng.Route.(
      rel
      / "internal"
      / "oauth2-sessions"
      /% Path.string
      / "sessions"
      /% Path.string
      /* Body.decode ~json:Sgs_service_auth_ep_oauth2_sessions.Put_request.of_yojson ())

  let oauth2_session_get_rt () =
    Brtl_rtng.Route.(
      rel / "internal" / "oauth2-sessions" /% Path.string / "sessions" /% Path.string)

  let oauth2_health_rt () =
    Brtl_rtng.Route.(rel / "internal" / "oauth2-sessions" /% Path.string / "health")
end

module Make (Cloud : Sgs_cloud.S) = struct
  module Ep_oauth2_callback = Sgs_service_auth_ep_oauth2_callback.Make (Cloud)

  (* The oauth2-proxy process, when OAuth is configured and the process started. *)
  type t = Sgs_service_auth_oauth2_proxy.t option
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty

  let ty = Ty
  let name = "auth"

  (* A failure to spawn oauth2-proxy does not stop the server: it serves without OAuth, as logged. *)
  let start config _storage =
    let open Abb.Future.Infix_monad in
    Sgs_service_auth_oauth2_proxy.spawn config
    >>= function
    | Ok oauth2_proxy -> Abbs_fc.return_ok (Some oauth2_proxy)
    | Error `No_oauth_config -> Abbs_fc.return_ok None
    | Error (`Spawn_failed _ | #Abb_intf.Errors.spawn) ->
        Logs.warn (fun m -> m "OAuth authentication will not be available");
        Abbs_fc.return_ok None

  (* Build OAuth2 proxy routes if oauth2_proxy is available *)
  let oauth2_routes config storage oauth2_proxy =
    match oauth2_proxy with
    | None -> []
    | Some proxy ->
        Brtl_rtng.Route.
          [
            (* All methods for each OAuth2 endpoint - provider extracted from path, stripped when proxying *)
            ( `GET,
              Rt.oauth2_start ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "start" );
            ( `GET,
              Rt.oauth2_callback ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "callback" );
            ( `GET,
              Rt.oauth2_sign_in ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "sign_in" );
            ( `POST,
              Rt.oauth2_sign_in ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "sign_in" );
            ( `GET,
              Rt.oauth2_sign_out ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "sign_out" );
            ( `POST,
              Rt.oauth2_sign_out ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "sign_out" );
            ( `GET,
              Rt.oauth2_auth ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "auth" );
            ( `GET,
              Rt.oauth2_userinfo ()
              --> fun provider -> Sgs_service_auth_ep_oauth2_proxy.run ~provider proxy "userinfo" );
            (* StateGraph callback - creates user and session after oauth2-proxy auth *)
            (`GET, Rt.oauth2_complete () --> Ep_oauth2_callback.run config storage proxy);
          ]

  let routes oauth2_proxy config storage =
    Brtl_rtng.Route.
      [
        (`GET, Rt.whoami () --> Sgs_service_auth_ep_whoami.run config storage);
        (`GET, Rt.set_cookie () --> Sgs_service_auth_ep_set_cookie.run config storage);
        (* Login endpoints - login_options and login_password must come before login to avoid {provider} matching *)
        (`GET, Rt.login_options () --> Sgs_service_auth_ep_login.options config);
        (`POST, Rt.login_password () --> Sgs_service_auth_ep_login_password.run config storage);
        (`GET, Rt.login () --> Sgs_service_auth_ep_login.run config oauth2_proxy);
        (`GET, Rt.logout () --> Sgs_service_auth_ep_login.logout config);
        (* OAuth2 Session Storage - internal endpoints for oauth2-proxy *)
        ( `PUT,
          Rt.oauth2_session_rt () --> Sgs_service_auth_ep_oauth2_sessions.Put.run config storage );
        ( `GET,
          Rt.oauth2_session_get_rt () --> Sgs_service_auth_ep_oauth2_sessions.Get.run config storage
        );
        ( `DELETE,
          Rt.oauth2_session_get_rt ()
          --> Sgs_service_auth_ep_oauth2_sessions.Delete.run config storage );
        ( `GET,
          Rt.oauth2_health_rt () --> Sgs_service_auth_ep_oauth2_sessions.Health.run config storage
        );
      ]
    @ oauth2_routes config storage oauth2_proxy

  let stop = function
    | Some oauth2_proxy -> Sgs_service_auth_oauth2_proxy.stop oauth2_proxy
    | None -> Abb.Future.return ()
end

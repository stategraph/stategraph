let src = Logs.Src.create "server"

module Logs = (val Logs.src_log src : Logs.LOG)

type route = Sgs_service.route

module Rt = struct
  let api_v1 () = Brtl_rtng.Route.(rel / "api" / "v1")
  let health () = Brtl_rtng.Route.(api_v1 () / "health")
  let version () = Brtl_rtng.Route.(api_v1 () / "version")
  let openapi () = Brtl_rtng.Route.(api_v1 () / "openapi")
  let capabilities () = Brtl_rtng.Route.(api_v1 () / "capabilities")

  (* MQL *)
  let mql () =
    Brtl_rtng.Route.(
      api_v1 ()
      / "mql"
      /? Query.(string "q")
      /? Query.(option (string "tz"))
      /? Query.(
           option
             (ud
                "page"
                CCFun.(
                  CCOption.wrap Yojson.Safe.from_string
                  %> CCOption.flat_map (Mql_to_pgsql.Page.of_yojson %> CCResult.to_opt)))))

  let mql_schema () = Brtl_rtng.Route.(api_v1 () / "mql" / "schema")
end

let response_404 =
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx))

let rtng ~routes config storage =
  let base_routes =
    Brtl_rtng.Route.
      [
        (`GET, Rt.health () --> Sgs_server_ep_health.run config storage);
        (`GET, Rt.version () --> Sgs_server_ep_version.run config storage);
        (`GET, Rt.openapi () --> Sgs_server_ep_openapi.run config storage);
        (`GET, Rt.capabilities () --> Sgs_server_ep_capabilities.run config storage);
        (* Mql *)
        (`GET, Rt.mql () --> Sgs_mql_ep.run config storage);
        (`GET, Rt.mql_schema () --> Sgs_mql_ep.Schema.run config);
      ]
  in
  let all_routes = base_routes @ routes in
  Brtl_rtng.create ~default:response_404 all_routes

let run ~routes config storage =
  let open Abb.Future.Infix_monad in
  let one_min = Duration.of_min 1 in
  let five_min = Duration.of_min 5 in
  let cfg =
    Brtl_cfg.create ~read_header_timeout:one_min ~handler_timeout:five_min (Sgs_config.port config)
  in
  let mw_log = Brtl_mw_log.(create (Config.make ~remote_ip_header:"X-Forwarded-For" ())) in
  Sgs_user_session.create ~secure_cookies:(Sgs_config.secure_cookies config) storage
  >>= fun mw_session ->
  let middlewares =
    if Sgs_config.enable_cors config then
      [
        mw_log;
        Sgs_server_mw_cors.create ~default_origin:(Sgs_config.cors_default_origin config) ();
        mw_session;
      ]
    else [ mw_log; mw_session ]
  in
  let mw = Brtl_mw.create middlewares in
  Logs.info (fun m -> m "Starting server");
  Brtl.run cfg mw (rtng ~routes config storage)
  >>| function
  | Ok () -> ()
  | Error (`Exn exn) ->
      Logs.err (fun m -> m "%s" (Printexc.to_string exn));
      ()
  | Error `E_address_not_available ->
      Logs.err (fun m -> m "Failed to run server because address not available");
      ()
  | Error `E_address_family_not_supported ->
      Logs.err (fun m -> m "Failed to run server because address family not supported");
      ()
  | Error `E_address_in_use ->
      Logs.err (fun m -> m "Failed to run server because address already in use");
      ()

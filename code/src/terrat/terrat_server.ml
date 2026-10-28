module Metrics = struct
  module Histogram = Prmths.Histogram (struct
    let spec =
      Prmths.Histogram_spec.of_list [ 0.1; 0.25; 0.5; 1.0; 2.5; 5.0; 10.0; 20.0; 30.0; 60.0 ]
  end)

  let request_duration =
    let help = "HTTP request duration in seconds" in
    Histogram.v_labels
      ~label_names:[ "method" ]
      ~help
      ~namespace:"terrat"
      "http_request_duration_seconds"

  let observe _uri meth duration =
    let meth_str = Cohttp.Code.string_of_method meth in
    Histogram.observe (Histogram.labels request_duration [ meth_str ]) duration
end

module Rt = struct
  let api () = Brtl_rtng.Route.(rel / "api")
  let api_404 () = Brtl_rtng.Route.(api () /% Path.any)
  let api_v1 () = Brtl_rtng.Route.(api () / "v1")
  let whoami () = Brtl_rtng.Route.(api_v1 () / "whoami")
  let logout () = Brtl_rtng.Route.(api_v1 () / "logout")
  let server_config () = Brtl_rtng.Route.(api_v1 () / "server" / "config")
  let health_check () = Brtl_rtng.Route.(rel / "health")

  (* The [Path.string] before "infracost" is so that we can ignore any
     underlying VCS-based API base URL. *)
  let infracost () = Brtl_rtng.Route.(api () /% Path.string / "infracost" /% Path.any)
  let metrics () = Brtl_rtng.Route.(rel / "metrics")

  (* Admin interface *)
  let admin_rt () = Brtl_rtng.Route.(api_v1 () / "admin")
  let admin_drift_list_rt () = Brtl_rtng.Route.(admin_rt () / "drifts")

  (* Tasks API *)
  let tasks_api_rt () = Brtl_rtng.Route.(api_v1 () / "tasks")
  let task_rt () = Brtl_rtng.Route.(tasks_api_rt () /% Path.ud Uuidm.of_string)

  (* Tenv *)
  let tenv_rt () =
    Brtl_rtng.Route.(rel / "api" /% Path.string / "tenv" /% Path.ud Uuidm.of_string /% Path.any)

  (* Access token *)
  let access_token_refresh_rt () = Brtl_rtng.Route.(rel / "api" / "v1" / "access-token" / "refresh")
end

let response_404 =
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx))

let maybe_add_admin_routes config storage =
  (* Very important, we only want to add these endpoints if the admin token is
       set.  The admin token is really only meant for debugging purposes. *)
  match Terrat_config.admin_token config with
  | Some token ->
      Brtl_rtng.Route.
        [
          (`GET, Rt.admin_drift_list_rt () --> Terrat_ep_admin.Drift.List.get token config storage);
        ]
  | None -> []

let api_routes ~infracost config storage =
  maybe_add_admin_routes config storage
  @ Brtl_rtng.Route.
      [
        (* Ops *)
        (`GET, Rt.health_check () --> Terrat_ep_health_check.get storage);
        (`GET, Rt.metrics () --> Terrat_ep_metrics.get);
        (* Tenv *)
        (`GET, Rt.tenv_rt () --> Terrat_ep_tenv.get config storage);
        (* Access token *)
        (`POST, Rt.access_token_refresh_rt () --> Terrat_ep_access_token.Refresh.post config storage);
        (* Infracost *)
        (`POST, Rt.infracost () --> fun _ -> Terrat_ep_infracost.post infracost storage);
      ]

(* The routes do not overlap, so their order only matters for the API 404s, which come last. *)
let rtng ~infracost config storage services =
  let routes =
    CCList.flat_map
      (function
        | Terrat_vcs_service.Service ((module M), service) -> M.Service.routes service)
      services
  in
  Brtl_rtng.create
    ~default:
      (Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
           Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)))
    (api_routes ~infracost config storage
    @ Brtl_rtng.Route.(
        [ (* Tasks *) (`GET, Rt.task_rt () --> Terrat_ep_tasks.get storage) ]
        @ routes
        @ [
            (* User *)
            (`GET, Rt.whoami () --> Terrat_ep_whoami.get config storage services);
            (`POST, Rt.logout () --> Terrat_ep_logout.post config storage);
            (* Server *)
            (`GET, Rt.server_config () --> Terrat_ep_server.Config.get config);
            (* API 404s.  This is needed because for any and only UI endpoint we
               want to return the HTML *)
            (`GET, Rt.api_404 () --> fun _ ctx -> response_404 ctx);
            (`PUT, Rt.api_404 () --> fun _ ctx -> response_404 ctx);
            (`POST, Rt.api_404 () --> fun _ ctx -> response_404 ctx);
            (`DELETE, Rt.api_404 () --> fun _ ctx -> response_404 ctx);
          ]))

let start_telemetry config =
  match Terrat_config.telemetry config with
  | Terrat_config.Telemetry.Disabled ->
      Logs.info (fun m -> m "Telemetry disabled");
      Abbs_fc.unit
  | Terrat_config.Telemetry.Anonymous uri as tc ->
      let open Abb.Future.Infix_monad in
      Logs.info (fun m -> m "Telemetry enabled with endpoint %a" Uri.pp uri);
      (match Terrat_config.github config with
        | Some github ->
            Terrat_telemetry.send
              tc
              (Terrat_telemetry.Event.Start
                 { app_type = "github"; app_id = Terrat_config.Github.app_id github })
        | None -> Abb.Future.return ())
      >>= fun () -> Abbs_fc.ignore (Abb.Future.fork (Terrat_telemetry.start_ping_loop config))

let run ~infracost config storage services =
  let open Abbs_fc.Infix_result_monad in
  let one_min = Duration.of_min 1 in
  let five_min = Duration.of_min 5 in
  let cfg =
    Brtl_cfg.create
      ~read_header_timeout:one_min
      ~handler_timeout:five_min
      (Terrat_config.port config)
  in
  let mw_log =
    Brtl_mw_log.(
      create (Config.make ~remote_ip_header:"X-Forwarded-For" ~metrics:Metrics.observe ()))
  in
  Logs.info (fun m -> m "Creating storage connection");
  Terrat_session.try_create ~cookie_name:(Terrat_config.session_cookie_name config) storage
  >>= fun mw_session ->
  let open Abb.Future.Infix_monad in
  let mw = Brtl_mw.create [ mw_log; mw_session ] in
  Logs.info (fun m -> m "Starting server");
  start_telemetry config
  >>= fun () ->
  Abb.Future.fork
    (match Terrat_config.nginx_status_uri config with
    | Some uri ->
        Logs.info (fun m -> m "Starting nginx metrics: %s" (Uri.to_string uri));
        Terrat_nginx_metrics.start uri
    | None -> Abb.Future.return ())
  >>= fun _ ->
  Brtl.run cfg mw (rtng ~infracost config storage services)
  >>| function
  | Ok () -> Ok ()
  | Error (`Exn exn) ->
      Logs.err (fun m -> m "%s" (Printexc.to_string exn));
      Ok ()
  | Error `E_address_not_available ->
      Logs.err (fun m -> m "Failed to run server because address not available");
      Ok ()
  | Error `E_address_family_not_supported ->
      Logs.err (fun m -> m "Failed to run server because address family not supported");
      Ok ()
  | Error `E_address_in_use ->
      Logs.err (fun m -> m "Failed to run server because address already in use");
      Ok ()

module Cmdline = struct
  module C = Cmdliner

  let reporter ppf =
    let report src level ~over k msgf =
      let k _ =
        over ();
        k ()
      in
      let with_stamp h _tags k ppf fmt =
        (* TODO: Make this use the proper Abb time *)
        let time = Unix.gettimeofday () in
        let time_str = ISO8601.Permissive.string_of_datetime time in
        Format.kfprintf
          k
          ppf
          ("[%s] %a [%s] @[" ^^ fmt ^^ "@]@.")
          time_str
          Logs.pp_header
          (level, h)
          (Logs.Src.name src)
      in
      msgf @@ fun ?header ?tags fmt -> with_stamp header tags k ppf fmt
    in
    { Logs.report }

  let setup_log level loggers =
    Format.set_geometry ~max_indent:490 ~margin:500;
    let loggers =
      CCOption.map_or
        ~default:[]
        (fun loggers ->
          loggers
          |> CCString.split_on_char ','
          |> CCList.map (function
            | logger when CCString.length logger > 0 && CCString.get logger 0 = '+' ->
                (`Add, CCString.drop 1 logger)
            | logger when CCString.length logger > 0 && CCString.get logger 0 = '-' ->
                (`Remove, CCString.drop 1 logger)
            | logger -> raise (Failure (Printf.sprintf "Unknown logger: %S" logger))))
        loggers
    in
    Logs.set_reporter (reporter Format.err_formatter);
    Logs.set_level level;
    let default_remove_loggers =
      [
        "abb.dns";
        "abb_curl";
        "abb_curl_easy";
        "brtl_mw_log.pre";
        "cohttp_abb";
        "cohttp_abb.io";
        "cohttp_abb.tls";
        "dns_cache";
        "dns_client";
        "happy-eyeballs";
        "pgsql.io";
        "pgsql.pool";
        "vcs_event_evaluator2_builder.github.run_db";
        "vcs_event_evaluator2_builder.gitlab.run_db";
      ]
    in
    let all_logger_names = CCList.map Logs.Src.name (Logs.Src.list ()) in
    let loggers =
      CCList.fold_left
        (fun acc -> function
          | `Add, "*" -> []
          | `Remove, "*" -> all_logger_names
          | `Add, logger -> CCList.remove ~eq:CCString.equal ~key:logger acc
          | `Remove, logger -> logger :: acc)
        default_remove_loggers
        loggers
    in
    CCList.iter
      (fun src ->
        if CCList.mem ~eq:CCString.equal (Logs.Src.name src) loggers then
          Logs.Src.set_level src (Some Logs.Error))
      (Logs.Src.list ());
    Logs_threaded.enable ()

  let loggers =
    let env =
      let doc = "Specify logging subsystems" in
      C.Cmd.Env.info ~doc "STATEGRAPH_LOGGERS"
    in
    let doc = "Specify logging subsystems.  Comma separated." in
    C.Arg.(value & opt (some string) None & info [ "loggers" ] ~env ~doc)

  let logs =
    let env_info = C.Cmd.Env.info "STATEGRAPH_LOG_LEVEL" in
    C.Term.(const setup_log $ Logs_cli.level ~env:env_info () $ loggers)

  let server_cmd f =
    let doc = "Run server" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "server" ~doc ~exits) C.Term.(const f $ logs)

  let migrate_cmd f =
    let doc = "Perform migration" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "migrate" ~doc ~exits) C.Term.(const f $ logs)

  let version_cmd =
    let doc = "Print version" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "version" ~doc ~exits)
      C.Term.(const (fun () -> print_endline Sg_version.version) $ const ())

  let default_cmd = C.Term.(ret (const (`Help (`Pager, None))))
end

(* [routes], each of whose handlers runs in [wrap]. *)
let wrap_routes wrap routes =
  CCList.map (fun (meth, route) -> (meth, Brtl_rtng.Route.Route.map wrap route)) routes

(* The routes of a started service, each running in the service's wrapper. *)
let service_routes (Sgs_service.Started ((module M), t)) = wrap_routes (M.wrap t) (M.routes t)

(* Runs the server with the build's services, and with its orchestration services when
   orchestration is enabled. The storage service is registered with the build's services, the config
   service among them, so every service loads both like any other dependency; the boot loads the
   values itself for the listener. The orchestration services register once the others are up, so
   their routes come after every other route. One of them refusing for good is fatal when
   orchestration was asked for explicitly; otherwise the server runs without them. *)
let run_server ~services ~orchestration_services mgr =
  let open Abbs_fc.Infix_result_monad in
  let register services =
    Abbs_fc.Result.map_err
      ~f:(fun `Register_err -> `Start_err "SERVICE_MANAGER : could not register the services")
      (Sgs_svc_mngr.register' mgr services)
  in
  register ((module Sgs_service_storage) :: services)
  >>= fun () ->
  (* A service whose start never succeeds keeps this undetermined, so the boot waits here until
     every service is up. *)
  Sgs_svc_mngr.started mgr
  >>= fun () ->
  Abbs_fc.Result.all2
    (Sgs_svc_mngr.load ~name:Sgs_service_config.name Sgs_service_config.Ty mgr)
    (Sgs_svc_mngr.load ~name:Sgs_service_storage.name Sgs_service_storage.Ty mgr)
  >>= fun (config, storage) ->
  print_endline (Sgs_config.show config);
  (match Sgs_config.orchestration_enabled config with
    | true -> (
        register orchestration_services
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        Sgs_svc_mngr.started mgr
        >>= function
        | Ok () -> Abbs_fc.return_ok ()
        | Error (`Start_fatal_err msg) when not (Sgs_config.orchestration_explicit config) ->
            Abbs_fc.return_err (`Orchestration_unavailable msg)
        | Error (`Start_fatal_err _) as err -> Abb.Future.return err)
    | false -> Abbs_fc.return_ok ())
  >>= fun () ->
  Abbs_fc.Result.map_err
    ~f:(fun `Routes_err -> `Start_err "SERVICE_MANAGER : could not collect the routes")
    (Sgs_svc_mngr.routes mgr service_routes)
  >>= fun routes -> Abb.Future.map (fun () -> Ok ()) (Sgs_server.run ~routes config storage)

(* A service whose stop never ends must not keep the process from exiting, so the stop is bounded. *)
let stop_timeout = 10.0

let stop_services mgr =
  let open Abb.Future.Infix_monad in
  Abbs_fc.timeout ~timeout:(Abb.Sys.sleep stop_timeout) (Sgs_svc_mngr.stop mgr)
  >>| function
  | `Ok () -> `Stopped
  | `Timeout ->
      Logs.err (fun m ->
          m "SERVICE_MANAGER : the services did not stop within %.0fs, exiting anyway" stop_timeout);
      `Timeout

(* Stopping the manager stops the services it started, whether the server ran or the boot failed.
   When orchestration is unavailable, the boot starts again without the orchestration services, on a
   manager of its own, so none of them is left half started. Services that did not stop in time may
   still run, so the process exits instead: starting again would run them twice. *)
let server' ~services ~orchestration_services =
  let rec run ~orchestration_services () =
    let open Abb.Future.Infix_monad in
    Sgs_svc_mngr.start ()
    >>= function
    | Error `Start_err -> Abbs_fc.return_err (`Start_err "Could not start the service manager")
    | Ok mgr -> (
        Abbs_fc.on_failure
          (fun () -> run_server ~services ~orchestration_services mgr)
          ~failure:(fun () -> Abb.Future.map (fun (`Stopped | `Timeout) -> ()) (stop_services mgr))
        >>= fun result ->
        stop_services mgr
        >>= fun stopped ->
        match result with
        | Error (`Orchestration_unavailable msg) -> (
            Logs.err (fun m ->
                m
                  {|Orchestration failed to start; orchestration is unavailable.
Set STATEGRAPH_ORCHESTRATION_ENABLED=false to stop trying, or fix: %s|}
                  msg);
            match stopped with
            | `Stopped -> run ~orchestration_services:[] ()
            | `Timeout ->
                Abbs_fc.return_err
                  (`Start_err
                     "SERVICE_MANAGER : the server cannot start again without orchestration while \
                      its services may still run"))
        | (Ok () | Error #Sgs_service.start_err) as result -> Abb.Future.return result)
  in
  let result = Abb.Scheduler.run_with_state (run ~orchestration_services) in
  match result with
  | `Det (Ok ()) -> ()
  | `Det (Error (#Sgs_service.start_err as err)) ->
      Logs.err (fun m -> m "%a" Sgs_service.pp_start_err err);
      exit 1
  | `Aborted -> assert false
  | `Exn (exn, bt_opt) ->
      Logs.err (fun m -> m "%s" (Printexc.to_string exn));
      CCOption.iter
        (fun bt -> Logs.err (fun m -> m "%s" (Printexc.raw_backtrace_to_string bt)))
        bt_opt;
      assert false

let server ~services ~orchestration_services () = server' ~services ~orchestration_services

(* An orchestration step of [migrate]. Its failure stops the migration only when orchestration was
   asked for explicitly. Otherwise the step logs the failure, and the deployment runs without
   orchestration. *)
let orchestration_step ~name ~remedy ~pp_err ~wrap config step =
  let open Abb.Future.Infix_monad in
  step
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error err when not (Sgs_config.orchestration_explicit config) ->
      Logs.err (fun m ->
          m
            {|%s failed; orchestration is unavailable.
Set STATEGRAPH_ORCHESTRATION_ENABLED=false to stop trying, or %s.|}
            name
            remedy);
      Logs.err (fun m -> m "%a" pp_err err);
      Abbs_fc.return_ok ()
  | Error err -> Abbs_fc.return_err (wrap err)

(* The migrations and the FDW reconcile do not read who supplies the GitHub App, so the
     configuration takes the default. *)
let migrate () =
  match Sgs_config.create () with
  | Ok config -> (
      let run () =
        let open Abb.Future.Infix_monad in
        Sgs_storage.create config
        >>= fun storage ->
        let open Abbs_fc.Infix_result_monad in
        Sgs_migrations.run config storage
        >>= fun () ->
        (* The FDW bridge is a function of env, not a migration; reconcile
           it after the stream so orchestration deployments converge on
           the current config + catalog every boot. *)
        orchestration_step
          ~name:"FDW reconcile"
          ~remedy:"give the database role the rights the bridge needs"
          ~pp_err:Sgs_cli_lib_fdw_reconcile.pp_err
          ~wrap:(fun err -> `Fdw_reconcile_err err)
          config
          (Sgs_cli_lib_fdw_reconcile.run config storage)
        >>= fun () ->
        orchestration_step
          ~name:"Terrateam database setup"
          ~remedy:"make the terrateam database (TERRAT_DB_*) reachable and migratable"
          ~pp_err:Sgs_cli_lib_terrat_migrate.pp_err
          ~wrap:(fun err -> `Terrat_migrate_err err)
          config
          (Sgs_cli_lib_terrat_migrate.run config)
      in
      print_endline (Sgs_config.show config);
      match Abb.Scheduler.run_with_state run with
      | `Det (Ok ()) -> Logs.info (fun m -> m "Migration complete")
      | `Det (Error (`Migration_err (#Pgsql_io.err as err))) ->
          Logs.err (fun m -> m "Migration failed");
          Logs.err (fun m -> m "%s" (Pgsql_io.show_err err));
          exit 1
      | `Det (Error (`Migration_err (#Pgsql_pool.err as err))) ->
          Logs.err (fun m -> m "Migration failed");
          Logs.err (fun m -> m "%s" (Pgsql_pool.show_err err));
          exit 1
      | `Det (Error (`Migration_err (`Mql_err err))) ->
          Logs.err (fun m -> m "Migration failed - MQL could not read the migration");
          Logs.err (fun m -> m "%s" (Mql.Ast.show_err err));
          exit 1
      | `Det (Error (`Consistency_err consistency)) ->
          Logs.err (fun m ->
              m
                "Migration failed - inconsistent migrations: %s"
                (Data_mig.Error.Consistency.to_string consistency));
          exit 1
      | `Det (Error (`Fdw_reconcile_err err)) ->
          Logs.err (fun m -> m "FDW reconcile failed, and orchestration was asked for");
          Logs.err (fun m -> m "%s" (Sgs_cli_lib_fdw_reconcile.show_err err));
          exit 1
      | `Det (Error (`Terrat_migrate_err err)) ->
          Logs.err (fun m -> m "Terrateam database setup failed, and orchestration was asked for");
          Logs.err (fun m -> m "%a" Sgs_cli_lib_terrat_migrate.pp_err err);
          exit 1
      | `Aborted -> assert false
      | `Exn (exn, bt_opt) ->
          Logs.err (fun m -> m "%s" (Printexc.to_string exn));
          CCOption.iter
            (fun bt -> Logs.err (fun m -> m "%s" (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          assert false)
  | Error (#Sgs_config.err as err) ->
      Logs.err (fun m -> m "Config file failed to load %a" Sgs_config.pp_err err);
      exit 1

let cmds ~services ~orchestration_services =
  Cmdline.
    [
      server_cmd (server ~services ~orchestration_services);
      migrate_cmd migrate;
      version_cmd;
      Sgs_cli_lib_test.cmd logs;
    ]

let main ~services ~orchestration_services =
  Random.self_init ();
  Mirage_crypto_rng_unix.use_default ();
  let info =
    Cmdliner.Cmd.info ~doc:"Operate the Stategraph server" (Filename.basename Sys.argv.(0))
  in
  exit
  @@ Cmdliner.Cmd.eval
  @@ Cmdliner.Cmd.group ~default:Cmdline.default_cmd info (cmds ~services ~orchestration_services)

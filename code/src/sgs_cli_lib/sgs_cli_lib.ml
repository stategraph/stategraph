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
        "dns_cache";
        "dns_client";
        "happy-eyeballs";
        "pgsql.io";
        "pgsql.pool";
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

module Make (Cloud : Sgs_cloud.S) = struct
  module Server = Sgs_server.Make (Cloud)

  (* Runs the server with the build's services. Stopping the manager at the end stops those
     services too. *)
  let run_server ~services config storage mgr =
    let open Abb.Future.Infix_monad in
    (* The manager starts the build's services, so the routes come from what it started. *)
    Sgs_svc_mngr.start_services mgr services
    >>= function
    | Ok started ->
        let routes = CCList.flat_map (fun s -> Sgs_service.routes s config storage) started in
        Abbs_fc.with_finally
          (fun () -> Server.run ~routes config storage)
          ~finally:(fun () -> Sgs_svc_mngr.stop mgr)
        >>| fun () -> Ok ()
    | Error err -> Abb.Future.return (Error err)

  let server' ~services config =
    let run () =
      let open Abb.Future.Infix_monad in
      Sgs_storage.create config
      >>= fun storage ->
      Sgs_svc_mngr.start config storage
      >>= function
      | Error `Start_err -> Abbs_fc.return_err (`Start_err "Could not start the service manager")
      | Ok mgr -> run_server ~services config storage mgr
    in
    print_endline (Sgs_config.show config);
    let result = Abb.Scheduler.run_with_state run in
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

  let config_github_app_managed () =
    match Cloud.github_app () with
    | `Deployment -> true
    | `Console -> false

  let server ~services () =
    match Sgs_config.create ~github_app_managed:(config_github_app_managed ()) () with
    | Ok config -> server' ~services config
    | Error (#Sgs_config.err as err) ->
        Logs.err (fun m -> m "Config file failed to load %a" Sgs_config.pp_err err);
        exit 1

  let migrate () =
    match Sgs_config.create ~github_app_managed:(config_github_app_managed ()) () with
    | Ok config -> (
        let run () =
          let open Abb.Future.Infix_monad in
          Sgs_storage.create config
          >>= fun storage ->
          Sgs_migrations.run config storage
          >>= function
          | Ok () -> (
              (* The FDW bridge is a function of env, not a migration; reconcile
               it after the stream so orchestration deployments converge on
               the current config + catalog every boot. *)
              Sgs_cli_lib_fdw_reconcile.run config storage
              >>= function
              | Ok () -> Abbs_fc.return_ok ()
              | Error (#Sgs_cli_lib_fdw_reconcile.err as err)
                when not (Sgs_config.orchestration_explicit config) ->
                  Logs.err (fun m ->
                      m
                        "FDW reconcile failed; orchestration is unavailable. Set \
                         STATEGRAPH_ORCHESTRATION_ENABLED=false to stop trying, or give the \
                         database role the rights the bridge needs.");
                  Logs.err (fun m -> m "%s" (Sgs_cli_lib_fdw_reconcile.show_err err));
                  Abbs_fc.return_ok ()
              | Error (#Sgs_cli_lib_fdw_reconcile.err as err) ->
                  Abbs_fc.return_err (`Fdw_reconcile_err err))
          | Error _ as err -> Abb.Future.return err
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

  let cmds ~services =
    Cmdline.
      [ server_cmd (server ~services); migrate_cmd migrate; version_cmd; Sgs_cli_lib_test.cmd logs ]

  let main ~services =
    Random.self_init ();
    Mirage_crypto_rng_unix.use_default ();
    let info =
      Cmdliner.Cmd.info ~doc:"Operate the Stategraph server" (Filename.basename Sys.argv.(0))
    in
    exit
    @@ Cmdliner.Cmd.eval
    @@ Cmdliner.Cmd.group ~default:Cmdline.default_cmd info (cmds ~services)
end

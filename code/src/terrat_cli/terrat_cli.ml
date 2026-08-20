module Metrics = struct
  module Exec_duration_histogram = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_list [ 0.01; 0.05; 0.1; 0.3; 0.5; 0.8; 1.0; 2.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "main"

  let exec_duration =
    let help = "Time scheduler spends processing a loop." in
    Exec_duration_histogram.v ~help ~namespace ~subsystem "exec_duration"
end

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
          ("[%s] %a [%s] " ^^ fmt ^^ "@.")
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
    Logs.set_reporter (reporter Format.std_formatter);
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
        "vcs_event_evaluator2_builder.github.run_db";
        "vcs_event_evaluator2_builder.gitlab.run_db";
      ]
    in
    let loggers =
      CCList.fold_left
        (fun acc -> function
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
      C.Cmd.Env.info ~doc "TERRAT_LOGGERS"
    in
    let doc = "Specify logging subsystems.  Comma separated." in
    C.Arg.(value & opt (some string) None & info [ "loggers" ] ~env ~doc)

  let logs = C.Term.(const setup_log $ Logs_cli.level () $ loggers)

  let app_id =
    let doc = "App ID." in
    C.Arg.(required & opt (some string) None & info [ "app-id" ] ~doc)

  let pem =
    let doc = "PEM file path." in
    C.Arg.(required & opt (some file) None & info [ "pem" ] ~doc)

  let inst_id =
    let doc = "Installation ID." in
    C.Arg.(required & opt (some string) None & info [ "inst-id" ] ~doc)

  let generate_auth_token_cmd f =
    let doc = "Generate an auth token." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "gen-auth-token" ~doc ~exits) C.Term.(const f $ app_id $ pem $ inst_id)

  let server_cmd f =
    let doc = "Run server." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "server" ~doc ~exits) C.Term.(const f $ logs)

  let migrate_cmd f =
    let doc = "Perform migration" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "migrate" ~doc ~exits) C.Term.(const f $ logs)

  let default_cmd = C.Term.(ret (const (`Help (`Pager, None))))
end

let exec_duration duration =
  Metrics.Exec_duration_histogram.observe Metrics.exec_duration duration;
  if duration >= 0.5 then Logs.info (fun m -> m "EXEC_DURATION : %f" duration)

module Make
    (Github : Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Github.t)
    (Gitlab : Terrat_vcs_service.S with type Service.vcs_config = Terrat_config.Gitlab.t) =
struct
  let src = Logs.Src.create "terrat"

  module Logs = (val Logs.src_log src : Logs.LOG)

  let maybe_start_github config storage exec =
    let open Abb.Future.Infix_monad in
    match Terrat_config.github config with
    | Some github -> (
        Logs.info (fun m -> m "Starting GitHub Service");
        Github.Service.start config github storage exec
        >>= function
        | Ok service ->
            Abb.Future.return (Some (Terrat_vcs_service.Service ((module Github), service)))
        | Error `Error ->
            Logs.err (fun m -> m "Failed to start GitHub Service");
            exit 1)
    | None -> Abb.Future.return None

  let maybe_start_gitlab config storage exec =
    let open Abb.Future.Infix_monad in
    match Terrat_config.gitlab config with
    | Some gitlab -> (
        Logs.info (fun m -> m "Starting GitLab Service");
        Gitlab.Service.start config gitlab storage exec
        >>= function
        | Ok service ->
            Abb.Future.return (Some (Terrat_vcs_service.Service ((module Gitlab), service)))
        | Error `Error ->
            Logs.err (fun m -> m "Failed to start GitLab Service");
            exit 1)
    | None -> Abb.Future.return None

  let server () =
    let run () =
      match Terrat_config.create () with
      | Ok config ->
          let open Abb.Future.Infix_monad in
          print_endline (Terrat_config.show config);
          CCOption.iter (fun config ->
              Logs.info (fun m -> m "DYNAMIC_GC : START");
              DynamicGc.setup_dynamic_tuning config)
          @@ (Terrat_config.gc config).Terrat_config.Gc.dynamic_gc;
          Terrat_storage.create config
          >>= fun storage ->
          Terrat_vcs_event_evaluator2.create_exec
            ~slots:(Terrat_config.event_evaluator_slots config)
            ()
          >>= fun exec ->
          maybe_start_github config storage exec
          >>= fun github_service ->
          maybe_start_gitlab config storage exec
          >>= fun gitlab_service ->
          let services = CCOption.to_list github_service @ CCOption.to_list gitlab_service in
          Terrat_server.run config storage services
      | Error err ->
          Logs.err (fun m -> m "CONFIG : ERROR : %s" (Terrat_config.show_err err));
          exit 1
    in
    match
      Abb.Scheduler.run_with_state
        ?thread_pool_size:
          (CCOption.flat_map CCInt.of_string @@ Sys.getenv_opt "TERRAT_SCHEDULER_THREAD_POOL_SIZE")
        ~exec_duration
        run
    with
    | `Det () -> ()
    | `Aborted -> assert false
    | `Exn (exn, bt_opt) ->
        Logs.err (fun m -> m "%s" (Printexc.to_string exn));
        CCOption.iter
          (fun bt -> Logs.err (fun m -> m "%s" (Printexc.raw_backtrace_to_string bt)))
          bt_opt;
        assert false

  let migrate () =
    match Terrat_config.create () with
    | Ok config -> (
        let run () =
          let open Abb.Future.Infix_monad in
          Terrat_storage.create config >>= fun storage -> Terrat_migrations.run config storage
        in
        print_endline (Terrat_config.show config);
        match
          Abb.Scheduler.run_with_state
            ?thread_pool_size:
              (CCOption.flat_map CCInt.of_string
              @@ Sys.getenv_opt "TERRAT_SCHEDULER_THREAD_POOL_SIZE")
            run
        with
        | `Det (Ok ()) -> Logs.info (fun m -> m "Migration complete")
        | `Det (Error (`Migration_err (#Pgsql_io.err as err))) ->
            Logs.err (fun m -> m "Migration failed");
            Logs.err (fun m -> m "%s" (Pgsql_io.show_err err));
            exit 1
        | `Det (Error (`Migration_err (#Pgsql_pool.err as err))) ->
            Logs.err (fun m -> m "Migration failed");
            Logs.err (fun m -> m "%s" (Pgsql_pool.show_err err));
            exit 1
        | `Det (Error `Consistency_err) ->
            Logs.err (fun m -> m "Migration failed - inconsistent migrations");
            exit 1
        | `Aborted -> assert false
        | `Exn (exn, bt_opt) ->
            Logs.err (fun m -> m "%s" (Printexc.to_string exn));
            CCOption.iter
              (fun bt -> Logs.err (fun m -> m "%s" (Printexc.raw_backtrace_to_string bt)))
              bt_opt;
            assert false)
    | Error (#Terrat_config.err as err) ->
        Logs.err (fun m -> m "Config file failed to load %s" (Terrat_config.show_err err));
        exit 1

  let generate_auth_token app_id pem inst_id =
    let run () =
      match Terrat_config.create () with
      | Ok config -> (
          match Terrat_config.github config with
          | Some github -> (
              let open Abb.Future.Infix_monad in
              print_endline (Terrat_config.show config);
              Abb.Sys.time ()
              >>= fun time ->
              let pem =
                match X509.Private_key.decode_pem (CCIO.with_in pem CCIO.read_all) with
                | Ok (`RSA v) -> v
                | Ok _ -> failwith "Expected RSA"
                | Error (`Msg s) -> failwith ("Error: " ^ s)
              in
              let payload =
                let module P = Jwt.Payload in
                let module C = Jwt.Claim in
                P.empty
                |> P.add_claim C.iss (`String app_id)
                |> P.add_claim C.iat (`Int (Float.to_int (time -. 60.0)))
                |> P.add_claim C.exp (`Int (Float.to_int (time +. (60.0 *. 10.0))))
              in
              let signer = Jwt.Signer.(RS256 (Priv_key.of_priv_key pem)) in
              let header = Jwt.Header.create (Jwt.Signer.to_string signer) in
              let jwt = Jwt.of_header_and_payload signer header payload in
              let token = Jwt.token jwt in
              let open Abbs_future_combinators.Infix_result_monad in
              let client = Terrat_github.create github (`Bearer token) in
              Githubc2_abb.call
                client
                Githubc2_apps.Create_installation_access_token.(
                  make (Parameters.make ~installation_id:(CCInt.of_string_exn inst_id)))
              >>= fun resp ->
              match Openapi.Response.value resp with
              | `Created token ->
                  let installation_token = Githubc2_components.Installation_token.value token in
                  print_endline
                    installation_token.Githubc2_components.Installation_token.Primary.token;
                  Abbs_future_combinators.return_ok ()
              | (`Unauthorized _ | `Forbidden _ | `Not_found _ | `Unprocessable_entity _) as err ->
                  failwith (Terrat_github.show_get_installation_access_token_err err))
          | None -> assert false)
      | _ -> assert false
    in
    match Abb.Scheduler.run_with_state run with
    | `Det (Ok ()) -> ()
    | `Det (Error _) -> failwith "err"
    | `Aborted -> assert false
    | `Exn (exn, bt_opt) ->
        Printf.eprintf "%s\n" (Printexc.to_string exn);
        CCOption.iter (fun bt -> Printf.eprintf "%s\n" (Printexc.raw_backtrace_to_string bt)) bt_opt;
        assert false

  let cmds =
    Cmdline.[ server_cmd server; migrate_cmd migrate; generate_auth_token_cmd generate_auth_token ]

  let () =
    Printf.eprintf "Starting Terrateam Server CLI (build %s)\n%!" Terrat_build_info.sha;
    Mirage_crypto_rng_unix.use_default ();
    let info = Cmdliner.Cmd.info "terrat" in
    exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group ~default:Cmdline.default_cmd info cmds
end

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
        "cohttp_abb";
        "cohttp_abb.io";
        "cohttp_abb.tls";
        "dns_cache";
        "dns_client";
        "happy-eyeballs";
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
      C.Cmd.Env.info ~doc "TTM_LOGGERS"
    in
    let doc = "Specify logging subsystems.  Comma separated." in
    C.Arg.(value & opt (some string) None & info [ "loggers" ] ~env ~doc)

  let logs = C.Term.(const setup_log $ Logs_cli.level () $ loggers)
  let default_cmd = C.Term.(ret (const (`Help (`Pager, None))))
end

let cmds = Cmdline.[ Ttm_kv.cmd logs; Ttm_secrets.cmd logs ]

let () =
  Mirage_crypto_rng_unix.use_default ();
  let info = Cmdliner.Cmd.info "ttm" in
  exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group ~default:Cmdline.default_cmd info cmds

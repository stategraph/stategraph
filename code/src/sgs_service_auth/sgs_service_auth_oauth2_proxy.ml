(* OAuth2 Proxy Process Management

   This module handles spawning and managing the oauth2-proxy process
   for OAuth authentication. oauth2-proxy runs as a subprocess and handles
   the OAuth2 flow with external providers (Google, OIDC, etc.).

   StateGraph acts as the HTTP storage backend for oauth2-proxy sessions
   and proxies /oauth2/* requests to the oauth2-proxy instance.
*)

let src = Logs.Src.create "oauth2_proxy"

module Logs = (val Logs.src_log src : Logs.LOG)

(* The port oauth2-proxy listens on *)
let oauth2_proxy_port = 4180

(* Where oauth2-proxy's own stdout/stderr goes. Its startup failures are only ever reported
   here, so error paths point operators at it. *)
let log_file = "/tmp/oauth2-proxy.log"

(* How long to wait for oauth2-proxy to start accepting connections before declaring the spawn a
   failure. It binds its port in well under a second; the slack is for a loaded host. *)
let readiness_attempts = 100
let readiness_interval = 0.1

(* Flags whose values are secrets. The full argv is logged at debug to make misconfiguration
   diagnosable, which must not mean printing credentials into the operator's logs. *)
let redacted_flags = [ "--client-id"; "--client-secret"; "--cookie-secret"; "--http-store-api-key" ]

let redact_arg arg =
  match CCString.Split.left ~by:"=" arg with
  | Some (flag, _) when CCList.mem ~eq:CCString.equal flag redacted_flags -> flag ^ "=<redacted>"
  | Some _ | None -> arg

(* Path to oauth2-proxy binary - can be overridden via environment *)
let oauth2_proxy_binary () =
  CCOption.get_or
    ~default:"/usr/local/bin/oauth2-proxy"
    (Sys.getenv_opt "STATEGRAPH_OAUTH2_PROXY_PATH")

type t = {
  process : Abb.Process.t;
  port : int;
  (* Set only when we wrote the file ourselves from inline JSON, so [stop] never removes a path the
     operator gave us. *)
  owned_service_account_path : string option;
}

type spawn_err =
  [ `Spawn_failed of string
  | `No_oauth_config
  | Abb_intf.Errors.spawn
  ]

let pp_spawn_err fmt = function
  | `Spawn_failed msg -> Format.fprintf fmt "Spawn failed: %s" msg
  | `No_oauth_config -> Format.fprintf fmt "No OAuth configuration present"
  | #Abb_intf.Errors.spawn as err -> Abb_intf.Errors.pp_spawn fmt err

let show_spawn_err err =
  let buf = Buffer.create 64 in
  let fmt = Format.formatter_of_buffer buf in
  pp_spawn_err fmt err;
  Format.pp_print_flush fmt ();
  Buffer.contents buf

(* oauth2-proxy's --google-service-account-json takes a path, but every surface we ship (docs,
   .env.example, the Helm chart) hands operators the JSON contents. Accept both: a value whose first
   non-whitespace character is '{' is contents and gets written to a private file, anything else is
   already a path. A filesystem path can't start with '{', so the two are unambiguous. *)
let written_service_account_path = "/tmp/oauth2-proxy-service-account.json"

(* Returns the path to hand to --google-service-account-json, and whether we created that file and
   so are responsible for removing it on stop. Never report ownership of an operator-supplied
   path. *)
let materialize_service_account_json json =
  if CCString.prefix ~pre:"{" (CCString.trim json) then
    try
      let fd =
        Unix.openfile
          written_service_account_path
          [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ]
          0o600
      in
      Fun.protect
        ~finally:(fun () -> Unix.close fd)
        (fun () ->
          let buf = Bytes.of_string json in
          let len = Bytes.length buf in
          let rec write pos = if pos < len then write (pos + Unix.write fd buf pos (len - pos)) in
          write 0);
      Logs.info (fun m ->
          m
            "Google service account JSON supplied inline, written to %s"
            written_service_account_path);
      Ok (written_service_account_path, `Owned)
    with Unix.Unix_error (err, func, arg) ->
      Error
        (`Spawn_failed
           (Printf.sprintf
              "Writing Google service account JSON to %s failed: %s(%s): %s"
              written_service_account_path
              func
              arg
              (Unix.error_message err)))
  else Ok (json, `Operator_supplied)

(* Build command line arguments for oauth2-proxy based on config *)
let build_args ~service_account_path config oauth2_config =
  let Sgs_config.
        {
          oauth2_client_id;
          oauth2_client_secret;
          oauth2_cookie_secret;
          oauth2_email_domain;
          oauth2_provider;
          oauth2_provider_name = _;
          oauth2_display_name = _;
          oauth2_config_hash = _;
        } =
    oauth2_config
  in
  let port = Sgs_config.port config in
  let api_key = Sgs_config.oauth2_api_key config in

  (* Get OAuth redirect base URL for the callback.
     In development this is the backend URL (e.g., http://localhost:8080).
     In production with nginx, this is the public URL. *)
  let oauth_redirect_base = Sgs_config.oauth_redirect_base config in
  let redirect_uri = Uri.of_string oauth_redirect_base in
  let redirect_host = Uri.host_with_default ~default:"localhost" redirect_uri in
  let redirect_port = Uri.port redirect_uri in
  let redirect_domain =
    match redirect_port with
    | Some p -> Printf.sprintf "%s:%d" redirect_host p
    | None -> redirect_host
  in

  (* Also get UI base for whitelisting (needed for redirects back to frontend) *)
  let ui_base = Sgs_config.ui_base config in
  let ui_uri = Uri.of_string ui_base in
  let ui_host = Uri.host_with_default ~default:"localhost" ui_uri in
  let ui_port = Uri.port ui_uri in
  let ui_domain =
    match ui_port with
    | Some p -> Printf.sprintf "%s:%d" ui_host p
    | None -> ui_host
  in

  (* Whitelist both domains if they're different *)
  let whitelist_domains =
    if redirect_domain = ui_domain then [ redirect_domain ] else [ redirect_domain; ui_domain ]
  in

  (* Determine if HTTPS based on redirect URL *)
  let is_https = Uri.scheme redirect_uri = Some "https" in

  (* Get provider name for namespacing *)
  let provider_name = oauth2_config.Sgs_config.oauth2_provider_name in

  (* Base URL for HTTP storage endpoints on StateGraph server - namespaced by provider *)
  let http_store_base_url =
    Printf.sprintf "http://127.0.0.1:%d/internal/oauth2-sessions/%s" port provider_name
  in

  (* Common arguments *)
  let common_args =
    [
      (* Session storage *)
      "--session-store-type=http";
      Printf.sprintf "--http-store-base-url=%s" http_store_base_url;
      Printf.sprintf "--http-store-api-key=%s" api_key;
      (* Listening address *)
      Printf.sprintf "--http-address=127.0.0.1:%d" oauth2_proxy_port;
      (* Upstream - all authenticated requests go to StateGraph *)
      Printf.sprintf "--upstream=http://127.0.0.1:%d" port;
      (* OAuth client credentials *)
      Printf.sprintf "--client-id=%s" oauth2_client_id;
      Printf.sprintf "--client-secret=%s" oauth2_client_secret;
      (* Cookie configuration *)
      Printf.sprintf "--cookie-secret=%s" oauth2_cookie_secret;
      Printf.sprintf "--cookie-secure=%b" is_https;
      "--cookie-samesite=lax";
      (* Email domain restriction *)
      Printf.sprintf "--email-domain=%s" oauth2_email_domain;
      (* Redirect URL for callback - use OAuth redirect base URL with provider *)
      Printf.sprintf "--redirect-url=%s/oauth2/%s/callback" oauth_redirect_base provider_name;
      (* Pass user info in headers *)
      "--set-xauthrequest=true";
      "--pass-user-headers=true";
      "--pass-access-token=true";
      (* Request profile scope to get avatar/picture URL *)
      "--scope=openid email profile";
    ]
  in

  (* Whitelist domains for redirects (both backend and UI if different) *)
  let whitelist_args =
    CCList.map (fun domain -> Printf.sprintf "--whitelist-domain=%s" domain) whitelist_domains
  in

  let common_args = common_args @ whitelist_args in

  (* Provider-specific arguments *)
  let provider_args =
    match oauth2_provider with
    | Sgs_config.Google { google_group; google_admin_email; google_service_account_json = _ } ->
        let base =
          [
            "--provider=google";
            (* Force account selection prompt so users can choose which Google account *)
            "--prompt=select_account";
          ]
        in
        let group_args =
          match google_group with
          | Some group -> [ Printf.sprintf "--google-group=%s" group ]
          | None -> []
        in
        let admin_args =
          match google_admin_email with
          | Some email -> [ Printf.sprintf "--google-admin-email=%s" email ]
          | None -> []
        in
        let sa_args =
          match service_account_path with
          | Some path -> [ Printf.sprintf "--google-service-account-json=%s" path ]
          | None -> []
        in
        base @ group_args @ admin_args @ sa_args
    | Sgs_config.Oidc { oidc_issuer_url; auth0_rp_logout = _ } ->
        [ "--provider=oidc"; Printf.sprintf "--oidc-issuer-url=%s" oidc_issuer_url ]
  in

  common_args @ provider_args

let is_listening port =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      try
        Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
        true
      with Unix.Unix_error _ -> false)

(* [Abb.Process.spawn] returns as soon as the fork succeeds, which says nothing about whether
   oauth2-proxy stayed up: a fatal config error exits it within milliseconds, and we would go on to
   register the /oauth2/* routes and proxy every login into a closed port, answering 502 forever
   with the reason buried in [log_file]. Wait for it to actually accept a connection, and surface
   the failure at startup instead. *)
let rec poll_until_listening ~attempts port =
  let open Abb.Future.Infix_monad in
  if is_listening port then Abb.Future.return `Listening
  else if attempts <= 1 then Abb.Future.return `Timed_out
  else
    Abb.Sys.sleep readiness_interval
    >>= fun () -> poll_until_listening ~attempts:(attempts - 1) port

(* Race "it started listening" against "it died". [Abb.Process.exit_code] is no use here: the
   underlying wait future is built with [Future.with_state] and so does not run until something
   awaits it, meaning a poll of it reports the process alive no matter what actually happened. *)
let wait_until_listening ~attempts process port =
  let open Abb.Future.Infix_monad in
  Abbs_fc.first
    (poll_until_listening ~attempts port)
    (Abb.Process.wait process >>| fun exit_code -> `Exited exit_code)
  >>= fun (outcome, _) ->
  match outcome with
  | `Listening -> Abbs_fc.return_ok ()
  | `Exited exit_code ->
      Abbs_fc.return_err
        (`Spawn_failed
           (Printf.sprintf
              "oauth2-proxy exited (%s) without listening on port %d - see %s for the reason"
              (Abb_intf.Process.Exit_code.show exit_code)
              port
              log_file))
  | `Timed_out ->
      (* Alive but never bound the port. Don't leave it orphaned. *)
      Abb.Process.signal process Abb_intf.Process.Signal.SIGKILL;
      Abbs_fc.return_err
        (`Spawn_failed
           (Printf.sprintf
              "oauth2-proxy did not listen on port %d within %.0f seconds - see %s"
              port
              (float_of_int readiness_attempts *. readiness_interval)
              log_file))

(* Spawn oauth2-proxy as a background process using Abb.Process *)
let spawn config =
  match Sgs_config.oauth2 config with
  | None ->
      Logs.info (fun m -> m "No OAuth2 configuration - skipping oauth2-proxy");
      Abbs_fc.return_err `No_oauth_config
  | Some oauth2_config -> (
      match
        match oauth2_config.Sgs_config.oauth2_provider with
        | Sgs_config.Google
            { google_group = _; google_admin_email = _; google_service_account_json = Some json } ->
            CCResult.map CCOption.return (materialize_service_account_json json)
        | Sgs_config.Google _ | Sgs_config.Oidc _ -> Ok None
      with
      | Error (`Spawn_failed _ as err) ->
          Logs.err (fun m -> m "%a" pp_spawn_err err);
          Abbs_fc.return_err err
      | Ok service_account -> (
          let service_account_path = CCOption.map fst service_account in
          let owned_service_account_path =
            match service_account with
            | Some (path, `Owned) -> Some path
            | Some (_, `Operator_supplied) | None -> None
          in
          let binary = oauth2_proxy_binary () in
          let args = build_args ~service_account_path config oauth2_config in
          let provider_name = oauth2_config.Sgs_config.oauth2_provider_name in
          let display_name = oauth2_config.Sgs_config.oauth2_display_name in
          let oauth_redirect_base = Sgs_config.oauth_redirect_base config in
          let callback_url =
            Printf.sprintf "%s/oauth2/%s/callback" oauth_redirect_base provider_name
          in

          Logs.info (fun m ->
              m "OAUTH2_CONFIG : provider=%s display_name=%s" provider_name display_name);
          Logs.info (fun m ->
              m "OAUTH2_CALLBACK_URL : %s (register this URL with your OAuth provider)" callback_url);
          if not (Sgs_config.oauth_redirect_base_explicit config) then
            Logs.warn (fun m ->
                m
                  "OAUTH2_REDIRECT_BASE_DEFAULT : STATEGRAPH_OAUTH_REDIRECT_BASE is not set, \
                   defaulting to '%s' which will not work in production"
                  oauth_redirect_base);

          Logs.info (fun m -> m "Starting oauth2-proxy on port %d" oauth2_proxy_port);
          Logs.debug (fun m -> m "oauth2-proxy binary: %s" binary);
          Logs.debug (fun m ->
              m "oauth2-proxy args: %s" (String.concat " " (CCList.map redact_arg args)));

          try
            let log_fd =
              Unix.openfile log_file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o644
            in
            let dev_null = Unix.openfile "/dev/null" [ Unix.O_RDONLY ] 0o644 in

            Logs.info (fun m -> m "oauth2-proxy output will be logged to %s" log_file);

            (* Build process spec using Abb_intf.Process *)
            let process_spec =
              Abb_intf.Process.{ exec_name = binary; args = binary :: args; env = None }
            in

            (* Spawn using Abb.Process *)
            match Abb.Process.spawn ~stdin:dev_null ~stdout:log_fd ~stderr:log_fd process_spec with
            | Ok process -> (
                Unix.close dev_null;
                Unix.close log_fd;
                let pid = Abb.Process.Pid.to_native (Abb.Process.pid process) in
                let open Abb.Future.Infix_monad in
                wait_until_listening ~attempts:readiness_attempts process oauth2_proxy_port
                >>= function
                | Ok () ->
                    Logs.info (fun m -> m "oauth2-proxy started with PID %d" pid);
                    Abbs_fc.return_ok
                      { process; port = oauth2_proxy_port; owned_service_account_path }
                | Error (`Spawn_failed _ as err) ->
                    (* Nobody will call [stop] for a failed spawn, so clean up after ourselves. *)
                    CCOption.iter
                      (fun path -> try Unix.unlink path with Unix.Unix_error _ -> ())
                      owned_service_account_path;
                    Logs.err (fun m -> m "%a" pp_spawn_err err);
                    Abbs_fc.return_err err)
            | Error err ->
                Unix.close dev_null;
                Unix.close log_fd;
                Logs.err (fun m ->
                    m "Failed to spawn oauth2-proxy: %a" Abb_intf.Errors.pp_spawn err);
                Abbs_fc.return_err (err :> spawn_err)
          with
          | Unix.Unix_error (err, func, arg) ->
              let msg = Printf.sprintf "%s(%s): %s" func arg (Unix.error_message err) in
              Logs.err (fun m -> m "Failed to open files for oauth2-proxy: %s" msg);
              Abbs_fc.return_err (`Spawn_failed msg)
          | exn ->
              let msg = Printexc.to_string exn in
              Logs.err (fun m -> m "Failed to spawn oauth2-proxy: %s" msg);
              Abbs_fc.return_err (`Spawn_failed msg)))

(* Check if oauth2-proxy is still running *)
let is_running t =
  match Abb.Process.exit_code t.process with
  | None -> true (* Still running if no exit code yet *)
  | Some _ -> false

(* Stop oauth2-proxy - sends SIGTERM, then SIGKILL if still running *)
let stop t =
  let pid = Abb.Process.Pid.to_native (Abb.Process.pid t.process) in
  Logs.info (fun m -> m "Stopping oauth2-proxy (PID %d)" pid);

  (* Send SIGTERM for graceful shutdown *)
  Abb.Process.signal t.process Abb_intf.Process.Signal.SIGTERM;

  (* Wait a bit for graceful shutdown *)
  let open Abb.Future.Infix_monad in
  Abb.Sys.sleep 0.5
  >>= fun () ->
  (* Check if still running, send SIGKILL if needed *)
  if is_running t then (
    Logs.warn (fun m -> m "oauth2-proxy didn't terminate, sending SIGKILL");
    Abb.Process.signal t.process Abb_intf.Process.Signal.SIGKILL);

  (* Wait for the process to fully exit *)
  Abb.Process.wait t.process
  >>= fun _exit_code ->
  CCOption.iter
    (fun path -> try Unix.unlink path with Unix.Unix_error (_, _, _) -> ())
    t.owned_service_account_path;
  Abb.Future.return ()

(* Get the port oauth2-proxy is listening on *)
let port t = t.port

module Tests = struct
  let redact_arg = redact_arg
  let materialize_service_account_json = materialize_service_account_json
end

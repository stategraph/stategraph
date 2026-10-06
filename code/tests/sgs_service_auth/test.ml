let sa_json =
  {|{"type":"service_account","project_id":"p","client_email":"sa@p.iam.gserviceaccount.com"}|}

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in ic)
    (fun () -> really_input_string ic (in_channel_length ic))

(* A stand-in for the oauth2-proxy binary that execs fine and then dies, the way a real one does on
   a fatal config error. *)
let write_exiting_binary () =
  let path = Filename.concat (Filename.get_temp_dir_name ()) "fake-oauth2-proxy.sh" in
  let oc = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out oc)
    (fun () -> output_string oc "#!/bin/sh\necho 'invalid configuration' >&2\nexit 1\n");
  Unix.chmod path 0o755;
  path

let oauth_env () =
  CCList.iter
    (fun (k, v) -> Unix.putenv k v)
    [
      ("STATEGRAPH_UI_BASE", "https://example.com");
      ("DB_HOST", "localhost");
      ("DB_USER", "sg");
      ("DB_PASS", "pw");
      ("DB_NAME", "sg");
      ("STATEGRAPH_OAUTH_TYPE", "google");
      ("STATEGRAPH_OAUTH_CLIENT_ID", "client-id");
      ("STATEGRAPH_OAUTH_CLIENT_SECRET", "client-secret");
      ("STATEGRAPH_OAUTH_COOKIE_SECRET", "0123456789abcdef");
      ("STATEGRAPH_OAUTH2_PROXY_PATH", write_exiting_binary ());
    ]

(* Serial: the inline-JSON cases all write the same file. *)
let test =
  Oth.serial
    [
      Oth.test ~name:"inline JSON is written to a file we own" (fun _ ->
          match Sgs_service_auth_oauth2_proxy.Tests.materialize_service_account_json sa_json with
          | Ok (path, `Owned) ->
              Oth.Assert.true_ (Sys.file_exists path);
              Oth.Assert.Eq.string ~expected:sa_json ~actual:(read_file path);
              Oth.Assert.Eq.int ~expected:0o600 ~actual:((Unix.stat path).Unix.st_perm land 0o777)
          | Ok (_, `Operator_supplied) -> Oth.Assert.false_ "inline JSON treated as a path"
          | Error (`Spawn_failed msg) -> Oth.Assert.false_ msg);
      Oth.test ~name:"leading whitespace before the brace is still inline JSON" (fun _ ->
          match
            Sgs_service_auth_oauth2_proxy.Tests.materialize_service_account_json ("\n  " ^ sa_json)
          with
          | Ok (path, `Owned) -> Oth.Assert.true_ (Sys.file_exists path)
          | Ok (_, `Operator_supplied) -> Oth.Assert.false_ "inline JSON treated as a path"
          | Error (`Spawn_failed msg) -> Oth.Assert.false_ msg);
      Oth.test ~name:"a path is passed through untouched and never owned" (fun _ ->
          let path = "/var/secrets/google/sa.json" in
          match Sgs_service_auth_oauth2_proxy.Tests.materialize_service_account_json path with
          | Ok (resolved, `Operator_supplied) ->
              Oth.Assert.Eq.string ~expected:path ~actual:resolved
          | Ok (_, `Owned) -> Oth.Assert.false_ "operator path reported as owned"
          | Error (`Spawn_failed msg) -> Oth.Assert.false_ msg);
      Oth.test ~name:"secret-bearing flags are redacted in the debug argv log" (fun _ ->
          CCList.iter
            (fun flag ->
              Oth.Assert.Eq.string
                ~expected:(flag ^ "=<redacted>")
                ~actual:(Sgs_service_auth_oauth2_proxy.Tests.redact_arg (flag ^ "=s3cret")))
            [ "--client-id"; "--client-secret"; "--cookie-secret"; "--http-store-api-key" ];
          (* Everything else has to survive verbatim or the log stops being useful. *)
          CCList.iter
            (fun arg ->
              Oth.Assert.Eq.string
                ~expected:arg
                ~actual:(Sgs_service_auth_oauth2_proxy.Tests.redact_arg arg))
            [
              "--provider=google";
              "--google-service-account-json=/var/secrets/google/sa.json";
              "--email-domain=example.com";
              "--set-xauthrequest=true";
            ]);
      (* The bug this guards: forking succeeded, so spawn used to return Ok and the server proxied
         every login into a closed port, answering 502 forever. *)
      Oth.test ~name:"spawn fails when oauth2-proxy dies instead of listening" (fun _ ->
          oauth_env ();
          let config = Oth.Assert.ok_pp ~pp:Sgs_config.pp_err (Sgs_config.create ()) in
          match
            Abb.Scheduler.run_with_state (fun () -> Sgs_service_auth_oauth2_proxy.spawn config)
          with
          | `Det (Error (`Spawn_failed msg)) ->
              Oth.Assert.str_contains ~haystack:msg ~needle:"without listening";
              Oth.Assert.str_contains ~haystack:msg ~needle:"/tmp/oauth2-proxy.log"
          | `Det (Ok _) -> Oth.Assert.false_ "spawn reported success for a dead oauth2-proxy"
          | `Det (Error err) -> Oth.Assert.false_ (Sgs_service_auth_oauth2_proxy.show_spawn_err err)
          | `Aborted -> Oth.Assert.false_ "scheduler aborted"
          | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn));
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

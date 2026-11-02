let sa_json =
  {|{"type":"service_account","project_id":"p","client_email":"sa@p.iam.gserviceaccount.com"}|}

let group_env service_account_json =
  [
    ("STATEGRAPH_OAUTH_GOOGLE_GROUP", "eng@example.com");
    ("STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL", "admin@example.com");
    ("STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON", service_account_json);
  ]

let oauth_env env =
  CCList.iter
    (fun (k, v) -> Unix.putenv k v)
    ([
       ("STATEGRAPH_UI_BASE", "https://example.com");
       ("STATEGRAPH_OAUTH_REDIRECT_BASE", "https://example.com");
       ("DB_HOST", "localhost");
       ("DB_USER", "sg");
       ("DB_PASS", "pw");
       ("DB_NAME", "sg");
       ("STATEGRAPH_OAUTH_TYPE", "google");
       ("STATEGRAPH_OAUTH_CLIENT_ID", "client-id");
       ("STATEGRAPH_OAUTH_CLIENT_SECRET", "client-secret");
       ("STATEGRAPH_OAUTH_COOKIE_SECRET", "0123456789abcdef");
       ("STATEGRAPH_OAUTH_EMAIL_DOMAIN", "*");
       ("STATEGRAPH_OAUTH_GOOGLE_GROUP", "");
       ("STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL", "");
       ("STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON", "");
     ]
    @ env)

(* Runs [f] on the sign-in flow created from [env]. *)
let with_oauth2 env f =
  oauth_env env;
  let config = Oth.Assert.ok_pp ~pp:Sgs_config.pp_err (Sgs_config.create ()) in
  Abb.Scheduler.run_with_state (fun () ->
      let open Abb.Future.Infix_monad in
      Sgs_service_oauth2.Provider.create config
      >>= function
      | Ok oauth2 -> f oauth2 >>| fun r -> Ok r
      | Error _ as err -> Abb.Future.return err)

let start_request path =
  Oauth2_htp_request.of_ctx
    (Brtl_ctx.set_body
       ""
       (Brtl_ctx.create
          "127.0.0.1"
          (Cohttp.Request.make
             ~headers:(Cohttp.Header.of_list [ ("Host", "example.com") ])
             (Uri.of_string path))))

let assert_invalid_config ~needle = function
  | `Det (Error (`Invalid_config msg)) -> Oth.Assert.str_contains ~haystack:msg ~needle
  | `Det (Ok _) -> Oth.Assert.false_ "the configuration was accepted"
  | `Det (Error err) -> Oth.Assert.false_ (Sgs_service_oauth2.Provider.show_create_err err)
  | `Aborted -> Oth.Assert.false_ "scheduler aborted"
  | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn)

(* The configuration was accepted and the service account reached the Admin SDK check. *)
let assert_admin_checked = function
  | `Det (Error (`Provider_err msg)) -> Oth.Assert.str_contains ~haystack:msg ~needle:"credentials"
  | `Det (Ok _) -> Oth.Assert.false_ "a service account without a private key was accepted"
  | `Det (Error err) -> Oth.Assert.false_ (Sgs_service_oauth2.Provider.show_create_err err)
  | `Aborted -> Oth.Assert.false_ "scheduler aborted"
  | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn)

module Config_service = Sgs_service_config.Make (Sgs_cloud_oss)

(* Starts the service from [env] in a manager that runs the config service. *)
let start_service env =
  oauth_env env;
  Abb.Scheduler.run_with_state (fun () ->
      let open Abb.Future.Infix_monad in
      Sgs_svc_mngr.start ()
      >>= function
      | Error `Start_err -> Abb.Future.return (Error (`Start_err "the manager did not start"))
      | Ok mgr ->
          Sgs_svc_mngr.register' mgr [ (module Config_service) ]
          >>= fun _ ->
          Sgs_svc_mngr.started mgr
          >>= fun _ ->
          Sgs_service_oauth2.start mgr >>= fun res -> Sgs_svc_mngr.stop mgr >>| fun () -> res)

let assert_start_err ~expected = function
  | `Det (Error (#Sgs_service.start_err as err)) when expected err -> ()
  | `Det (Error err) -> Oth.Assert.false_ (Sgs_service.show_start_err err)
  | `Det (Ok _) -> Oth.Assert.false_ "the service started"
  | `Aborted -> Oth.Assert.false_ "scheduler aborted"
  | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn)

(* Serial: every case sets the process environment. *)
let test =
  Oth.serial
    [
      Oth.test ~name:"a Google group takes its service account key inline" (fun _ ->
          (* The key is read, then refused by the Admin SDK check for its missing private key. *)
          assert_admin_checked (with_oauth2 (group_env sa_json) (fun _ -> Abb.Future.return ())));
      Oth.test ~name:"a Google group reads its service account key from a path" (fun _ ->
          let path = Filename.temp_file "sa" ".json" in
          CCIO.File.write_exn path sa_json;
          let r = with_oauth2 (group_env path) (fun _ -> Abb.Future.return ()) in
          Sys.remove path;
          assert_admin_checked r);
      Oth.test
        ~name:"an admin email and service account without a group look up every group"
        (fun _ ->
          assert_admin_checked
            (with_oauth2 (("STATEGRAPH_OAUTH_GOOGLE_GROUP", "") :: group_env sa_json) (fun _ ->
                 Abb.Future.return ())));
      Oth.test ~name:"a missing service account key file fails the create" (fun _ ->
          let path = "/nonexistent/sa.json" in
          match with_oauth2 (group_env path) (fun _ -> Abb.Future.return ()) with
          | `Det (Error (`Invalid_config msg)) -> Oth.Assert.str_contains ~haystack:msg ~needle:path
          | `Det (Ok ()) -> Oth.Assert.false_ "a missing key file was accepted"
          | `Det (Error err) -> Oth.Assert.false_ (Sgs_service_oauth2.Provider.show_create_err err)
          | `Aborted -> Oth.Assert.false_ "scheduler aborted"
          | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn));
      Oth.test ~name:"Google sign-in starts at Google with the configured callback" (fun _ ->
          match
            with_oauth2 [] (fun oauth2 ->
                Oauth2_htp.oauth_start
                  ~now:1700000000.
                  (Sgs_service_oauth2.Provider.authenticator oauth2)
                  (start_request "/oauth2/google/start?rd=%2Fstates"))
          with
          | `Det (Ok (Ok { Oauth2_htp.Start_result.login_url; set_cookies })) ->
              let uri = Uri.of_string login_url in
              Oth.Assert.Eq.string
                ~expected:"accounts.google.com"
                ~actual:(CCOption.get_or ~default:"" (Uri.host uri));
              CCList.iter
                (fun (k, v) ->
                  Oth.Assert.Eq.string
                    ~expected:v
                    ~actual:(CCOption.get_or ~default:"" (Uri.get_query_param uri k)))
                [
                  ("client_id", "client-id");
                  ("redirect_uri", "https://example.com/oauth2/google/callback");
                  ("scope", "openid email profile");
                  ("prompt", "select_account");
                ];
              Oth.Assert.true_
                (CCList.exists
                   (fun c -> CCString.equal c.Oauth2_htp_cookie.name Oauth2_htp_csrf.cookie_name)
                   set_cookies)
          | `Det (Ok (Error err)) -> Oth.Assert.false_ (Oauth2_htp.show_err err)
          | `Det (Error err) -> Oth.Assert.false_ (Sgs_service_oauth2.Provider.show_create_err err)
          | `Aborted -> Oth.Assert.false_ "scheduler aborted"
          | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn));
      Oth.test ~name:"a Google group needs its admin email and service account" (fun _ ->
          assert_invalid_config
            ~needle:"needs both"
            (with_oauth2
               [ ("STATEGRAPH_OAUTH_GOOGLE_GROUP", "eng@example.com") ]
               (fun _ -> Abb.Future.return ())));
      Oth.test ~name:"an admin email needs a service account" (fun _ ->
          assert_invalid_config
            ~needle:"must be set together"
            (with_oauth2
               [ ("STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL", "admin@example.com") ]
               (fun _ -> Abb.Future.return ())));
      Oth.test ~name:"an email domain list is accepted" (fun _ ->
          match
            with_oauth2
              [ ("STATEGRAPH_OAUTH_EMAIL_DOMAIN", "example.com, example.org") ]
              (fun _ -> Abb.Future.return ())
          with
          | `Det (Ok ()) -> ()
          | `Det (Error err) -> Oth.Assert.false_ (Sgs_service_oauth2.Provider.show_create_err err)
          | `Aborted -> Oth.Assert.false_ "scheduler aborted"
          | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn));
      Oth.test ~name:"an empty email domain fails the create" (fun _ ->
          assert_invalid_config
            ~needle:"STATEGRAPH_OAUTH_EMAIL_DOMAIN"
            (with_oauth2
               [ ("STATEGRAPH_OAUTH_EMAIL_DOMAIN", " , ") ]
               (fun _ -> Abb.Future.return ())));
      Oth.test ~name:"the service starts with no provider without an OAuth configuration" (fun _ ->
          match start_service [ ("STATEGRAPH_OAUTH_TYPE", "") ] with
          | `Det (Ok service) ->
              Oth.Assert.true_ (CCOption.is_none (Sgs_service_oauth2.provider service))
          | `Det (Error err) -> Oth.Assert.false_ (Sgs_service.show_start_err err)
          | `Aborted -> Oth.Assert.false_ "scheduler aborted"
          | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn));
      Oth.test ~name:"the service starts with the configured provider" (fun _ ->
          match start_service [] with
          | `Det (Ok service) ->
              Oth.Assert.true_ (CCOption.is_some (Sgs_service_oauth2.provider service))
          | `Det (Error err) -> Oth.Assert.false_ (Sgs_service.show_start_err err)
          | `Aborted -> Oth.Assert.false_ "scheduler aborted"
          | `Exn (exn, _) -> Oth.Assert.false_ (Printexc.to_string exn));
      Oth.test ~name:"an invalid OAuth configuration refuses the start for good" (fun _ ->
          assert_start_err
            ~expected:(function
              | `Start_fatal_err _ -> true
              | `Start_err _ | `Start_missing_deps_err _ -> false)
            (start_service [ ("STATEGRAPH_OAUTH_GOOGLE_GROUP", "eng@example.com") ]));
      Oth.test ~name:"an unreachable OIDC issuer refuses the start for a retry" (fun _ ->
          assert_start_err
            ~expected:(function
              | `Start_err _ -> true
              | `Start_fatal_err _ | `Start_missing_deps_err _ -> false)
            (start_service
               [
                 ("STATEGRAPH_OAUTH_TYPE", "oidc");
                 ("STATEGRAPH_OAUTH_OIDC_ISSUER_URL", "http://127.0.0.1:1");
               ]));
    ]

let () =
  Mirage_crypto_rng_unix.use_default ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

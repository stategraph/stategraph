(* The whole config is printed to stdout at startup (see Sgs_cli.server), so any secret reachable
   from it lands in the logs of every deployment. *)

let private_key = "-----BEGIN PRIVATE KEY-----MIIEvQIBADANBgkqh-----END PRIVATE KEY-----"

let service_account_json =
  Printf.sprintf
    {|{"type":"service_account","project_id":"p","private_key":"%s","client_email":"sa@p.iam.gserviceaccount.com"}|}
    private_key

let set_env () =
  CCList.iter
    (fun (k, v) -> Unix.putenv k v)
    [
      ("STATEGRAPH_UI_BASE", "https://example.com");
      ("DB_HOST", "localhost");
      ("DB_PORT", "5432");
      ("DB_USER", "sg");
      ("DB_PASS", "hunter2-should-not-print");
      ("DB_NAME", "sg");
      ("STATEGRAPH_OAUTH_TYPE", "google");
      ("STATEGRAPH_OAUTH_CLIENT_ID", "client-id");
      ("STATEGRAPH_OAUTH_CLIENT_SECRET", "client-secret-should-not-print");
      ("STATEGRAPH_OAUTH_COOKIE_SECRET", "0123456789abcdef");
      ("STATEGRAPH_OAUTH_GOOGLE_GROUP", "eng@example.com");
      ("STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON", service_account_json);
      ("STATEGRAPH_ORCHESTRATION_ENABLED", "");
      ("STATEGRAPH_FDW_PASSWORD", "");
    ]

(* [Unix.putenv] cannot unset a variable; [Sgs_config] reads an empty value as unset. *)
let orchestration_case ~name ~flag ~password expected =
  Oth.test ~name (fun _ ->
      set_env ();
      Unix.putenv "STATEGRAPH_ORCHESTRATION_ENABLED" flag;
      Unix.putenv "STATEGRAPH_FDW_PASSWORD" password;
      let config = Oth.Assert.ok_pp ~pp:Sgs_config.pp_err (Sgs_config.create ()) in
      Oth.Assert.Eq.bool ~expected ~actual:(Sgs_config.orchestration_enabled config))

let test =
  Oth.serial
    [
      orchestration_case
        ~name:"orchestration is off with no flag and no FDW password"
        ~flag:""
        ~password:""
        false;
      orchestration_case
        ~name:"orchestration is on with no flag and an FDW password"
        ~flag:""
        ~password:"stategraph_mql"
        true;
      orchestration_case
        ~name:"orchestration is off when the flag is false"
        ~flag:"false"
        ~password:"stategraph_mql"
        false;
      orchestration_case
        ~name:"orchestration is on when the flag is true"
        ~flag:"true"
        ~password:"stategraph_mql"
        true;
      Oth.test ~name:"an explicit true with no FDW password is a config error" (fun _ ->
          set_env ();
          Unix.putenv "STATEGRAPH_ORCHESTRATION_ENABLED" "true";
          Unix.putenv "STATEGRAPH_FDW_PASSWORD" "";
          match Sgs_config.create () with
          | Error (`Key_error "STATEGRAPH_FDW_PASSWORD") -> ()
          | Ok _ -> Oth.Assert.false_ "config loaded without the FDW password"
          | Error err -> Oth.Assert.false_ (Sgs_config.show_err err));
      Oth.test ~name:"a DB_PORT that is not an integer is a config error" (fun _ ->
          set_env ();
          Unix.putenv "DB_PORT" "not-a-port";
          match Sgs_config.create () with
          | Error (`Key_error "DB_PORT") -> ()
          | Ok _ -> Oth.Assert.false_ "config loaded with an invalid DB_PORT"
          | Error err -> Oth.Assert.false_ (Sgs_config.show_err err));
      Oth.test ~name:"GitHub sign-in reads its comma-separated organizations" (fun _ ->
          set_env ();
          Unix.putenv "STATEGRAPH_OAUTH_TYPE" "github";
          Unix.putenv "STATEGRAPH_OAUTH_GITHUB_ORG" " acme, ,acme-labs ";
          let config = Oth.Assert.ok_pp ~pp:Sgs_config.pp_err (Sgs_config.create ()) in
          match CCOption.map (fun c -> c.Sgs_config.oauth2_provider) (Sgs_config.oauth2 config) with
          | Some (Sgs_config.Github { github_orgs }) ->
              Oth.Assert.Eq.string_list
                ~expected:[ "acme"; "acme-labs" ]
                ~actual:(Sln_list.Non_empty.to_list github_orgs)
          | Some (Sgs_config.Google _ | Sgs_config.Oidc _) | None ->
              Oth.Assert.false_ "not a GitHub sign-in");
      Oth.test ~name:"GitHub sign-in without an organization is a config error" (fun _ ->
          CCList.iter
            (fun orgs ->
              set_env ();
              Unix.putenv "STATEGRAPH_OAUTH_TYPE" "github";
              Unix.putenv "STATEGRAPH_OAUTH_GITHUB_ORG" orgs;
              match Sgs_config.create () with
              | Error (`Key_error key) ->
                  Oth.Assert.str_contains ~haystack:key ~needle:"STATEGRAPH_OAUTH_GITHUB_ORG"
              | Ok _ -> Oth.Assert.false_ (Printf.sprintf "config loaded with orgs %S" orgs))
            [ ""; " , " ]);
      Oth.test ~name:"startup config print masks the Google service account key" (fun _ ->
          set_env ();
          let config = Oth.Assert.ok_pp ~pp:Sgs_config.pp_err (Sgs_config.create ()) in
          let shown = Sgs_config.show config in
          Oth.Assert.str_doesnt_contain ~haystack:shown ~needle:private_key;
          Oth.Assert.str_doesnt_contain ~haystack:shown ~needle:"client_email";
          (* Still shows whether one is configured, just not its contents. *)
          Oth.Assert.str_contains
            ~haystack:shown
            ~needle:"google_service_account_json = (Some <opaque>)");
      Oth.test ~name:"startup config print masks the other secrets too" (fun _ ->
          set_env ();
          let config = Oth.Assert.ok_pp ~pp:Sgs_config.pp_err (Sgs_config.create ()) in
          let shown = Sgs_config.show config in
          Oth.Assert.str_doesnt_contain ~haystack:shown ~needle:"hunter2-should-not-print";
          Oth.Assert.str_doesnt_contain ~haystack:shown ~needle:"client-secret-should-not-print");
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

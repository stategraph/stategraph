(* The Stategraph environment of a unified deployment: DB_* names the Stategraph database. *)
let base_env =
  [
    ("DB_HOST", "sg-host");
    ("DB_NAME", "stategraph");
    ("DB_PASS", "sg-pass");
    ("DB_PORT", "5433");
    ("DB_USER", "sg-user");
    ("STATEGRAPH_UI_BASE", "https://console.example.com/");
  ]

let config env =
  Oth.Assert.ok_show
    ~show:Terrat_config.show_err
    (Sgs_terrat_config.of_env (fun key -> CCList.assoc_opt ~eq:CCString.equal key env))

let test_db_name =
  Oth.test ~name:"the database is TERRAT_DB_NAME, else terrateam, never DB_NAME" (fun _ ->
      Oth.Assert.Eq.string ~expected:"terrateam" ~actual:(Terrat_config.db (config base_env));
      Oth.Assert.Eq.string
        ~expected:"orchestration"
        ~actual:(Terrat_config.db (config (("TERRAT_DB_NAME", "orchestration") :: base_env)));
      Oth.Assert.Eq.string
        ~expected:"terrateam"
        ~actual:(Terrat_config.db (config (("TERRAT_DB_NAME", "") :: base_env)));
      ())

let test_db_connection =
  Oth.test ~name:"TERRAT_DB_* wins over DB_*, one variable at a time" (fun _ ->
      let config =
        config (("TERRAT_DB_HOST", "tt-host") :: ("TERRAT_DB_PASS", "tt-pass") :: base_env)
      in
      Oth.Assert.Eq.string ~expected:"tt-host" ~actual:(Terrat_config.db_host config);
      Oth.Assert.Eq.string ~expected:"tt-pass" ~actual:(Terrat_config.db_password config);
      Oth.Assert.Eq.string ~expected:"sg-user" ~actual:(Terrat_config.db_user config);
      Oth.Assert.Eq.int ~expected:5433 ~actual:(Terrat_config.db_port config);
      ())

let test_bases_from_ui_base =
  Oth.test ~name:"the API and UI bases derive from STATEGRAPH_UI_BASE" (fun _ ->
      let config = config base_env in
      Oth.Assert.Eq.string
        ~expected:"https://console.example.com/api"
        ~actual:(Terrat_config.api_base config);
      Oth.Assert.Eq.string
        ~expected:"https://console.example.com"
        ~actual:(Uri.to_string (Terrat_config.web_base_url config Terrat_brand.Terrateam));
      ())

let test_explicit_bases =
  Oth.test ~name:"a set base is kept, an empty base is derived" (fun _ ->
      let config =
        config
          (("TERRAT_API_BASE", "https://api.example.com/api") :: ("TERRAT_UI_BASE", "") :: base_env)
      in
      Oth.Assert.Eq.string
        ~expected:"https://api.example.com/api"
        ~actual:(Terrat_config.api_base config);
      Oth.Assert.Eq.string
        ~expected:"https://console.example.com"
        ~actual:(Uri.to_string (Terrat_config.web_base_url config Terrat_brand.Terrateam));
      ())

let test_no_ui_base =
  Oth.test ~name:"without STATEGRAPH_UI_BASE the UI base is a key error" (fun _ ->
      let env =
        CCList.filter (fun (key, _) -> not (CCString.equal key "STATEGRAPH_UI_BASE")) base_env
      in
      match Sgs_terrat_config.of_env (fun key -> CCList.assoc_opt ~eq:CCString.equal key env) with
      | Ok _ -> Oth.Assert.false_ "the configuration loaded without a UI base"
      | Error (`Key_error key) -> Oth.Assert.Eq.string ~expected:"TERRAT_UI_BASE" ~actual:key
      | Error err -> Oth.Assert.false_ (Terrat_config.show_err err))

let test_python_exec =
  Oth.test ~name:"the Python executable defaults to the image's" (fun _ ->
      Oth.Assert.Eq.string
        ~expected:"/usr/bin/python3"
        ~actual:(Terrat_config.python_exec (config base_env));
      Oth.Assert.Eq.string
        ~expected:"python3"
        ~actual:(Terrat_config.python_exec (config (("TERRAT_PYTHON_EXEC", "python3") :: base_env)));
      ())

let () = Mirage_crypto_rng_unix.use_default ()
let pem = X509.Private_key.encode_pem (`RSA (Mirage_crypto_pk.Rsa.generate ~bits:2048 ()))

(* An env file holds a PEM on one line, with its newlines written as "\n". *)
let test_escaped_pem =
  Oth.test ~name:"a GitHub App PEM with escaped newlines decodes" (fun _ ->
      let escaped = CCString.replace ~which:`All ~sub:"\n" ~by:"\\n" pem in
      let config =
        config
          (("GITHUB_APP_ID", "42")
          :: ("GITHUB_APP_PEM", escaped)
          :: ("GITHUB_APP_CLIENT_ID", "Iv1.env")
          :: ("GITHUB_APP_CLIENT_SECRET", "env-secret")
          :: base_env)
      in
      let github = Oth.Assert.some (Terrat_config.github config) in
      Oth.Assert.Eq.string ~expected:"42" ~actual:(Terrat_config.Github.app_id github);
      ())

let test =
  Oth.parallel
    [
      test_db_name;
      test_db_connection;
      test_bases_from_ui_base;
      test_explicit_bases;
      test_no_ui_base;
      test_python_exec;
      test_escaped_pem;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

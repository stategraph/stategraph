(* [Unix.putenv] cannot remove a variable, and the config reads an empty value as unset, so "" is
   how a case says a variable is not set. *)
let unset = ""

let base_env =
  [
    ("DB_HOST", "localhost");
    ("DB_NAME", "terrateam");
    ("DB_PASS", "terrateam");
    ("DB_USER", "terrateam");
    ("TERRAT_API_BASE", "https://app.example.com/api");
    ("TERRAT_PYTHON_EXEC", "/usr/bin/python3");
  ]

let config ~stategraph_ui_base ~terrat_ui_base ~terrat_web_base_url =
  CCList.iter
    (fun (k, v) -> Unix.putenv k v)
    (base_env
    @ [
        ("STATEGRAPH_UI_BASE", stategraph_ui_base);
        ("TERRAT_UI_BASE", terrat_ui_base);
        ("TERRAT_WEB_BASE_URL", terrat_web_base_url);
      ]);
  Oth.Assert.ok_show ~show:Terrat_config.show_err (Terrat_config.create ())

let assert_base ~expected config brand =
  Oth.Assert.Eq.string ~expected ~actual:(Uri.to_string (Terrat_config.web_base_url config brand))

let test_brand_picks_its_own_base =
  Oth.test ~tags:[ "brand" ] ~name:"each brand links to its own console" (fun _ ->
      let config =
        config
          ~stategraph_ui_base:"https://app.stategraph.cloud"
          ~terrat_ui_base:"https://app.terrateam.io"
          ~terrat_web_base_url:"https://legacy.example.com"
      in
      assert_base ~expected:"https://app.stategraph.cloud" config Terrat_brand.Stategraph;
      assert_base ~expected:"https://app.terrateam.io" config Terrat_brand.Terrateam;
      ())

let test_falls_back_to_web_base_url =
  Oth.test ~tags:[ "brand" ] ~name:"a brand with no console of its own keeps the web base" (fun _ ->
      let config =
        config
          ~stategraph_ui_base:unset
          ~terrat_ui_base:"https://app.terrateam.io"
          ~terrat_web_base_url:"https://legacy.example.com"
      in
      assert_base ~expected:"https://legacy.example.com" config Terrat_brand.Stategraph;
      assert_base ~expected:"https://app.terrateam.io" config Terrat_brand.Terrateam;
      ())

let test_default_web_base_url =
  Oth.test ~tags:[ "brand" ] ~name:"the web base defaults to the Terrateam console" (fun _ ->
      let config =
        config
          ~stategraph_ui_base:unset
          ~terrat_ui_base:"https://app.terrateam.io"
          ~terrat_web_base_url:unset
      in
      assert_base ~expected:"https://app.terrateam.io" config Terrat_brand.Stategraph;
      ())

(* TERRAT_UI_BASE ends in a slash in Terrateam production, and a base is joined
   with a path. *)
let test_trailing_slash =
  Oth.test ~tags:[ "brand" ] ~name:"a base carries no trailing slash" (fun _ ->
      let config =
        config
          ~stategraph_ui_base:"https://app.stategraph.cloud//"
          ~terrat_ui_base:"https://app.terrateam.io/"
          ~terrat_web_base_url:"https://legacy.example.com/"
      in
      assert_base ~expected:"https://app.stategraph.cloud" config Terrat_brand.Stategraph;
      assert_base ~expected:"https://app.terrateam.io" config Terrat_brand.Terrateam;
      Oth.Assert.Eq.string
        ~expected:"https://app.terrateam.io/i/7/runs/ab-cd"
        ~actual:
          (Terrat_config.rebrand_url
             config
             Terrat_brand.Terrateam
             "https://legacy.example.com/i/7/runs/ab-cd");
      ())

let test_rebrand_url =
  Oth.test ~tags:[ "brand" ] ~name:"rebrand_url moves a link to the brand's console" (fun _ ->
      let config =
        config
          ~stategraph_ui_base:"https://app.stategraph.cloud"
          ~terrat_ui_base:"https://app.terrateam.io"
          ~terrat_web_base_url:"https://legacy.example.com"
      in
      Oth.Assert.Eq.string
        ~expected:"https://app.stategraph.cloud/i/7/runs/ab-cd"
        ~actual:
          (Terrat_config.rebrand_url
             config
             Terrat_brand.Stategraph
             "https://legacy.example.com/i/7/runs/ab-cd");
      (* A link read back from the forge already opens on a brand's console. It
         is published again unchanged, so it keeps one base. *)
      Oth.Assert.Eq.string
        ~expected:"https://app.terrateam.io/i/7/runs/ab-cd"
        ~actual:
          (Terrat_config.rebrand_url
             config
             Terrat_brand.Terrateam
             "https://app.terrateam.io/i/7/runs/ab-cd");
      (* GitLab publishes no link at all. *)
      Oth.Assert.Eq.string
        ~expected:""
        ~actual:(Terrat_config.rebrand_url config Terrat_brand.Terrateam "");
      ())

let () = Mirage_crypto_rng_unix.use_default ()
let pem = X509.Private_key.encode_pem (`RSA (Mirage_crypto_pk.Rsa.generate ~bits:2048 ()))

let stored ?(pem = pem) () =
  Terrat_config.github_of_stored
    ~app_id:"42"
    ~pem
    ~client_id:"Iv1.stored"
    ~client_secret:"stored-secret"
    ~webhook_secret:"stored-webhook"
    ~app_url:"https://github.com/apps/stored"

let test_github_of_stored =
  Oth.test ~tags:[ "github_app" ] ~name:"a stored App row decodes into the GitHub config" (fun _ ->
      let github = Oth.Assert.ok_show ~show:Terrat_config.show_err (stored ()) in
      Oth.Assert.Eq.string ~expected:"42" ~actual:(Terrat_config.Github.app_id github);
      Oth.Assert.Eq.string
        ~expected:"Iv1.stored"
        ~actual:(Terrat_config.Github.app_client_id github);
      Oth.Assert.Eq.string_option
        ~expected:(Some "stored-webhook")
        ~actual:(Terrat_config.Github.webhook_secret github);
      Oth.Assert.Eq.string
        ~expected:"https://github.com/apps/stored"
        ~actual:(Uri.to_string (Terrat_config.Github.app_url github));
      ())

let test_github_of_stored_bad_pem =
  Oth.test
    ~tags:[ "github_app" ]
    ~name:"a stored App row with a bad PEM is a config error"
    (fun _ ->
      match stored ~pem:"not a pem" () with
      | Error (`Bad_pem _) -> ()
      | Ok _ -> Oth.Assert.false_ "a bad PEM decoded"
      | Error err -> Oth.Assert.false_ (Terrat_config.show_err err))

let test_with_github =
  Oth.test ~tags:[ "github_app" ] ~name:"with_github puts the stored App in the config" (fun _ ->
      let config =
        config
          ~stategraph_ui_base:"https://console.example.com"
          ~terrat_ui_base:unset
          ~terrat_web_base_url:unset
      in
      Oth.Assert.none (Terrat_config.github config);
      let github = Oth.Assert.ok_show ~show:Terrat_config.show_err (stored ()) in
      let config = Terrat_config.with_github config github in
      let github = Oth.Assert.some (Terrat_config.github config) in
      Oth.Assert.Eq.string ~expected:"42" ~actual:(Terrat_config.Github.app_id github);
      ())

let test =
  Oth.serial
    [
      test_brand_picks_its_own_base;
      test_falls_back_to_web_base_url;
      test_default_web_base_url;
      test_trailing_slash;
      test_rebrand_url;
      test_github_of_stored;
      test_github_of_stored_bad_pem;
      test_with_github;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

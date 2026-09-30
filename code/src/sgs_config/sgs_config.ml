let cors_default_origin = "http://localhost:3000"

(* OAuth2 Provider Types *)
type oauth2_provider =
  | Google of {
      google_group : string option;
      google_admin_email : string option;
      google_service_account_json : (string[@opaque]) option;
    }
  | Oidc of {
      oidc_issuer_url : string;
      (* Force Auth0 RP-initiated logout (`<issuer>/v2/logout`) even when
         the issuer URL doesn't look like a `*.auth0.com` domain. Set this
         on Auth0 tenants that use a custom domain — without it, logout
         falls back to a local redirect and the IdP session stays alive. *)
      auth0_rp_logout : bool;
    }
[@@deriving show]

(* OAuth2 Configuration - optional, only present if OAuth is configured *)
type oauth2_config = {
  oauth2_display_name : string;
  oauth2_client_id : (string[@opaque]);
  oauth2_client_secret : (string[@opaque]);
  oauth2_email_domain : string;
  oauth2_provider : oauth2_provider;
  oauth2_provider_name : string; (* Machine-readable provider identifier, e.g., "google", "oidc" *)
  oauth2_config_hash : string;
  oauth2_cookie_secret : (string[@opaque]);
}
[@@deriving show]

(* The orchestration GitHub App's OAuth client.  Used only to establish which GitHub user is
   driving a claim (#1795); the App's private key stays with the engine, so nothing here can act as
   the App itself. *)
type github_oauth = {
  client_id : string;
  client_secret : (string[@opaque]);
  api_base : string;
  web_base : string;
}
[@@deriving show]

type t = {
  db : string;
  db_connect_timeout : float;
  db_host : string;
  db_idle_tx_timeout : string;
  dwf_idle_tx_timeout : string;
  db_max_pool_size : int;
  db_password : (string[@opaque]);
  db_port : int option;
  db_user : string;
  enable_cors : bool;
  port : int;
  statement_timeout : string;
  cors_default_origin : string;
  oauth2_api_key : (string[@opaque]);
  oauth2 : oauth2_config option;
  default_tenant_name : string option;
  cost_enabled : bool;
  dedicated_enabled : bool;
  (* STATEGRAPH_ORCHESTRATION_ENABLED: master on/off switch for the orchestration engine
     integration (FDW bridge to the terrateam database; the terrat runit service and nginx routes
     read the same variable). *)
  orchestration_enabled : bool;
  (* Whether STATEGRAPH_ORCHESTRATION_ENABLED said so, rather than the FDW password implying it.
     An operator who asked for orchestration gets a hard failure when its bridge cannot be built;
     one who got it by default gets a degraded subsystem, not a server that will not start. *)
  orchestration_explicit : bool;
  terrat_session_cookie_name : string;
  (* STATEGRAPH_FDW_*: how the stategraph database reaches the terrateam database over
     postgres_fdw. Only meaningful when orchestration is enabled. *)
  fdw_host : string;
  fdw_port : int;
  fdw_dbname : string;
  fdw_user : string;
  fdw_password : (string[@opaque]) option;
  fdw_provisioner_user : string;
  fdw_provisioner_password : (string[@opaque]) option;
  (* GITHUB_APP_URL: this deployment's own GitHub App install URL, surfaced to
     the console so the getting-started GitHub card can link to the app install.
     Optional, and with no default on purpose -- see the .mli. *)
  github_app_url : string option;
  (* TERRAT_API_BASE: the public base of the engine's API, STATEGRAPH_UI_BASE plus /api unless
     set. The webhook and callback URLs of a GitHub App the console creates are under it. *)
  terrat_api_base : string;
  pricing_service_url : string;
  pricing_default_region : string;
  cost_schedule_hours : int;
  cost_event_debounce_hours : int;
  cost_pricing_call_timeout_seconds : int;
  security_schedule_hours : int;
  security_event_debounce_hours : int;
  (* Total number of durable workflows (preview, commit, ...) allowed to run concurrently across all
     types, sharing one bounded executor. *)
  dwf_concurrency : int;
  preview_exec_timeout_minutes : int;
  preview_idle_timeout_minutes : int;
  commit_exec_timeout_minutes : int;
  commit_idle_timeout_minutes : int;
  task_result_fragment_size : int;
  (* STATEGRAPH_AEGIS_API_BASE: base URL of the Aegis control plane. *)
  aegis_api_base : string option;
  (* STATEGRAPH_AEGIS_SERVICE_TOKEN: shared bearer for service-to-service calls. *)
  aegis_service_token : (string[@opaque]) option;
  (* STATEGRAPH_MAGIC_LINK_SECRET: shared HMAC key for setup/magic-claim. *)
  magic_link_secret : string option;
  (* STATEGRAPH_INVITATION_TTL_HOURS: how long a tenant invitation link stays valid. *)
  invitation_ttl_hours : int;
  (* GITHUB_APP_CLIENT_ID / GITHUB_APP_CLIENT_SECRET: the orchestration GitHub App's OAuth client,
     used to prove which GitHub user is asking to claim an installation (#1795).  Both or neither;
     the engine already requires the same pair whenever GITHUB_APP_ID is set, so in the unified
     image these are the values the engine is started with. *)
  github_oauth : github_oauth option;
  (* GITHUB_APP_ID: set when the engine's GitHub App comes from the environment. *)
  github_app_id : string option;
  (* Set by the caller of [create] when this deployment supplies the orchestration GitHub App
     itself for every tenant, so the console must not offer to create one. *)
  github_app_managed : bool;
  (* GITHUB_API_BASE_URL / GITHUB_WEB_BASE_URL: the GitHub API and web hosts, github.com unless
     set. *)
  github_api_base : string;
  github_web_base : string;
  (* STATEGRAPH_LICENSE_KEY: opaque self-hosted license key, validated at use-site. *)
  license_key : string option;
  ui_base : string;
  oauth_redirect_base : string;
  oauth_redirect_base_explicit : bool;
  secure_cookies : bool;
}
[@@deriving show]

type err = [ `Key_error of string ] [@@deriving show]

let of_opt fail = function
  | Some v -> Ok v
  | None -> Error fail

let env_str key = of_opt (`Key_error key) (Sys.getenv_opt key)

(* A STATEGRAPH boolean env var is on iff it is exactly "true" or "1"; unset,
   empty, or any other value is off. *)
let env_bool key =
  match Sys.getenv_opt key with
  | Some ("true" | "1") -> true
  | _ -> false

(* Compute a hash of the OAuth2 config for invalidation *)
let compute_oauth2_config_hash ~provider_type ~client_id ~email_domain ~provider_specific =
  let parts = [ provider_type; client_id; email_domain ] @ provider_specific in
  let combined = CCString.concat "|" parts in
  (* Simple hash using Digest - produces hex string *)
  Digest.string combined |> Digest.to_hex

(* Parse OAuth2 configuration from environment variables *)
let parse_oauth2_config () =
  match Sys.getenv_opt "STATEGRAPH_OAUTH_TYPE" with
  | None | Some "" -> Ok None (* OAuth not configured *)
  | Some provider_type ->
      let open CCResult.Infix in
      (* Required fields *)
      env_str "STATEGRAPH_OAUTH_CLIENT_ID"
      >>= fun client_id ->
      env_str "STATEGRAPH_OAUTH_CLIENT_SECRET"
      >>= fun client_secret ->
      let email_domain =
        CCOption.get_or ~default:"*" (Sys.getenv_opt "STATEGRAPH_OAUTH_EMAIL_DOMAIN")
      in
      (* Parse provider-specific config *)
      (match CCString.lowercase_ascii provider_type with
        | "google" ->
            let google_group = Sys.getenv_opt "STATEGRAPH_OAUTH_GOOGLE_GROUP" in
            let google_admin_email = Sys.getenv_opt "STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL" in
            let google_service_account_json =
              Sys.getenv_opt "STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON"
            in
            let provider_specific =
              CCList.filter_map
                CCFun.id
                [ google_group; google_admin_email; google_service_account_json ]
            in
            let config_hash =
              compute_oauth2_config_hash
                ~provider_type:"google"
                ~client_id
                ~email_domain
                ~provider_specific
            in
            Ok
              ( Google { google_group; google_admin_email; google_service_account_json },
                config_hash,
                "google" )
        | "oidc" ->
            (* Pass STATEGRAPH_OAUTH_OIDC_ISSUER_URL through to oauth2-proxy
             EXACTLY as the operator provided it — do not strip trailing
             slashes. Modern oauth2-proxy strict-string-matches the
             configured --oidc-issuer-url against the "issuer" field in
             the provider's discovery doc, and some providers (notably
             Auth0) publish their issuer WITH a trailing slash. Stripping
             here was producing a guaranteed mismatch and crashing
             oauth2-proxy on startup with:
               oidc: issuer did not match the issuer returned by provider,
               expected "https://x.auth0.com" got "https://x.auth0.com/"
             Operators set the env var to match whatever .well-known/
             openid-configuration returns. *)
            env_str "STATEGRAPH_OAUTH_OIDC_ISSUER_URL"
            >>= fun oidc_issuer_url ->
            (if
               not
                 (CCString.prefix ~pre:"https://" oidc_issuer_url
                 || CCString.prefix ~pre:"http://" oidc_issuer_url)
             then
               Error
                 (`Key_error
                    (Printf.sprintf
                       "STATEGRAPH_OAUTH_OIDC_ISSUER_URL: must start with 'https://' or 'http://', \
                        got '%s'"
                       oidc_issuer_url))
             else Ok ())
            >>= fun () ->
            let auth0_rp_logout = env_bool "STATEGRAPH_OAUTH_OIDC_USE_AUTH0_LOGOUT" in
            let config_hash =
              compute_oauth2_config_hash
                ~provider_type:"oidc"
                ~client_id
                ~email_domain
                ~provider_specific:[ oidc_issuer_url ]
            in
            Ok (Oidc { oidc_issuer_url; auth0_rp_logout }, config_hash, "oidc")
        | other ->
            Error
              (`Key_error
                 (Printf.sprintf
                    "STATEGRAPH_OAUTH_TYPE: unknown provider type '%s' (expected 'google' or \
                     'oidc')"
                    other)))
      >>= fun (provider, config_hash, provider_name) ->
      (* Display name: use env var if non-empty, otherwise derive from provider *)
      let display_name =
        match Sys.getenv_opt "STATEGRAPH_OAUTH_DISPLAY_NAME" with
        | Some s when CCString.length (CCString.trim s) > 0 -> CCString.trim s
        | Some _ | None -> (
            match provider_name with
            | "google" -> "Google"
            | _ -> "SSO")
      in
      (* Cookie secret for oauth2-proxy. Prefer an operator-supplied value via
         STATEGRAPH_OAUTH_COOKIE_SECRET so every replica shares ONE secret.
         Generating per process (the fallback below) gives each replica a
         DIFFERENT secret, which breaks login behind a load balancer — the
         replica handling /oauth2/callback can't validate the CSRF/session
         cookie the /oauth2/start replica signed — and invalidates every
         session on each restart. See stategraph/mono#1133. oauth2-proxy
         requires the raw secret to be 16, 24, or 32 bytes (an AES key length). *)
      (match Sys.getenv_opt "STATEGRAPH_OAUTH_COOKIE_SECRET" with
        | Some s when CCString.length (CCString.trim s) > 0 ->
            let s = CCString.trim s in
            let n = CCString.length s in
            if n = 16 || n = 24 || n = 32 then Ok s
            else
              Error
                (`Key_error
                   (Printf.sprintf
                      "STATEGRAPH_OAUTH_COOKIE_SECRET must be 16, 24, or 32 bytes (got %d)"
                      n))
        | Some _ | None ->
            (* TODO(#1133): use a cryptographically secure RNG for this fallback. *)
            let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" in
            let chars_length = CCString.length chars in
            Ok (CCString.init 32 (fun _ -> chars.[Random.int chars_length])))
      >>= fun cookie_secret ->
      Ok
        (Some
           {
             oauth2_display_name = display_name;
             oauth2_client_id = client_id;
             oauth2_client_secret = client_secret;
             oauth2_email_domain = email_domain;
             oauth2_provider = provider;
             oauth2_provider_name = provider_name;
             oauth2_config_hash = config_hash;
             oauth2_cookie_secret = cookie_secret;
           })

let create ?(github_app_managed = false) () =
  let open CCResult.Infix in
  (* Normalized once: every URL built from it is concatenated with a path, and a
     trailing slash there is permanent in a GitHub App's callback URLs. *)
  CCResult.map (CCString.rdrop_while (Char.equal '/')) (env_str "STATEGRAPH_UI_BASE")
  >>= fun ui_base ->
  env_str "DB_HOST"
  >>= fun db_host ->
  let db_port = CCOption.map CCInt.of_string_exn @@ Sys.getenv_opt "DB_PORT" in
  let db_idle_tx_timeout = CCOption.get_or ~default:"180s" (Sys.getenv_opt "DB_IDLE_TX_TIMEOUT") in
  let dwf_idle_tx_timeout =
    CCOption.get_or ~default:"600s" (Sys.getenv_opt "DWF_IDLE_TX_TIMEOUT")
  in
  env_str "DB_USER"
  >>= fun db_user ->
  env_str "DB_PASS"
  >>= fun db_password ->
  env_str "DB_NAME"
  >>= fun db ->
  of_opt
    (`Key_error "DB_CONNECT_TIMEOUT")
    (CCFloat.of_string_opt (CCOption.get_or ~default:"120" (Sys.getenv_opt "DB_CONNECT_TIMEOUT")))
  >>= fun db_connect_timeout ->
  of_opt
    (`Key_error "DB_MAX_POOL_SIZE")
    (CCInt.of_string (CCOption.get_or ~default:"100" (Sys.getenv_opt "DB_MAX_POOL_SIZE")))
  >>= fun db_max_pool_size ->
  of_opt
    (`Key_error "STATEGRAPH_PORT")
    (CCInt.of_string (CCOption.get_or ~default:"8080" (Sys.getenv_opt "STATEGRAPH_PORT")))
  >>= fun port ->
  let statement_timeout =
    CCOption.get_or ~default:"30s" (Sys.getenv_opt "STATEGRAPH_DB_STATEMENT_TIMEOUT")
  in
  let enable_cors = env_bool "STATEGRAPH_ENABLE_CORS" in
  let cors_default_origin =
    CCOption.get_or ~default:cors_default_origin @@ Sys.getenv_opt "STATEGRAPH_CORS_DEFAULT_ORIGIN"
  in
  (* OAuth2 API key for session storage - generate random hex string if not set *)
  let oauth2_api_key =
    let generate_random_key () =
      Random.self_init ();
      let hex_char () =
        let n = Random.int 16 in
        if n < 10 then Char.chr (n + 48) else Char.chr (n + 87)
      in
      CCString.init 32 (fun _ -> hex_char ())
    in
    CCOption.get_or ~default:(generate_random_key ()) (Sys.getenv_opt "STATEGRAPH_OAUTH2_API_KEY")
  in
  (* Parse OAuth2 configuration if present *)
  parse_oauth2_config ()
  >>= fun oauth2 ->
  (* OAuth redirect base URL - where Google redirects after auth.
     In development, this needs to be the backend URL (e.g., http://localhost:8080)
     since the frontend dev server doesn't handle /oauth2/* routes.
     In production with nginx, this can be the same as ui_base. *)
  let oauth_redirect_base_env = Sys.getenv_opt "STATEGRAPH_OAUTH_REDIRECT_BASE" in
  let oauth_redirect_base_explicit = CCOption.is_some oauth_redirect_base_env in
  let oauth_redirect_base =
    CCOption.get_or ~default:(Printf.sprintf "http://localhost:%d" port) oauth_redirect_base_env
  in
  let default_tenant_name =
    match Sys.getenv_opt "STATEGRAPH_DEFAULT_TENANT_NAME" with
    | None -> Some "Default"
    | Some "" -> None
    | some -> some
  in
  let env_str_opt key =
    match Sys.getenv_opt key with
    | None | Some "" -> None
    | some -> some
  in
  let env_str_default key ~default = CCOption.get_or ~default (env_str_opt key) in
  let env_int_default key default =
    match env_str_opt key with
    | None -> default
    | Some v -> CCOption.get_or ~default (CCInt.of_string v)
  in
  let cost_enabled = env_bool "STATEGRAPH_COST_ENABLED" in
  let dedicated_enabled = env_bool "STATEGRAPH_DEDICATED_ENABLED" in
  let terrat_session_cookie_name =
    env_str_default "TERRAT_SESSION_COOKIE_NAME" ~default:"session"
  in
  let fdw_host = env_str_default "STATEGRAPH_FDW_HOST" ~default:"localhost" in
  let fdw_port = env_int_default "STATEGRAPH_FDW_PORT" 5432 in
  let fdw_dbname = env_str_default "STATEGRAPH_FDW_DBNAME" ~default:"terrateam" in
  let fdw_user = env_str_default "STATEGRAPH_FDW_USER" ~default:"stategraph_mql" in
  let fdw_password = env_str_opt "STATEGRAPH_FDW_PASSWORD" in
  let fdw_provisioner_user =
    env_str_default "STATEGRAPH_FDW_PROVISIONER_USER" ~default:"stategraph_provisioner"
  in
  let fdw_provisioner_password = env_str_opt "STATEGRAPH_FDW_PROVISIONER_PASSWORD" in
  (* Unset means on when the FDW password is set: without that password no bridge can be built,
     so the engine has nothing to serve. The image CMD and the nginx render script apply the same
     rule. *)
  let orchestration_explicit =
    match env_str_opt "STATEGRAPH_ORCHESTRATION_ENABLED" with
    | Some ("true" | "1" | "false" | "0") -> true
    | None | Some _ -> false
  in
  let orchestration_enabled =
    match env_str_opt "STATEGRAPH_ORCHESTRATION_ENABLED" with
    | Some ("true" | "1") -> true
    | Some ("false" | "0") -> false
    | None | Some _ -> CCOption.is_some fdw_password
  in
  let github_app_url = env_str_opt "GITHUB_APP_URL" in
  let terrat_api_base = env_str_default "TERRAT_API_BASE" ~default:(ui_base ^ "/api") in
  let pricing_service_url =
    env_str_default "STATEGRAPH_PRICING_SERVICE_URL" ~default:"http://localhost:8090"
  in
  let pricing_default_region =
    env_str_default "STATEGRAPH_PRICING_DEFAULT_REGION" ~default:"us-east-1"
  in
  let cost_schedule_hours = env_int_default "STATEGRAPH_COST_SCHEDULE_HOURS" 24 in
  let cost_event_debounce_hours = env_int_default "STATEGRAPH_COST_EVENT_DEBOUNCE_HOURS" 6 in
  let cost_pricing_call_timeout_seconds =
    env_int_default "STATEGRAPH_COST_PRICING_CALL_TIMEOUT_SECONDS" 30
  in
  let security_schedule_hours = env_int_default "STATEGRAPH_SECURITY_SCHEDULE_HOURS" 24 in
  let security_event_debounce_hours =
    env_int_default "STATEGRAPH_SECURITY_EVENT_DEBOUNCE_HOURS" 1
  in
  let dwf_concurrency = env_int_default "STATEGRAPH_DWF_CONCURRENCY" 40 in
  let preview_exec_timeout_minutes = env_int_default "STATEGRAPH_PREVIEW_EXEC_TIMEOUT_MINUTES" 60 in
  let preview_idle_timeout_minutes = env_int_default "STATEGRAPH_PREVIEW_IDLE_TIMEOUT_MINUTES" 60 in
  let commit_exec_timeout_minutes = env_int_default "STATEGRAPH_COMMIT_EXEC_TIMEOUT_MINUTES" 60 in
  let commit_idle_timeout_minutes = env_int_default "STATEGRAPH_COMMIT_IDLE_TIMEOUT_MINUTES" 60 in
  let task_result_fragment_size =
    env_int_default "STATEGRAPH_TASK_RESULT_FRAGMENT_SIZE" (256 * 1024)
  in
  let aegis_api_base = env_str_opt "STATEGRAPH_AEGIS_API_BASE" in
  let aegis_service_token = env_str_opt "STATEGRAPH_AEGIS_SERVICE_TOKEN" in
  let magic_link_secret = env_str_opt "STATEGRAPH_MAGIC_LINK_SECRET" in
  let invitation_ttl_hours = env_int_default "STATEGRAPH_INVITATION_TTL_HOURS" 168 in
  (* Both-or-neither: a client id without its secret cannot complete a code exchange, and silently
     half-configuring the flow would surface as an opaque GitHub error at the end of a redirect
     chain rather than as "not configured" up front. *)
  let github_api_base = env_str_default "GITHUB_API_BASE_URL" ~default:"https://api.github.com" in
  let github_web_base = env_str_default "GITHUB_WEB_BASE_URL" ~default:"https://github.com" in
  let github_app_id = env_str_opt "GITHUB_APP_ID" in
  let github_oauth =
    match (env_str_opt "GITHUB_APP_CLIENT_ID", env_str_opt "GITHUB_APP_CLIENT_SECRET") with
    | Some client_id, Some client_secret ->
        Some { client_id; client_secret; api_base = github_api_base; web_base = github_web_base }
    | Some _, None | None, Some _ | None, None -> None
  in
  let license_key = env_str_opt "STATEGRAPH_LICENSE_KEY" in
  let secure_cookies = Uri.scheme (Uri.of_string ui_base) = Some "https" in
  (* The FDW user mapping cannot be created without a password; fail config
     load rather than booting an orchestration deployment with a broken
     bridge. *)
  (if orchestration_enabled && CCOption.is_none fdw_password then
     Error (`Key_error "STATEGRAPH_FDW_PASSWORD")
   else Ok ())
  >>= fun () ->
  Ok
    {
      cors_default_origin;
      db;
      db_connect_timeout;
      db_host;
      db_idle_tx_timeout;
      dwf_idle_tx_timeout;
      db_max_pool_size;
      db_password;
      db_port;
      db_user;
      default_tenant_name;
      enable_cors;
      oauth2;
      oauth2_api_key;
      oauth_redirect_base;
      oauth_redirect_base_explicit;
      port;
      cost_enabled;
      dedicated_enabled;
      orchestration_enabled;
      orchestration_explicit;
      terrat_session_cookie_name;
      fdw_host;
      fdw_port;
      fdw_dbname;
      fdw_user;
      fdw_password;
      fdw_provisioner_user;
      fdw_provisioner_password;
      github_app_url;
      terrat_api_base;
      pricing_service_url;
      pricing_default_region;
      cost_schedule_hours;
      cost_event_debounce_hours;
      cost_pricing_call_timeout_seconds;
      security_schedule_hours;
      security_event_debounce_hours;
      dwf_concurrency;
      preview_exec_timeout_minutes;
      preview_idle_timeout_minutes;
      commit_exec_timeout_minutes;
      commit_idle_timeout_minutes;
      task_result_fragment_size;
      aegis_api_base;
      aegis_service_token;
      github_oauth;
      github_app_id;
      github_app_managed;
      github_api_base;
      github_web_base;
      magic_link_secret;
      invitation_ttl_hours;
      license_key;
      secure_cookies;
      statement_timeout;
      ui_base;
    }

let cors_default_origin t = t.cors_default_origin
let db t = t.db
let default_tenant_name t = t.default_tenant_name
let db_connect_timeout t = t.db_connect_timeout
let db_host t = t.db_host
let db_idle_tx_timeout t = t.db_idle_tx_timeout
let dwf_idle_tx_timeout t = t.dwf_idle_tx_timeout
let db_max_pool_size t = t.db_max_pool_size
let db_password t = t.db_password
let db_port t = t.db_port
let db_user t = t.db_user
let enable_cors t = t.enable_cors
let oauth2 t = t.oauth2
let oauth2_api_key t = t.oauth2_api_key
let port t = t.port
let cost_enabled t = t.cost_enabled
let dedicated_enabled t = t.dedicated_enabled
let orchestration_enabled t = t.orchestration_enabled
let orchestration_explicit t = t.orchestration_explicit
let terrat_session_cookie_name t = t.terrat_session_cookie_name
let fdw_host t = t.fdw_host
let fdw_port t = t.fdw_port
let fdw_dbname t = t.fdw_dbname
let fdw_user t = t.fdw_user
let fdw_password t = t.fdw_password
let fdw_provisioner_user t = t.fdw_provisioner_user
let fdw_provisioner_password t = t.fdw_provisioner_password
let github_app_url t = t.github_app_url
let terrat_api_base t = t.terrat_api_base
let pricing_service_url t = t.pricing_service_url
let pricing_default_region t = t.pricing_default_region
let cost_schedule_hours t = t.cost_schedule_hours
let cost_event_debounce_hours t = t.cost_event_debounce_hours
let cost_pricing_call_timeout_seconds t = t.cost_pricing_call_timeout_seconds
let security_schedule_hours t = t.security_schedule_hours
let security_event_debounce_hours t = t.security_event_debounce_hours
let dwf_concurrency t = t.dwf_concurrency
let preview_exec_timeout_minutes t = t.preview_exec_timeout_minutes
let preview_idle_timeout_minutes t = t.preview_idle_timeout_minutes
let commit_exec_timeout_minutes t = t.commit_exec_timeout_minutes
let commit_idle_timeout_minutes t = t.commit_idle_timeout_minutes
let task_result_fragment_size t = t.task_result_fragment_size
let github_oauth t = t.github_oauth
let github_oauth_client_id t = t.client_id
let github_oauth_client_secret t = t.client_secret
let github_oauth_api_base t = t.api_base
let github_oauth_web_base t = t.web_base
let github_app_id t = t.github_app_id
let github_app_managed t = t.github_app_managed
let github_api_base t = t.github_api_base
let github_web_base t = t.github_web_base

let make_github_oauth t ~client_id ~client_secret =
  { client_id; client_secret; api_base = t.github_api_base; web_base = t.github_web_base }

let aegis_api_base t = t.aegis_api_base
let aegis_service_token t = t.aegis_service_token
let magic_link_secret t = t.magic_link_secret
let invitation_ttl_hours t = t.invitation_ttl_hours
let license_key t = t.license_key
let statement_timeout t = t.statement_timeout
let ui_base t = t.ui_base
let oauth_redirect_base t = t.oauth_redirect_base

(* The base of a callback URL handed to a forge. STATEGRAPH_OAUTH_REDIRECT_BASE
   exists for a dev box whose console and server are on different ports, and it
   defaults to localhost, which no forge can reach. A GitHub App is created with
   its callback URLs baked in and its credentials shown once, so registering
   localhost there is not recoverable: fall back to the public URL instead. *)
let public_callback_base t =
  if t.oauth_redirect_base_explicit then t.oauth_redirect_base else t.ui_base

let oauth_redirect_base_explicit t = t.oauth_redirect_base_explicit
let secure_cookies t = t.secure_cookies

(** OAuth2 Provider Types *)
type oauth2_provider =
  | Google of {
      google_group : string option;
      google_admin_email : string option;
      google_service_account_json : string option;
    }
  | Oidc of {
      oidc_issuer_url : string;
      auth0_rp_logout : bool;
          (** STATEGRAPH_OAUTH_OIDC_USE_AUTH0_LOGOUT=true: force Auth0 RP-initiated logout
              regardless of issuer URL hostname. Needed when an Auth0 tenant uses a custom domain so
              the `.auth0.com` URL detection in [Sgs_ep_login] would miss. *)
    }

(** OAuth2 Configuration - present if OAuth is configured *)
type oauth2_config = {
  oauth2_display_name : string;
  oauth2_client_id : string;
  oauth2_client_secret : string;
  oauth2_email_domain : string;
  oauth2_provider : oauth2_provider;
  oauth2_provider_name : string;
      (** Machine-readable provider identifier, e.g., "google", "oidc" *)
  oauth2_config_hash : string;
  oauth2_cookie_secret : string;
}

type t [@@deriving show]
type err = [ `Key_error of string ] [@@deriving show]

val cors_default_origin : t -> string

(** [create ?github_app_managed ()] reads the configuration from the environment.
    [github_app_managed] says that this deployment supplies the orchestration GitHub App itself for
    every tenant; the console then does not offer to create one. It is an argument rather than an
    environment variable because the deployments that set it are the ones that also choose it, and
    only they know. *)
val create : ?github_app_managed:bool -> unit -> (t, [> err ]) result

val db : t -> string
val default_tenant_name : t -> string option
val db_connect_timeout : t -> float
val db_host : t -> string
val db_idle_tx_timeout : t -> string

(** DWF_IDLE_TX_TIMEOUT: [idle_in_transaction_session_timeout] applied to durable-workflow
    transactions specifically (see {!Sgs_dwf.tx}), independent of the connection-wide
    {!db_idle_tx_timeout}. Defaults to ["600s"] (10 minutes). *)
val dwf_idle_tx_timeout : t -> string

val db_max_pool_size : t -> int
val db_password : t -> string
val db_port : t -> int option
val db_user : t -> string
val enable_cors : t -> bool
val oauth2 : t -> oauth2_config option
val oauth2_api_key : t -> string
val port : t -> int

(** STATEGRAPH_COST_ENABLED: master on/off switch for cost estimation. *)
val cost_enabled : t -> bool

(** STATEGRAPH_DEDICATED_ENABLED: master on/off switch for dedicated-Stategraph provisioning (the
    "Create Dedicated Stategraph" flow and the personal/dev-eval tenant labeling). Defaults to off.
*)
val dedicated_enabled : t -> bool

(** STATEGRAPH_ORCHESTRATION_ENABLED: master on/off switch for the orchestration engine integration.
    [true] turns it on and makes [create] require STATEGRAPH_FDW_PASSWORD; [false] turns it off;
    unset means on exactly when STATEGRAPH_FDW_PASSWORD is set. When on, the boot-time FDW reconcile
    creates the postgres_fdw bridge to the terrateam database. The image CMD and nginx apply the
    same rule to gate the terrat service and its routes. *)
val orchestration_enabled : t -> bool

(** Whether STATEGRAPH_ORCHESTRATION_ENABLED decided {!orchestration_enabled}, rather than the
    presence of STATEGRAPH_FDW_PASSWORD implying it. A deployment that asked for orchestration is
    told loudly when its bridge cannot be built; one that got it by default keeps serving everything
    else. *)
val orchestration_explicit : t -> bool

(** TERRAT_SESSION_COOKIE_NAME (default "session", as in the orchestration engine): the name of the
    engine's browser session cookie. The engine shares the console's origin, so logout must expire
    this cookie too. *)
val terrat_session_cookie_name : t -> string

(** STATEGRAPH_FDW_HOST (default "localhost"): host of the terrateam database as seen from the
    stategraph database server (the FDW connects server-side). *)
val fdw_host : t -> string

(** STATEGRAPH_FDW_PORT (default 5432). *)
val fdw_port : t -> int

(** STATEGRAPH_FDW_DBNAME (default "terrateam"). *)
val fdw_dbname : t -> string

(** STATEGRAPH_FDW_USER (default "stategraph_mql"): the least-privilege role on the terrateam
    database the user mapping authenticates as. *)
val fdw_user : t -> string

(** STATEGRAPH_FDW_PASSWORD: password for {!fdw_user}. Required when orchestration is enabled. *)
val fdw_password : t -> string option

(** STATEGRAPH_FDW_PROVISIONER_USER (default "stategraph_provisioner"): the dedicated write role the
    second, write-capable FDW user mapping authenticates as. *)
val fdw_provisioner_user : t -> string

(** STATEGRAPH_FDW_PROVISIONER_PASSWORD: password for {!fdw_provisioner_user}. Optional — when unset
    the narrow admin FDW bridge is not built and GitLab provisioning is unavailable. *)
val fdw_provisioner_password : t -> string option

(** GITHUB_APP_URL: the GitHub App install URL, surfaced to the console so the getting-started
    GitHub card can link to the app install. Optional, and deliberately without the default
    [Terrat_config] gives the same variable: that default is Terrateam's own public app, so a
    self-hosted operator running their own App would be sent to install the wrong one, producing an
    installation their orchestration side never sees. Unset (or empty) means the console shows
    manual install steps instead of a link. *)
val github_app_url : t -> string option

(** TERRAT_API_BASE: the public base of the orchestration engine's API, STATEGRAPH_UI_BASE plus
    [/api] unless set. The same derivation the unified image's terrat service applies. *)
val terrat_api_base : t -> string

(** STATEGRAPH_PRICING_SERVICE_URL: endpoint of the pricing service, used when cost estimation is
    enabled. Defaults to the in-image service. *)
val pricing_service_url : t -> string

(** STATEGRAPH_PRICING_DEFAULT_REGION: region passed to the pricing service for resources whose
    [region] attribute is not set. Defaults to "us-east-1". *)
val pricing_default_region : t -> string

(** STATEGRAPH_COST_SCHEDULE_HOURS: minimum age (in hours) of the latest snapshot before the
    scheduler recomputes it. The schedule itself fires hourly (per state); this knob is the inline
    gate that the dispatcher applies before doing any pricing work. Defaults to 24. *)
val cost_schedule_hours : t -> int

(** STATEGRAPH_COST_EVENT_DEBOUNCE_HOURS: skip a scheduled recompute when an event-triggered
    snapshot for the same state landed within this window. Defaults to 6. *)
val cost_event_debounce_hours : t -> int

(** STATEGRAPH_COST_PRICING_CALL_TIMEOUT_SECONDS: cap on each HTTP call to the pricing service.
    Defaults to 30 (seconds). *)
val cost_pricing_call_timeout_seconds : t -> int

(** STATEGRAPH_SECURITY_SCHEDULE_HOURS: minimum age (in hours) of the latest current security scan
    before the scheduler re-scans the state. The schedule itself fires hourly (per state); this knob
    is the inline gate the dispatcher applies before doing any scanning work. Defaults to 24. *)
val security_schedule_hours : t -> int

(** STATEGRAPH_SECURITY_EVENT_DEBOUNCE_HOURS: skip a scheduled re-scan when an event-triggered
    current scan for the same state landed within this window. Defaults to 1. *)
val security_event_debounce_hours : t -> int

(** STATEGRAPH_DWF_CONCURRENCY: total number of durable workflows (preview, commit, ...) run
    concurrently across all types, sharing one bounded executor. Defaults to 40. *)
val dwf_concurrency : t -> int

(** STATEGRAPH_PREVIEW_EXEC_TIMEOUT_MINUTES: total wall-clock cap on a single preview run, from
    creation. Defaults to 60 (minutes). *)
val preview_exec_timeout_minutes : t -> int

(** STATEGRAPH_PREVIEW_IDLE_TIMEOUT_MINUTES: how long a preview workflow may sit waiting for the
    actuator's result before it is abandoned. Defaults to 60 (minutes). *)
val preview_idle_timeout_minutes : t -> int

(** STATEGRAPH_COMMIT_EXEC_TIMEOUT_MINUTES: total wall-clock cap on a single commit run, from
    creation. Defaults to 60 (minutes). *)
val commit_exec_timeout_minutes : t -> int

(** STATEGRAPH_COMMIT_IDLE_TIMEOUT_MINUTES: how long a commit workflow may sit waiting for the
    actuator's result before it is abandoned. Defaults to 60 (minutes). *)
val commit_idle_timeout_minutes : t -> int

(** STATEGRAPH_TASK_RESULT_FRAGMENT_SIZE: the byte size a stored run result (a plan or apply output)
    is cut into, one fragment per [task_results] row. It caps the size of a single row and,
    multiplied by the output endpoint's page limit, the memory one response can hold, so it is
    deliberately in the kilobytes range. Defaults to 256 KiB. *)
val task_result_fragment_size : t -> int

(** STATEGRAPH_AEGIS_API_BASE: base URL of the Aegis control plane (e.g.
    https://api.stategraph.cloud). None = dedicated provisioning is disabled (Sgs_aegis returns
    [`Not_configured_err]). *)
val aegis_api_base : t -> string option

(** STATEGRAPH_AEGIS_SERVICE_TOKEN: shared bearer token for service-to-service calls to Aegis. None
    = dedicated provisioning is disabled. *)
val aegis_service_token : t -> string option

(** STATEGRAPH_MAGIC_LINK_SECRET: HMAC key for setup/magic-claim. None = self-hosted. *)
val magic_link_secret : t -> string option

(** STATEGRAPH_INVITATION_TTL_HOURS: how long a tenant invitation link stays valid. Defaults to 168
    (7 days). Bounds the window in which a leaked or mistyped invitation is usable, which is the
    main mitigation for an invitation sent to the wrong address. *)
val invitation_ttl_hours : t -> int

(** The orchestration GitHub App's OAuth client, used to establish which GitHub user is driving an
    installation claim (#1795). The App's private key is deliberately not here: this client can
    identify a user, never act as the App. *)
type github_oauth

(** GITHUB_APP_CLIENT_ID and GITHUB_APP_CLIENT_SECRET, both or neither. None = the GitHub identity
    claim flow is unavailable and its endpoints answer 503. *)
val github_oauth : t -> github_oauth option

val github_oauth_client_id : github_oauth -> string
val github_oauth_client_secret : github_oauth -> string

(** GITHUB_API_BASE_URL, defaulting to https://api.github.com. Same variable the engine reads, so
    GitHub Enterprise deployments configure it once. *)
val github_oauth_api_base : github_oauth -> string

(** GITHUB_WEB_BASE_URL, defaulting to https://github.com. The host the user is redirected to for
    authorization. *)
val github_oauth_web_base : github_oauth -> string

(** [make_github_oauth t ~client_id ~client_secret] is the OAuth client of a GitHub App stored in
    the orchestration database, on the GitHub hosts of {!github_api_base} and {!github_web_base}. *)
val make_github_oauth : t -> client_id:string -> client_secret:string -> github_oauth

(** GITHUB_APP_ID: set when the engine's GitHub App comes from the environment, in which case the
    stored App row is ignored on both sides. *)
val github_app_id : t -> string option

(** Whether this deployment supplies the orchestration GitHub App itself for every tenant. *)
val github_app_managed : t -> bool

(** GITHUB_API_BASE_URL, defaulting to https://api.github.com. *)
val github_api_base : t -> string

(** GITHUB_WEB_BASE_URL, defaulting to https://github.com. *)
val github_web_base : t -> string

(** STATEGRAPH_LICENSE_KEY: opaque self-hosted license key. [None] when unset; validity is checked
    at use-site. *)
val license_key : t -> string option

val statement_timeout : t -> string
val ui_base : t -> string
val oauth_redirect_base : t -> string
val oauth_redirect_base_explicit : t -> bool

(** The base of a callback URL registered with a forge: {!oauth_redirect_base} when it was set, else
    {!ui_base}. The former defaults to localhost, which no forge can reach, and a GitHub App carries
    its callback URLs permanently. *)
val public_callback_base : t -> string

val secure_cookies : t -> bool

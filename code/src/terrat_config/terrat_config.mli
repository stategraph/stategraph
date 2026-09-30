module Github : sig
  type action_dynamic_title_item =
    [ `Pr_title
    | `Pr_number
    | `Run_kind
    | `Run_type
    ]
  [@@deriving show]

  type t [@@deriving show]

  val action_dynamic_title : t -> action_dynamic_title_item list
  val api_base_url : t -> Uri.t
  val app_client_id : t -> string
  val app_client_secret : t -> string
  val app_id : t -> string
  val app_pem : t -> Mirage_crypto_pk.Rsa.priv
  val app_url : t -> Uri.t
  val call_timeout : t -> float
  val web_base_url : t -> Uri.t
  val webhook_secret : t -> string option
  val workflow_path_override : t -> string option
end

module Gitlab : sig
  type t [@@deriving show]

  (* #899 TODO This will be removed once the migration is done *)
  val access_token : t -> string
  val api_base_url : t -> Uri.t
  val app_id : t -> string
  val app_secret : t -> string
  val call_timeout : t -> float
  val web_base_url : t -> Uri.t
end

type t [@@deriving show]

type err =
  [ `Key_error of string
  | `Bad_pem of string
  ]

module Telemetry : sig
  type t =
    | Disabled
    | Anonymous of Uri.t
end

module Infracost : sig
  (** How the connection to the pricing database treats TLS, as the libpq [sslmode] values name it.
  *)
  type sslmode =
    | Disable
    | Prefer
    | Require
  [@@deriving show]

  (** Connection settings of the [cloud_pricing] database that holds the price book. *)
  type price_book = {
    db : string;
    host : string;
    password : string;
    port : int;
    sslmode : sslmode;
    user : string;
  }
  [@@deriving show]

  (** An Infracost pricing API that the engine forwards the CLI requests to, with [api_key] in place
      of the key the CLI sent. *)
  type proxy = {
    api_key : string;
    endpoint : Uri.t;
  }
  [@@deriving show]

  (** [Proxy] when [INFRACOST_PRICING_API_ENDPOINT] and [SELF_HOSTED_INFRACOST_API_KEY] are both
      non-empty, otherwise [Price_book] when [PRICING_DB_HOST] is non-empty. *)
  type t =
    | Proxy of proxy
    | Price_book of price_book
  [@@deriving show]
end

module Gc : sig
  type dynamic_gc = DynamicGc.config = {
    min_space_overhead : int;
    max_space_overhead : int;
    heap_start_worrying_mb : int;
    heap_really_worry_mb : int;
  }
  [@@deriving show]

  type t = { dynamic_gc : dynamic_gc option } [@@deriving show]
end

val admin_token : t -> string option
val api_base : t -> string
val create : unit -> (t, [> err ]) result

(** The GitHub App a row of the orchestration database describes. The GitHub hosts, the call timeout
    and the workflow overrides come from the environment, as for the App of the environment. *)
val github_of_stored :
  app_id:string ->
  pem:string ->
  client_id:string ->
  client_secret:string ->
  webhook_secret:string ->
  app_url:string ->
  (Github.t, [> err ]) result

(** [with_github t github] is [t] with [github] as its GitHub App. *)
val with_github : t -> Github.t -> t

(** Build a configuration from explicit values, with no read of the environment. A test uses it to
    get a configuration that differs from the process environment, for example a test that runs
    several databases at the same time and must not change the environment that the others read. An
    optional argument that is not given is [None]. *)
val make :
  ?admin_token:string ->
  api_base:string ->
  db:string ->
  db_connect_timeout:float ->
  db_host:string ->
  db_port:int ->
  db_idle_tx_timeout:string ->
  db_lock_timeout:string ->
  db_max_pool_size:int ->
  db_password:string ->
  db_user:string ->
  default_tier:string ->
  event_evaluator_slots:int ->
  gc:Gc.t ->
  ?github:Github.t ->
  ?gitlab:Gitlab.t ->
  ?infracost:Infracost.t ->
  ?nginx_status_uri:Uri.t ->
  port:int ->
  python_exec:string ->
  session_cookie_name:string ->
  ?stategraph_ui_base:Uri.t ->
  statement_timeout:string ->
  telemetry:Telemetry.t ->
  ?terrateam_ui_base:Uri.t ->
  terrateam_web_base_url:Uri.t ->
  unit ->
  t

val db : t -> string
val db_connect_timeout : t -> float
val db_host : t -> string
val db_port : t -> int
val db_idle_tx_timeout : t -> string
val db_lock_timeout : t -> string
val db_max_pool_size : t -> int
val db_password : t -> string
val db_user : t -> string
val default_tier : t -> string
val event_evaluator_slots : t -> int
val gc : t -> Gc.t
val github : t -> Github.t option
val gitlab : t -> Gitlab.t option
val infracost : t -> Infracost.t option
val nginx_status_uri : t -> Uri.t option
val port : t -> int
val python_exec : t -> string

(** TERRAT_SESSION_COOKIE_NAME (default "session"): the name of the browser session cookie. It must
    differ from the name of any other auth cookie on the same origin, or each login overwrites the
    other's session. A value that is not a valid cookie name is a config error. *)
val session_cookie_name : t -> string

val show_err : err -> string
val statement_timeout : t -> string
val telemetry : t -> Telemetry.t
val terrateam_web_base_url : t -> Uri.t

(** The console base of a brand, from the first source that is set: [STATEGRAPH_UI_BASE] for
    [Stategraph], [TERRAT_UI_BASE] for [Terrateam], then {!terrateam_web_base_url}. It carries no
    trailing slash, so a caller joins it with a path directly. *)
val web_base_url : t -> Terrat_brand.t -> Uri.t

(** [rebrand_url t brand url] answers [url] with a leading {!terrateam_web_base_url} replaced by the
    console base of [brand]:

    {[
    (* TERRAT_WEB_BASE_URL = "https://app.example.com"
       TERRAT_UI_BASE      = "https://app.terrateam.io" *)
    rebrand_url t Terrateam "https://app.example.com/i/7/runs/ab-cd"
    (* = "https://app.terrateam.io/i/7/runs/ab-cd" *)
    ]}

    A URL that opens on another base passes through, so a link read back from the forge and
    published again keeps one base. *)
val rebrand_url : t -> Terrat_brand.t -> string -> string

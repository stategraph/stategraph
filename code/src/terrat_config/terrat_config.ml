let default_telemetry_uri = Uri.of_string "https://telemetry.terrateam.io"
let default_terrateam_web_base_url = Uri.of_string "https://app.terrateam.io"
let default_vcs_call_timeout = 20.0

module Github = struct
  let default_github_api_base_url = Uri.of_string "https://api.github.com"
  let default_github_app_url = Uri.of_string "https://github.com/apps/terrateam-action"
  let default_github_web_base_url = Uri.of_string "https://github.com"

  type action_dynamic_title_item =
    [ `Pr_title
    | `Pr_number
    | `Run_kind
    | `Run_type
    ]
  [@@deriving show]

  type t = {
    action_dynamic_title : action_dynamic_title_item list;
    api_base_url : Uri.t;
    app_client_id : string;
    app_client_secret : (string[@opaque]);
    app_id : string;
    app_pem : (Mirage_crypto_pk.Rsa.priv[@opaque]);
    app_url : Uri.t;
    call_timeout : float;
    web_base_url : Uri.t;
    webhook_secret : (string[@opaque]) option;
    workflow_path_override : string option;
  }
  [@@deriving show]

  let action_dynamic_title t = t.action_dynamic_title
  let api_base_url t = t.api_base_url
  let app_client_id t = t.app_client_id
  let app_client_secret t = t.app_client_secret
  let app_id t = t.app_id
  let app_pem t = t.app_pem
  let app_url t = t.app_url
  let call_timeout t = t.call_timeout
  let web_base_url t = t.web_base_url
  let webhook_secret t = t.webhook_secret
  let workflow_path_override t = t.workflow_path_override
end

module Gitlab = struct
  let default_gitlab_api_base_url = Uri.of_string "https://gitlab.com"
  let default_gitlab_web_base_url = Uri.of_string "https://gitlab.com"

  type t = {
    (* #899 TODO Access Token will be removed once the migration is done *)
    access_token : (string[@opaque]);
    api_base_url : Uri.t;
    app_id : string;
    app_secret : (string[@opaque]);
    call_timeout : float;
    web_base_url : Uri.t;
  }
  [@@deriving show]

  (* #899 TODO Access Token will be removed once the migration is done *)
  let access_token t = t.access_token
  let api_base_url t = t.api_base_url
  let app_id t = t.app_id
  let app_secret t = t.app_secret
  let call_timeout t = t.call_timeout
  let web_base_url t = t.web_base_url
end

module Telemetry = struct
  type t =
    | Disabled
    | Anonymous of Uri.t
  [@@deriving show]
end

module Infracost = struct
  type t = {
    api_key : string; [@opaque]
    endpoint : Uri.t;
  }
  [@@deriving show]
end

module Gc = struct
  type dynamic_gc = DynamicGc.config = {
    min_space_overhead : int;
    max_space_overhead : int;
    heap_start_worrying_mb : int;
    heap_really_worry_mb : int;
  }
  [@@deriving show]

  type t = { dynamic_gc : dynamic_gc option } [@@deriving show]
end

type t = {
  admin_token : string option;
  api_base : string;
  db : string;
  db_connect_timeout : float;
  db_host : string;
  db_port : int;
  db_idle_tx_timeout : string;
  db_lock_timeout : string;
  db_max_pool_size : int;
  db_password : (string[@opaque]);
  db_user : string;
  default_tier : string;
  event_evaluator_slots : int;
  gc : Gc.t;
  github : Github.t option;
  gitlab : Gitlab.t option;
  infracost : Infracost.t option;
  nginx_status_uri : Uri.t option;
  port : int;
  python_exec : string;
  statement_timeout : string;
  telemetry : Telemetry.t;
  terrateam_web_base_url : Uri.t;
}
[@@deriving show]

type err =
  [ `Key_error of string
  | `Bad_pem of string
  ]
[@@deriving show]

let of_opt fail = function
  | Some v -> Ok v
  | None -> Error fail

let env_str key = of_opt (`Key_error key) (Sys.getenv_opt key)

let vcs_call_timeout () =
  match Sys.getenv_opt "TERRAT_VCS_CALL_TIMEOUT" with
  | None | Some "" -> Ok default_vcs_call_timeout
  | Some timeout -> of_opt (`Key_error "TERRAT_VCS_CALL_TIMEOUT") (CCFloat.of_string_opt timeout)

let infracost () =
  let infracost_pricing_api_endpoint = Sys.getenv_opt "INFRACOST_PRICING_API_ENDPOINT" in
  let infracost_api_key = Sys.getenv_opt "SELF_HOSTED_INFRACOST_API_KEY" in
  match (infracost_pricing_api_endpoint, infracost_api_key) with
  | Some "", _ | _, Some "" -> None
  | Some endpoint, Some api_key -> Some { Infracost.endpoint = Uri.of_string endpoint; api_key }
  | _, _ -> None

let load_github () =
  let open CCResult.Infix in
  match Sys.getenv_opt "GITHUB_APP_ID" with
  | Some "" | None -> Ok None
  | Some app_id ->
      let webhook_secret = Sys.getenv_opt "GITHUB_WEBHOOK_SECRET" in
      env_str "GITHUB_APP_PEM"
      >>= fun app_pem_content ->
      (match X509.Private_key.decode_pem app_pem_content with
        | Ok (`RSA v) -> Ok v
        | Ok _ -> Error (`Bad_pem "Expected RSA")
        | Error (`Msg s) -> Error (`Bad_pem s))
      >>= fun app_pem ->
      env_str "GITHUB_APP_CLIENT_SECRET"
      >>= fun app_client_secret ->
      env_str "GITHUB_APP_CLIENT_ID"
      >>= fun app_client_id ->
      let api_base_url =
        CCOption.map_or
          ~default:Github.default_github_api_base_url
          Uri.of_string
          (Sys.getenv_opt "GITHUB_API_BASE_URL")
      in
      let web_base_url =
        CCOption.map_or
          ~default:Github.default_github_web_base_url
          Uri.of_string
          (Sys.getenv_opt "GITHUB_WEB_BASE_URL")
      in
      let app_url =
        CCOption.map_or
          ~default:Github.default_github_app_url
          Uri.of_string
          (Sys.getenv_opt "GITHUB_APP_URL")
      in
      vcs_call_timeout ()
      >>= fun call_timeout ->
      let workflow_path_override = Sys.getenv_opt "GITHUB_WORKFLOW_PATH_OVERRIDE" in
      let action_dynamic_title =
        CCOption.map_or
          ~default:[]
          (fun s ->
            s
            |> CCString.split_on_char ','
            |> CCList.sort_uniq ~cmp:CCString.compare
            |> CCList.filter_map (function
              | "pr_title" -> Some `Pr_title
              | "pr_number" -> Some `Pr_number
              | "run_kind" -> Some `Run_kind
              | "run_type" -> Some `Run_type
              | "" -> None
              | _ -> None))
          (Sys.getenv_opt "GITHUB_ACTION_DYNAMIC_TITLE")
      in
      Ok
        (Some
           {
             Github.action_dynamic_title;
             api_base_url;
             app_client_id;
             app_client_secret;
             app_id;
             app_pem;
             app_url;
             call_timeout;
             web_base_url;
             webhook_secret;
             workflow_path_override;
           })

let load_gitlab () =
  let open CCResult.Infix in
  match Sys.getenv_opt "GITLAB_APP_ID" with
  | Some "" | None -> Ok None
  | Some app_id ->
      env_str "GITLAB_APP_SECRET"
      >>= fun app_secret ->
      let api_base_url =
        CCOption.map_or ~default:Gitlab.default_gitlab_api_base_url Uri.of_string
        @@ Sys.getenv_opt "GITLAB_API_BASE_URL"
      in
      let web_base_url =
        CCOption.map_or ~default:Gitlab.default_gitlab_web_base_url Uri.of_string
        @@ Sys.getenv_opt "GITLAB_WEB_BASE_URL"
      in
      env_str "GITLAB_ACCESS_TOKEN"
      >>= fun access_token ->
      vcs_call_timeout ()
      >>= fun call_timeout ->
      (* #899 TODO Access Token will be removed once migration is over *)
      Ok
        (Some { Gitlab.access_token; api_base_url; app_id; app_secret; call_timeout; web_base_url })

let load_gc () =
  let dynamic_gc' () =
    let open CCOption.Infix in
    Sys.getenv_opt "TERRAT_GC_MIN_SPACE_OVERHEAD"
    >>= fun min_space_overhead ->
    Sys.getenv_opt "TERRAT_GC_MAX_SPACE_OVERHEAD"
    >>= fun max_space_overhead ->
    Sys.getenv_opt "TERRAT_GC_HEAP_SPACE_OVERHEAD_START_MB"
    >>= fun heap_start ->
    Sys.getenv_opt "TERRAT_GC_HEAP_SPACE_OVERHEAD_REALLY_MB"
    >>= fun heap_really -> Some (min_space_overhead, max_space_overhead, heap_start, heap_really)
  in
  let dynamic_gc () =
    match dynamic_gc' () with
    | None -> Ok None
    | Some (min_space_overhead, max_space_overhead, heap_start, heap_really) ->
        let open CCResult.Infix in
        of_opt (`Key_error "TERRAT_GC_MIN_SPACE_OVERHEAD") @@ CCInt.of_string min_space_overhead
        >>= fun min_space_overhead ->
        of_opt (`Key_error "TERRAT_GC_MAX_SPACE_OVERHEAD") @@ CCInt.of_string max_space_overhead
        >>= fun max_space_overhead ->
        of_opt (`Key_error "TERRAT_GC_HEAP_SPACE_OVERHEAD_START_MB") @@ CCInt.of_string heap_start
        >>= fun heap_start ->
        of_opt (`Key_error "TERRAT_GC_HEAP_SPACE_OVERHEAD_REALLY_MB") @@ CCInt.of_string heap_really
        >>= fun heap_really ->
        Ok
          (Some
             {
               DynamicGc.min_space_overhead;
               max_space_overhead;
               heap_start_worrying_mb = heap_start;
               heap_really_worry_mb = heap_really;
             })
  in
  let open CCResult.Infix in
  dynamic_gc () >>= fun dynamic_gc -> Ok { Gc.dynamic_gc }

let create () =
  let open CCResult.Infix in
  (* This is required for Terrateam UI to work correctly so we simply check if
     it is set to we can error to the user if it is not, we do not use it in the
     actual server. *)
  env_str "TERRAT_UI_BASE"
  >>= fun _ ->
  (* Validated here so a typo fails boot; the value itself is read by
     Terrat_check_title at the VCS boundary. Consumers accept both brands
     regardless, so this only decides what new commit checks are named. *)
  (match Sys.getenv_opt "TERRAT_CHECK_TITLE_BRAND" with
    | None | Some "terrateam" | Some "stategraph" -> Ok ()
    | Some _ -> Error (`Key_error "TERRAT_CHECK_TITLE_BRAND: must be terrateam or stategraph"))
  >>= fun () ->
  of_opt
    (`Key_error "TERRAT_PORT")
    (CCInt.of_string (CCOption.get_or ~default:"8080" (Sys.getenv_opt "TERRAT_PORT")))
  >>= fun port ->
  env_str "DB_HOST"
  >>= fun db_host ->
  of_opt
    (`Key_error "DB_PORT")
    (CCInt.of_string (CCOption.get_or ~default:"5432" (Sys.getenv_opt "DB_PORT")))
  >>= fun db_port ->
  let db_idle_tx_timeout = CCOption.get_or ~default:"180s" (Sys.getenv_opt "DB_IDLE_TX_TIMEOUT") in
  let db_lock_timeout = CCOption.get_or ~default:"120s" (Sys.getenv_opt "DB_LOCK_TIMEOUT") in
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
  env_str "TERRAT_API_BASE"
  >>= fun api_base ->
  env_str "TERRAT_PYTHON_EXEC"
  >>= fun python_exec ->
  of_opt
    (`Key_error "TERRAT_EVENT_EVALUATOR_SLOTS")
    (CCInt.of_string
       (CCOption.get_or ~default:"20" (Sys.getenv_opt "TERRAT_EVENT_EVALUATOR_SLOTS")))
  >>= fun event_evaluator_slots ->
  let infracost = infracost () in
  let nginx_status_uri = CCOption.map Uri.of_string (Sys.getenv_opt "NGINX_STATUS_URI") in
  let admin_token = Sys.getenv_opt "TERRAT_ADMIN_TOKEN" in
  let telemetry_uri =
    CCOption.map_or
      ~default:default_telemetry_uri
      Uri.of_string
      (Sys.getenv_opt "TERRAT_TELEMETRY_URI")
  in
  of_opt
    (`Key_error "TERRAT_TELEMETRY_LEVEL")
    (match CCOption.get_or ~default:"anonymous" (Sys.getenv_opt "TERRAT_TELEMETRY_LEVEL") with
    | "anonymous" -> Some (Telemetry.Anonymous telemetry_uri)
    | "disabled" -> Some Telemetry.Disabled
    | _ -> None)
  >>= fun telemetry ->
  let terrateam_web_base_url =
    CCOption.map_or
      ~default:default_terrateam_web_base_url
      Uri.of_string
      (Sys.getenv_opt "TERRAT_WEB_BASE_URL")
  in
  let statement_timeout =
    CCOption.get_or ~default:"5s" (Sys.getenv_opt "TERRAT_STATEMENT_TIMEOUT")
  in
  load_github ()
  >>= fun github ->
  load_gitlab ()
  >>= fun gitlab ->
  let default_tier = CCOption.get_or ~default:"unlimited" @@ Sys.getenv_opt "TERRAT_DEFAULT_TIER" in
  load_gc ()
  >>= fun gc ->
  Ok
    {
      admin_token;
      api_base;
      db;
      db_connect_timeout;
      db_host;
      db_port;
      db_idle_tx_timeout;
      db_lock_timeout;
      db_max_pool_size;
      db_password;
      db_user;
      default_tier;
      event_evaluator_slots;
      gc;
      github;
      gitlab;
      infracost;
      nginx_status_uri;
      port;
      python_exec;
      statement_timeout;
      telemetry;
      terrateam_web_base_url;
    }

let admin_token t = t.admin_token
let api_base t = t.api_base
let db t = t.db
let db_connect_timeout t = t.db_connect_timeout
let db_host t = t.db_host
let db_port t = t.db_port
let db_idle_tx_timeout t = t.db_idle_tx_timeout
let db_lock_timeout t = t.db_lock_timeout
let db_max_pool_size t = t.db_max_pool_size
let db_password t = t.db_password
let db_user t = t.db_user
let default_tier t = t.default_tier
let event_evaluator_slots t = t.event_evaluator_slots
let gc t = t.gc
let github t = t.github
let gitlab t = t.gitlab
let infracost t = t.infracost
let nginx_status_uri t = t.nginx_status_uri
let port t = t.port
let python_exec t = t.python_exec
let statement_timeout t = t.statement_timeout
let telemetry t = t.telemetry
let terrateam_web_base_url t = t.terrateam_web_base_url

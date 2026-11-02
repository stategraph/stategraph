let src = Logs.Src.create "oauth2"

module Logs = (val Logs.src_log src : Logs.LOG)

type t = {
  authenticator : Oauth2_htp.t;
  provider_name : string;
}

type create_err =
  [ `No_oauth_config
  | `Invalid_config of string
  | `Setup_timeout
  | Oauth2_htp.err
  ]
[@@deriving show]

(* A value whose first non-whitespace character is '{' is the key itself, anything else is the path
   of the key file. A filesystem path can't start with '{', so the two are unambiguous. *)
let service_account_key value =
  if CCString.prefix ~pre:"{" (CCString.trim value) then Ok value
  else
    CCResult.map_err
      (fun msg ->
        `Invalid_config
          (Printf.sprintf
             "STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON: reading %s failed: %s"
             value
             msg))
      (CCIO.File.read value)

let non_empty = function
  | Some s when not (CCString.is_empty (CCString.trim s)) -> Some s
  | Some _ | None -> None

(* A comma-separated setting: its non-empty values, trimmed. *)
let split_list value =
  CCList.filter
    (fun v -> not (CCString.is_empty v))
    (CCList.map CCString.trim (CCString.split_on_char ',' value))

(* A group lookup goes through the Admin SDK as the admin, with the service account's key. *)
let google_group_of_provider = function
  | Sgs_config.Oidc _ -> Ok None
  | Sgs_config.Google { google_group; google_admin_email; google_service_account_json } -> (
      match
        (non_empty google_group, non_empty google_admin_email, non_empty google_service_account_json)
      with
      | None, None, None -> Ok None
      | group, Some admin_email, Some value ->
          CCResult.map
            (fun service_account_json ->
              Some
                {
                  Oauth2_htp_google.Group.groups = CCOption.map_or ~default:[] split_list group;
                  admin_email;
                  service_account_json;
                })
            (service_account_key value)
      | _, Some _, None | _, None, Some _ | Some _, None, None ->
          Error
            (`Invalid_config
               "STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL and \
                STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON must be set together, and \
                STATEGRAPH_OAUTH_GOOGLE_GROUP needs both"))

let email_domains_of_config oauth2_config =
  match split_list oauth2_config.Sgs_config.oauth2_email_domain with
  | [] ->
      Error
        (`Invalid_config
           "STATEGRAPH_OAUTH_EMAIL_DOMAIN is empty: set a domain, or * to allow any email")
  | domains -> Ok domains

(* How long setting up the provider may take before OAuth sign-in is disabled. *)
let setup_timeout = 10.0

let domain_of_url url =
  let uri = Uri.of_string url in
  let host = Uri.host_with_default ~default:"localhost" uri in
  match Uri.port uri with
  | Some port -> Printf.sprintf "%s:%d" host port
  | None -> host

let make_config ~group ~email_domains ~callback_url config oauth2_config =
  let {
    Sgs_config.oauth2_client_id = client_id;
    oauth2_client_secret = client_secret;
    oauth2_cookie_secret = cookie_secret;
    oauth2_email_domain = _;
    oauth2_provider;
    oauth2_provider_name = _;
    oauth2_display_name = _;
    oauth2_config_hash = _;
  } =
    oauth2_config
  in
  let oauth_redirect_base = Sgs_config.oauth_redirect_base config in
  (* Sign-in may return to the backend or, in development, to a UI on another origin. *)
  let whitelist_domains =
    Sln_list.String.uniq
      [ domain_of_url oauth_redirect_base; domain_of_url (Sgs_config.ui_base config) ]
  in
  let provider, login_params =
    match oauth2_provider with
    | Sgs_config.Google _ ->
        (* Let users choose which Google account to sign in with. *)
        (Oauth2_htp.Config.Google { group }, [ ("prompt", "select_account") ])
    | Sgs_config.Oidc { oidc_issuer_url; auth0_rp_logout = _ } ->
        (Oauth2_htp.Config.Oidc { issuer_url = oidc_issuer_url }, [])
  in
  Oauth2_htp.Config.make
    ~login_params
    ~provider
    ~client_id
    ~client_secret
    ~redirect_url:callback_url
    ~whitelist_domains
    ~email_domains
    ~cookie_secret
    ~cookie_secure:(Uri.scheme (Uri.of_string oauth_redirect_base) = Some "https")
    ()

let create config =
  match Sgs_config.oauth2 config with
  | None ->
      Logs.info (fun m -> m "No OAuth2 configuration - OAuth sign-in disabled");
      Abbs_fc.return_err `No_oauth_config
  | Some oauth2_config -> (
      match
        CCResult.both
          (google_group_of_provider oauth2_config.Sgs_config.oauth2_provider)
          (email_domains_of_config oauth2_config)
      with
      | Error (`Invalid_config _ as err) -> Abbs_fc.return_err err
      | Ok (group, email_domains) -> (
          let provider_name = oauth2_config.Sgs_config.oauth2_provider_name in
          let oauth_redirect_base = Sgs_config.oauth_redirect_base config in
          let callback_url =
            Printf.sprintf "%s/oauth2/%s/callback" oauth_redirect_base provider_name
          in
          Logs.info (fun m ->
              m
                "OAUTH2_CONFIG : provider=%s display_name=%s"
                provider_name
                oauth2_config.Sgs_config.oauth2_display_name);
          Logs.info (fun m ->
              m "OAUTH2_CALLBACK_URL : %s (register this URL with your OAuth provider)" callback_url);
          if not (Sgs_config.oauth_redirect_base_explicit config) then
            Logs.warn (fun m ->
                m
                  "OAUTH2_REDIRECT_BASE_DEFAULT : STATEGRAPH_OAUTH_REDIRECT_BASE is not set, \
                   defaulting to '%s' which will not work in production"
                  oauth_redirect_base);
          let open Abb.Future.Infix_monad in
          Abbs_fc.timeout
            ~timeout:(Abb.Sys.sleep setup_timeout)
            (Oauth2_htp.create
               (make_config ~group ~email_domains ~callback_url config oauth2_config))
          >>| function
          | `Ok (Ok authenticator) -> Ok { authenticator; provider_name }
          | `Ok (Error err) -> Error (err :> create_err)
          | `Timeout -> Error `Setup_timeout))

let authenticator t = t.authenticator
let provider_name t = t.provider_name

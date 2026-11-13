let src = Logs.Src.create "oauth2_htp"

module Logs = (val Logs.src_log src : Logs.LOG)
module Csrf = Oauth2_htp_csrf
module Request = Oauth2_htp_request
module Values = Oauth2_htp_values

type err =
  [ Oauth2_htp_oidc.err
  | Oauth2_htp_google.err
  | Oauth2_htp_github.err
  | Oauth2_htp_csrf.err
  | `Idp_error of string * string
  | `Invalid_state
  | `Missing_code
  | `Missing_csrf_cookie
  | `Csrf_token_mismatch
  | `Unauthorized
  ]
[@@deriving show]

module Config = struct
  type provider =
    | Google of { group : Oauth2_htp_google.Group.t option }
    | Github of {
        orgs : string Sln_list.Non_empty.t;
        endpoints : Oauth2_htp_github.Endpoints.t;
      }
    | Oidc of { issuer_url : string }

  type t = {
    provider : provider;
    client_id : string;
    client_secret : string;
    scope : string;
    login_params : (string * string) list;
    redirect_url : string;
    whitelist_domains : string list;
    email_domains : string list;
    cookie_secret : string;
    cookie_secure : bool;
  }

  let default_scope = function
    | Github _ -> Oauth2_htp_github.scope
    | Google _ | Oidc _ -> "openid email profile"

  let make
      ?scope
      ?(login_params = [])
      ~provider
      ~client_id
      ~client_secret
      ~redirect_url
      ~whitelist_domains
      ~email_domains
      ~cookie_secret
      ~cookie_secure
      () =
    {
      provider;
      client_id;
      client_secret;
      scope = CCOption.get_or ~default:(default_scope provider) scope;
      login_params;
      redirect_url;
      whitelist_domains;
      email_domains;
      cookie_secret;
      cookie_secure;
    }
end

module Start_result = struct
  type t = {
    login_url : string;
    set_cookies : Oauth2_htp_cookie.t list;
  }
end

module Callback_result = struct
  type t = {
    session : Oauth2_htp_session.t;
    redirect : string;
    set_cookies : Oauth2_htp_cookie.t list;
  }
end

type provider =
  | Google of Oauth2_htp_google.t
  | Github of Oauth2_htp_github.t
  | Oidc of Oauth2_htp_oidc.t

type t = {
  config : Config.t;
  provider : provider;
  email_validator : string -> bool;
}

let create config =
  let open Abbs_fc.Infix_result_monad in
  let { Config.client_id; client_secret; _ } = config in
  (match config.Config.provider with
    | Config.Google { group } ->
        let provider = Oauth2_htp_google.make ~client_id ~client_secret ~group () in
        let open Abb.Future.Infix_monad in
        Abb.Sys.time ()
        >>= fun now ->
        let open Abbs_fc.Infix_result_monad in
        Oauth2_htp_google.check_admin ~now provider >>| fun () -> Google provider
    | Config.Github { orgs; endpoints } ->
        Abb.Future.return
          (Ok (Github (Oauth2_htp_github.make ~client_id ~client_secret ~endpoints ~orgs)))
    | Config.Oidc { issuer_url } ->
        Oauth2_htp_oidc.discover ~issuer_url ~client_id ~client_secret
        >>| fun provider -> Oidc provider)
  >>| fun provider ->
  {
    config;
    provider;
    email_validator = Oauth2_htp_validator.create ~email_domains:config.Config.email_domains;
  }

(* The state parameter is the hashed CSRF nonce and the app redirect, joined by the first colon. *)
let encode_state ~nonce ~redirect = nonce ^ ":" ^ redirect
let decode_state state = CCOption.to_result `Invalid_state (CCString.Split.left ~by:":" state)

let login_url t ~state =
  let base =
    Uri.of_string
      (match t.provider with
      | Google provider -> Oauth2_htp_google.login_url provider
      | Github provider -> Oauth2_htp_github.login_url provider
      | Oidc provider -> Oauth2_htp_oidc.login_url provider)
  in
  let params =
    CCList.fold_left
      (fun params (k, v) -> Values.add k v params)
      (Uri.query base)
      (t.config.Config.login_params
      @ [
          ("redirect_uri", t.config.Config.redirect_url);
          ("scope", t.config.Config.scope);
          ("client_id", t.config.Config.client_id);
          ("response_type", "code");
          ("state", state);
        ])
  in
  (* Rebuilding through [Uri] would re-encode the query with RFC 3986 rules rather than the form
     encoding an IdP expects, so the encoded parameters are appended to the bare base. *)
  let base = Uri.to_string (Uri.with_query base []) in
  CCOption.get_or ~default:base (CCString.chop_suffix ~suf:"?" base) ^ "?" ^ Values.encode params

let safe_redirect t redirect =
  match
    Oauth2_htp_redirect.is_valid_redirect
      ~allowed_domains:t.config.Config.whitelist_domains
      redirect
  with
  | true -> redirect
  | false -> "/"

let oauth_start ~now t req =
  let csrf = Csrf.create () in
  let state =
    encode_state
      ~nonce:(Csrf.hashed_state csrf)
      ~redirect:(safe_redirect t (Request.form_value "rd" req))
  in
  Abb.Future.return
    (CCResult.map
       (fun cookie -> { Start_result.login_url = login_url t ~state; set_cookies = [ cookie ] })
       (Csrf.set_cookie
          ~now
          ~secret:t.config.Config.cookie_secret
          ~secure:t.config.Config.cookie_secure
          csrf))

let redeem ~now ~code t =
  let redirect_uri = t.config.Config.redirect_url in
  match t.provider with
  | Google provider -> Oauth2_htp_google.redeem ~now ~redirect_uri ~code provider
  | Github provider -> Oauth2_htp_github.redeem ~redirect_uri ~code provider
  | Oidc provider -> Oauth2_htp_oidc.redeem ~now ~redirect_uri ~code provider

let authorize t session =
  t.email_validator session.Oauth2_htp_session.email
  &&
  match t.provider with
  | Google provider -> Oauth2_htp_google.authorize provider session
  | Github provider -> Oauth2_htp_github.authorize provider session
  | Oidc _ -> true

let clear_cookies t = [ Csrf.clear ~secure:t.config.Config.cookie_secure ]

let oauth_callback ~now t req =
  let open Abbs_fc.Infix_result_monad in
  match Request.form_value "error" req with
  | error when not (CCString.is_empty error) ->
      let description = Request.form_value "error_description" req in
      Logs.err (fun m -> m "Error while parsing OAuth2 callback: %s: %s" error description);
      Abb.Future.return (Error (`Idp_error (error, description)))
  | _ -> (
      Abb.Future.return (decode_state (Request.form_value "state" req))
      >>= fun (nonce, app_redirect) ->
      (match Csrf.load ~now ~secret:t.config.Config.cookie_secret req with
        | Ok csrf -> Abb.Future.return (Ok csrf)
        | Error err ->
            Logs.err (fun m ->
                m
                  "Invalid authentication via OAuth2: unable to obtain CSRF cookie: %a"
                  Csrf.pp_err
                  err);
            Abb.Future.return (Error `Missing_csrf_cookie))
      >>= fun csrf ->
      (match Csrf.check_state csrf nonce with
        | true -> Abb.Future.return (Ok ())
        | false ->
            Logs.err (fun m ->
                m "Invalid authentication via OAuth2: CSRF token mismatch, potential attack");
            Abb.Future.return (Error `Csrf_token_mismatch))
      >>= fun () ->
      (match Request.form_value "code" req with
        | "" -> Abb.Future.return (Error `Missing_code)
        | code -> redeem ~now ~code t)
      >>= fun session ->
      match authorize t session with
      | true ->
          Logs.info (fun m ->
              m
                "Authenticated via OAuth2: email=%s user=%s groups=[%s]"
                session.Oauth2_htp_session.email
                session.Oauth2_htp_session.user
                (CCOption.map_or
                   ~default:"unknown"
                   (CCString.concat " ")
                   session.Oauth2_htp_session.groups));
          Abb.Future.return
            (Ok
               {
                 Callback_result.session;
                 redirect = safe_redirect t app_redirect;
                 set_cookies = clear_cookies t;
               })
      | false ->
          Logs.err (fun m ->
              m
                "Invalid authentication via OAuth2 for %s: unauthorized"
                session.Oauth2_htp_session.email);
          Abb.Future.return (Error `Unauthorized))

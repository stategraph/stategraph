(** OAuth2 sign-in for Google, GitHub and generic OIDC providers.

    The caller serves two endpoints and writes their responses: the start, which sends the browser
    to the provider, and the callback, which the provider redirects back to. A completed callback
    hands back who signed in; keeping them signed in is the caller's business.

    A CSRF cookie binds a sign-in's [state] to the browser that started it. The cookie is signed and
    encrypted with the cookie secret, so every server answering the same sign-in needs the same
    secret. *)

(** [`Idp_error (error, error_description)] is a callback the provider sent with an [error]. *)
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

module Config : sig
  type provider =
    | Google of { group : Oauth2_htp_google.Group.t option }
    | Github of {
        orgs : string Sln_list.Non_empty.t;
            (** A user may sign in when they are an active member of at least one of these orgs:
                [[ "acme"; "acme-labs" ]] admits a member of [acme], of [acme-labs], or of both. *)
        endpoints : Oauth2_htp_github.Endpoints.t;
      }
    | Oidc of { issuer_url : string }

  type t

  (** [redirect_url] is the absolute URL of the callback, as registered with the provider.
      [whitelist_domains] are the hosts, with an optional [:port] or [:*], a sign-in may return to
      by absolute URL. [email_domains] are the domains that may sign in, [*] for any. [login_params]
      are added to the provider's sign-in URL. [cookie_secret] is 16, 24 or 32 bytes, or their URL
      safe base64 encoding. [scope] defaults to [read:user user:email read:org] for GitHub and to
      [openid email profile] otherwise. *)
  val make :
    ?scope:string ->
    ?login_params:(string * string) list ->
    provider:provider ->
    client_id:string ->
    client_secret:string ->
    redirect_url:string ->
    whitelist_domains:string list ->
    email_domains:string list ->
    cookie_secret:string ->
    cookie_secure:bool ->
    unit ->
    t
end

module Start_result : sig
  type t = {
    login_url : string;  (** Where to send the browser. *)
    set_cookies : Oauth2_htp_cookie.t list;
  }
end

module Callback_result : sig
  type t = {
    session : Oauth2_htp_session.t;
    redirect : string;  (** The [rd] the sign-in started with, or ["/"] when it was not safe. *)
    set_cookies : Oauth2_htp_cookie.t list;  (** Expires the CSRF cookie. *)
  }
end

type t

(** Set up the provider. An OIDC provider is discovered here, and a Google group lookup's service
    account is checked against the Admin SDK. *)
val create : Config.t -> (t, [> err ]) result Abb.Future.t

(** Start a sign-in. The [rd] parameter of the request is where the callback returns to. *)
val oauth_start :
  now:float -> t -> Oauth2_htp_request.t -> (Start_result.t, [> err ]) result Abb.Future.t

(** Complete a sign-in: check the [state] against the CSRF cookie, redeem the [code], and check the
    user's email domain and, for Google with a group or for GitHub, their membership. *)
val oauth_callback :
  now:float -> t -> Oauth2_htp_request.t -> (Callback_result.t, [> err ]) result Abb.Future.t

(** Cookies that expire the CSRF cookie, for a response that ends a sign-in. *)
val clear_cookies : t -> Oauth2_htp_cookie.t list

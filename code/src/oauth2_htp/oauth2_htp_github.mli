(** Sign-in with GitHub. GitHub sign-in is OAuth2 without OIDC: it issues no ID token, so the user
    is read from the GitHub API with the access token. *)

type err =
  [ Oauth2_htp_requests.err
  | `Provider_err of string
  | `Unverified_email of string
  ]
[@@deriving show]

(** The scopes a sign-in asks for: [read:user user:email read:org]. *)
val scope : string

(** The GitHub hosts the provider calls: for GitHub itself [https://github.com] and
    [https://api.github.com], for a GitHub Enterprise Server [https://<host>] and
    [https://<host>/api/v3]. *)
module Endpoints : sig
  type t = {
    web_base : string;  (** Serves the sign-in page and the token endpoint. *)
    api_base : string;  (** Serves the REST API. *)
  }
end

type t

(** Only the members of one of [orgs] may sign in. *)
val make :
  client_id:string ->
  client_secret:string ->
  endpoints:Endpoints.t ->
  orgs:string Sln_list.Non_empty.t ->
  t

(** The authorization endpoint. *)
val login_url : t -> string

(** Exchange the authorization [code] for an access token and read the user with it. The session's
    [user] is GitHub's numeric user id, and its [avatar_url] the user's avatar. Its [email] is the
    primary email, which must be verified. Its [groups] are the logins of the organizations the user
    is an active member of, or [None] when they cannot be read. *)
val redeem :
  redirect_uri:string -> code:string -> t -> (Oauth2_htp_session.t, [> err ]) result Abb.Future.t

(** Whether the session may sign in: only an active member of one of the orgs. Logins are compared
    without case, as GitHub does. *)
val authorize : t -> Oauth2_htp_session.t -> bool

(** Sign-in with Google. *)

type err =
  [ Oauth2_htp_requests.err
  | `Provider_err of string
  | `Unverified_email of string
  ]
[@@deriving show]

(** Read the user's Google groups from the Admin SDK, with a service account that impersonates
    [admin_email] through domain-wide delegation. With [groups], sign-in is restricted to their
    members. Without, anyone may sign in and the session carries every group the user is in. *)
module Group : sig
  type t = {
    groups : string list;
    admin_email : string;
    service_account_json : string;  (** The service account's JSON key. *)
  }
end

(** The Google endpoints the provider calls. *)
module Endpoints : sig
  type t = {
    login_url : string;
    token_url : string;  (** Redeems the authorization code. *)
    admin_token_url : string;  (** Exchanges the service account's assertion for a token. *)
    admin_directory_url : string;  (** The Admin SDK Directory API. *)
  }

  (** Google's own. *)
  val default : t
end

type t

(** [endpoints] defaults to {!Endpoints.default}. *)
val make :
  ?endpoints:Endpoints.t ->
  client_id:string ->
  client_secret:string ->
  group:Group.t option ->
  unit ->
  t

(** The authorization endpoint. *)
val login_url : t -> string

(** With a group lookup, whether the service account key works and is granted one of the Admin SDK
    group scopes. *)
val check_admin : now:float -> t -> (unit, [> err ]) result Abb.Future.t

(** Exchange the authorization [code] for the user's identity, read from the ID token in Google's
    token response. The email must be verified. With groups configured, the session's groups are
    those of them the user is a member of. With a group lookup but no groups configured, they are
    every group the user is in, or [None] when the lookup fails. *)
val redeem :
  now:float ->
  redirect_uri:string ->
  code:string ->
  t ->
  (Oauth2_htp_session.t, [> err ]) result Abb.Future.t

(** Whether the session may sign in: with groups configured, only a member of one of them. *)
val authorize : t -> Oauth2_htp_session.t -> bool

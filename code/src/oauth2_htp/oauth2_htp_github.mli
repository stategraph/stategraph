(** Sign-in with GitHub. GitHub sign-in is OAuth2 without OIDC: it issues no ID token, so the user
    is read from the GitHub API with the access token. *)

type err =
  [ Oauth2_htp_requests.err
  | `Provider_err of string
  | `Unverified_email of string
  ]
[@@deriving show]

(** The scopes a sign-in asks for. *)
val scope : string list

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

(** Only the members of one of [authorized_orgs] may sign in. Only the teams of [authorized_orgs],
    with their ancestors, are groups; every organization of the user is a group, whether it is in
    [authorized_orgs] or not. *)
val make :
  client_id:string ->
  client_secret:string ->
  endpoints:Endpoints.t ->
  authorized_orgs:string Sln_list.Non_empty.t ->
  t

(** The authorization endpoint. *)
val login_url : t -> string

(** The organizations and teams of a GitHub user, with the names GitHub gives them. Logins are
    spelled as GitHub spells them. *)
module Groups : sig
  module Team : sig
    type t
  end

  type t = {
    organizations : string list;
        (** The login of each organization the user is an active member of. *)
    teams : Team.t list;
        (** Each team the user is a member of in one of the authorized organizations, and each
            ancestor of that team, because GitHub counts the members of a child team as members of
            its parent. *)
  }

  (** The groups that group rules are evaluated against: [github:<org>] for each organization, then
      [github:<org>/<slug>] for each team. The [github:] prefix tells a GitHub group from the groups
      of another provider in a group rule. *)
  val to_github_prefixed_list : t -> string list
end

(** The {!Groups} of the user of [access_token], with the teams of [authorized_orgs] only.
    [authorized_orgs] is compared with the logins without case. For example, with [authorized_orgs]
    [acme], a member of [Acme] and [Other], in the team [platform-infra] of [Acme] whose parent is
    [platform], and in the team [ops] of [Other]:

    {v
      organizations  Acme, Other
      teams          { org = Acme; slug = platform }, { org = Acme; slug = platform-infra }
    v}

    and {!Groups.to_github_prefixed_list} gives

    [github:Acme github:Other github:Acme/platform github:Acme/platform-infra].

    [Error] when the organizations cannot be read. If the organizations can be read, but not the
    teams or one of their ancestors, the function logs the error and behaves as if the user belonged
    to no team: [teams] is empty. [user] is for logging only. *)
val groups :
  access_token:string ->
  api_base:string ->
  authorized_orgs:string Sln_list.Non_empty.t ->
  user:string ->
  (Groups.t, [> err ]) result Abb.Future.t

(** Who signed in with GitHub, before {!authorize} admits them. *)
module Redeemed : sig
  type t = {
    user : string;  (** GitHub's numeric user id. *)
    email : string;  (** The primary email, which is verified. *)
    groups : Groups.t option;
        (** {!groups} with the authorized orgs of [t], or [None] when the organizations cannot be
            read. *)
    avatar_url : string option;
    access_token : string;
  }
end

(** Exchange the authorization [code] for an access token and read the user with it. *)
val redeem : redirect_uri:string -> code:string -> t -> (Redeemed.t, [> err ]) result Abb.Future.t

(** Whether the user may sign in: only an active member of one of the authorized orgs of [t]. Only
    the organizations of the groups count, and they are compared with the authorized orgs without
    case, as GitHub does. *)
val authorize : t -> Redeemed.t -> bool

(** The session of a sign-in. Its [groups] are {!Groups.to_github_prefixed_list} of the groups. *)
val session : Redeemed.t -> Oauth2_htp_session.t

module Tests : sig
  (** [team ~org ~slug] is the team [slug] of the organization [org]. *)
  val team : org:string -> slug:string -> Groups.Team.t
end

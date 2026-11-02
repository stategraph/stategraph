(** The OAuth2 provider in {!Sgs_config.oauth2}, set up with {!Oauth2_htp}. Sign-in mints a
    Stategraph session, so the flow keeps no session of its own. *)

type t

type create_err =
  [ `No_oauth_config
  | `Invalid_config of string
  | `Setup_timeout
  | Oauth2_htp.err
  ]
[@@deriving show]

(** Build the authenticator for the configured provider. Returns [Error `No_oauth_config] if OAuth
    is not configured. An OIDC provider is discovered here, so an unreachable issuer fails the
    create. A Google service account key given as a path is read here and checked against the Admin
    SDK. Setup that takes longer than ten seconds fails with [`Setup_timeout].
    [STATEGRAPH_OAUTH_EMAIL_DOMAIN] and [STATEGRAPH_OAUTH_GOOGLE_GROUP] are comma-separated lists.
*)
val create : Sgs_config.t -> (t, create_err) result Abb.Future.t

val authenticator : t -> Oauth2_htp.t

(** The configured provider's machine-readable name, which is also the [auth_origin] of the users it
    signs in. *)
val provider_name : t -> string

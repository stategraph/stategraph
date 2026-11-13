(** Sign-in with an OIDC provider: discovery, ID token verification, and the session built from the
    token's claims. *)

type err =
  [ Oauth2_htp_requests.err
  | `Issuer_mismatch of string * string
  | `Jwks_err
  | `Missing_id_token
  | `Malformed_token
  | `Token_expired of float
  | `Token_not_yet_valid of float
  | `Unsupported_signing_alg of string
  | `No_supported_signing_alg of string list
  | `Unknown_key_id of string
  | `Signature_verification_failed
  | `Invalid_audience of string list
  | `Unverified_email of string
  | `Missing_email
  | `Missing_access_token
  | `Invalid_discovery of string
  | `Missing_claim of string
  | `Invalid_claim of string
  ]
[@@deriving show]

type t

(** Read [<issuer_url>/.well-known/openid-configuration]. Its [issuer] must equal [issuer_url]
    exactly, trailing slash included. It must name the authorization, token and JWKS endpoints, and
    may name a userinfo endpoint. When it lists ID token signing algorithms, one of them must be
    supported: RS256, RS384, RS512, ES256, ES384, ES512, PS256, PS384, PS512 or EdDSA. A document of
    another shape is [`Invalid_discovery reason]. *)
val discover :
  issuer_url:string -> client_id:string -> client_secret:string -> (t, [> err ]) result Abb.Future.t

(** The authorization endpoint. *)
val login_url : t -> string

(** Exchange the authorization [code] at the token endpoint and build the session from the verified
    ID token. The client authenticates with HTTP Basic and, when that fails, with its credentials in
    the form. The token response must have an ID token and an access token. A claim the ID token
    lacks, or has as [null], is read from the userinfo endpoint. The session needs a [sub], a string
    or a number, and an email. The email must be verified unless [email_verified] is absent;
    [email_verified] is a boolean or the string ["true"] or ["false"]. [groups], when present, is a
    string or an array of strings. A claim of another shape is [`Invalid_claim claim]. *)
val redeem :
  now:float ->
  redirect_uri:string ->
  code:string ->
  t ->
  (Oauth2_htp_session.t, [> err ]) result Abb.Future.t

(** Check an ID token: its [alg] is one the provider lists, or RS256 when it lists none; its
    signature is by the key of the provider's JWKS that its [kid] names, or by any key when it names
    none; its issuer; that its [aud], a string or an array of strings, includes the client id; that
    it has an [exp] and has not expired; and that its [nbf], when present, is at most five minutes
    ahead. A missing claim is [`Missing_claim claim], and a claim of another shape
    [`Invalid_claim claim]. Returns its claims. *)
val verify : now:float -> t -> Jwt.decoded Jwt.t -> (Yojson.Safe.t, [> err ]) result Abb.Future.t

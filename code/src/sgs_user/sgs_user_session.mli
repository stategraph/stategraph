module Session : sig
  module Expiration : sig
    (** A user token is expired either after an amount of time from when it was created OR it is
        tied to an access token that lives in the database and expires when that token goes away. *)
    type t =
      | Duration of {
          duration : Duration.t;
          capabilities : Sg_caps.t;
        }
      | Access_token of Uuidm.t
    [@@deriving show]
  end

  (** A session token can include metadata to be passed around with it. This way extra data can be
      included in the session without it needing to be stored in the DB *)
  module Metadata : sig
    type t = Yojson.Safe.t
  end

  (** A [minted] session has just been created in memory: it carries a minted user and no resolved
      capabilities. *)
  type minted [@@deriving show]

  (** A [stored] session has been reified against the database: it carries a stored (enriched) user
      and a fully-resolved (non-optional) set of capabilities. *)
  type stored [@@deriving show]

  type 'a t [@@deriving show]

  type of_token_err =
    [ `User_not_found_err of Uuidm.t
    | `Decode_err
    | `Data_decode_err of string
    | `Expired_token_err of string
      (** It should be hard to use an expired token, so return it as an error but the decoded token
          is available in case there is a use for it. *)
    | Sgs_user_access_token.query_err
    | Pgsql_io.err
    ]
  [@@deriving show]

  type fetch_key_err =
    [ `Key_not_found_err
    | `Bad_signing_key_err of string
    | Pgsql_io.err
    ]
  [@@deriving show]

  type enrich_err =
    [ `User_not_found_err of Uuidm.t
    | Sgs_user_access_token.query_err
    | Pgsql_io.err
    ]
  [@@deriving show]

  (** Create a session. A [Duration] expiration is capped at ten minutes: a [Duration] session lives
      only in its JWT, so it cannot be revoked before it expires, and anything longer-lived must be
      DB-backed ({!create_login}, {!Sgs_user_access_token}) so deleting the row revokes it. *)
  val create :
    ?metadata:Metadata.t -> expiration:Expiration.t -> Sgs_user.minted Sgs_user.t -> minted t

  (** Create a browser sign-in session: persists an [access_tokens] row of kind ['login'] carrying
      the capability snapshot and a 24 hour expiration, and returns a session whose token references
      that row. Deleting the row revokes the session — capability changes do exactly that
      ({!Sgs_user.revoke_login_sessions}), forcing a fresh sign-in. Also sweeps already-expired
      login rows. *)
  val create_login :
    ?metadata:Metadata.t ->
    capabilities:Sg_caps.t ->
    Sgs_user.minted Sgs_user.t ->
    Pgsql_io.t ->
    (minted t, [> Sgs_user_access_token.store_err ]) result Abb.Future.t

  val user : stored t -> Sgs_user.stored Sgs_user.t
  val expiration : 'a t -> Expiration.t
  val metadata : 'a t -> Metadata.t option
  val capabilities : stored t -> Sg_caps.t

  (** Signing material for session JWTs: the RSA key that mints, every public half that still
      verifies, and the pre-RS256 HMAC keys. Obtained from {!fetch_key}. *)
  module Keys : sig
    type t

    (** [signer t] is RS256 under the RSA key that mints session JWTs. A token it signs is as hard
        to forge as a session, and only its payload tells it apart from one: such a token must hold
        its payload under a claim that no session JWT holds. *)
    val signer : t -> Jwt.Signer.t

    (** [rs256_verifiers t] is one RS256 verifier per RSA row of [encryption_keys], the signing key
        first, so a token signed by a key that no longer signs still verifies while its row remains.
        The legacy HMAC keys are left out. *)
    val rs256_verifiers : t -> Jwt.Verifier.t list
  end

  (** [sign_token ~signer payload] is [payload] signed by [signer], as a compact JWT. *)
  val sign_token : signer:Jwt.Signer.t -> Jwt.Payload.t -> string

  (** [verify_token ~verifiers token] is the payload of [token] once one of [verifiers] accepts its
      signature: [`Malformed_err] when [token] does not decode as a JWT, [`Bad_signature_err] when
      no verifier accepts it. It checks no claim, [exp] included. *)
  val verify_token :
    verifiers:Jwt.Verifier.t list ->
    string ->
    (Jwt.Payload.t, [> `Malformed_err | `Bad_signature_err ]) result

  val of_token :
    keys:Keys.t -> Pgsql_io.t -> string -> (stored t, [> of_token_err ]) result Abb.Future.t

  (** Construct a token given t and how expiration. By default it is 60 seconds *)
  val to_token : key:Keys.t -> 'a t -> string Abb.Future.t

  (** Enrich a minted session into a stored one: enrich its user from the database and resolve its
      capabilities (from the JWT-carried capabilities for a [Duration] expiration, from the access
      token row for an [Access_token] expiration). *)
  val enrich : minted t -> Pgsql_io.t -> (stored t, [> enrich_err ]) result Abb.Future.t

  (** The signing material for session JWTs. Generates and stores the RSA row of [encryption_keys]
      on the first call after the migration that added the [type] column; every later call reads it.
  *)
  val fetch_key : Pgsql_io.t -> (Keys.t, [> fetch_key_err ]) result Abb.Future.t
end

val create : secure_cookies:bool -> Sgs_storage.t -> Brtl_mw.Mw.t Abb.Future.t
val set : Session.stored Session.t -> ('a, 'b) Brtl_ctx.t -> ('a, 'b) Brtl_ctx.t

val rem :
  ('a, 'b) Brtl_ctx.t ->
  Pgsql_io.t ->
  (('a, 'b) Brtl_ctx.t, [> Pgsql_pool.err | Pgsql_io.err ]) result Abb.Future.t

(** Helpers for building the [~caps] predicate passed to {!with_user} / {!with_session}. *)
module Caps : sig
  (** One reason a [~caps] predicate denied a request. [kind] mirrors the generated
      {!Sgs_capability_denied_reason_capability.Kind.t}. *)
  type denial_reason = {
    kind : Sgs_capability_denied_reason_capability.Kind.t;
    detail : string;
  }

  (** The outcome of evaluating a [~caps] predicate: [Allowed], or [Denied] with every unmet
      requirement. *)
  type result =
    | Allowed
    | Denied of denial_reason list

  (** A [~caps] predicate receives the session-resolved capabilities and the acting user, so that
      capability checks ({!satisfies}) and identity checks ({!is_user}) can be composed with {!or_}.
      It returns [Allowed], or [Denied] with the reasons the request was refused. *)
  type t = Sg_caps.t -> Sgs_user.stored Sgs_user.t -> result

  (** [is_allowed result] is [true] iff [result] is [Allowed]. *)
  val is_allowed : result -> bool

  (** [satisfies required] is a predicate that is [Allowed] when the session's resolved capabilities
      allow everything [required] allows. *)
  val satisfies : Sg_caps.t -> t

  (** Administrative authority over the whole installation: requiring [admin] without naming a
      tenant asks for every tenant, which only installation-wide admin satisfies. *)
  val admin_instance : t

  (** An unscoped [admin] grant, or an unscoped [users-manage] grant: authority over the users of
      the whole installation, rather than the members of one tenant. Compose with {!is_user} via
      {!or_} where a user may also reach its own record.

      Both alternatives name no tenant, so only an unrestricted grant satisfies either. See
      {!users_manage_tenant} for the narrower, tenant-scoped counterpart. *)
  val users_manage_instance : t

  (** [admin_tenant tenant_id] is administrative authority over that one tenant. An
      installation-wide grant satisfies it too, since it permits every tenant. *)
  val admin_tenant : string -> t

  (** Holds an admin grant, whatever its scope: an empty required tenants list names no tenant, so
      any grant satisfies it while a session with no admin grant is still denied. For endpoints
      whose tenant is only known after a database lookup — this gate proves the session administers
      something, and the query does the tenant match. *)
  val admin_some : t

  (** Holds authority over users somewhere: an [admin] or a [users-manage] grant, of any scope. The
      empty required tenants list names no tenant, so any grant satisfies it while a session with
      neither is denied.

      A coarse pre-filter, not a decision. Which users such a session may act on depends on what
      those users hold and which tenants they belong to, both of which take a database read (which
      can be done using {!users_manage_tenant}, once you know the concerned tenant). *)
  val users_manage_some : t

  (** [users_manage_tenant tenant_id] is authority over that one tenant's membership — listing,
      adding, removing and promoting its members, but not renaming it or reaching its
      infrastructure. An unscoped grant satisfies it too. *)
  val users_manage_tenant : string -> t

  (** [manages_tenant_members tenant_id] is the gate for changing members to the tenant. It is
      granted by administering the tenant, or holding [users-manage] scoped to it. *)
  val manages_tenant_members : string -> t

  (** Always [Allowed]: a [~caps] predicate that imposes no requirement. *)
  val allow_all : t

  (** [is_user user_id] is [Allowed] when the acting user's id equals [user_id]; otherwise [Denied]
      with an [`Identity] reason. *)
  val is_user : Uuidm.t -> t

  (** [or_ p q] is a [~caps] predicate [Allowed] when either [p] or [q] is. When both deny, the
      result accumulates (deduped) the reasons of both branches. *)
  val or_ : t -> t -> t

  (** [denied_body reasons] is the [CAPABILITY_UNAUTHORIZED] response body {!with_session} returns
      on denial. Exposed for endpoints whose check needs a database lookup and so cannot live in the
      [~caps] predicate — they deny in the same shape. *)
  val denied_body : denial_reason list -> string
end

val with_user :
  caps:Caps.t ->
  f:
    (Sgs_user.stored Sgs_user.t ->
    (string, 'a) Brtl_ctx.t ->
    (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t) ->
  (string, 'a) Brtl_ctx.t ->
  (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t

val with_session :
  caps:Caps.t ->
  f:
    (Session.stored Session.t ->
    (string, 'a) Brtl_ctx.t ->
    (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t) ->
  (string, 'a) Brtl_ctx.t ->
  (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t

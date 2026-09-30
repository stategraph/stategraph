(** Responses shared by the GitHub claim endpoints (#1795). *)

(** The session signing keys and the GitHub App's OAuth client, on one connection. Resolving the
    client here is what keeps a console-created App working, so no endpoint reads the configuration
    on its own. *)
val keys_and_oauth :
  Sgs_config.t ->
  Pgsql_io.t ->
  ( Sgs_user_session.Session.Keys.t * Sgs_config.github_oauth option,
    [> Sgs_user_session.Session.fetch_key_err | Pgsql_io.err ] )
  result
  Abb.Future.t

(** Log why the handshake cannot run: [ORCHESTRATION_UNAVAILABLE] or
    [GITHUB_CLAIM_OAUTH_NOT_CONFIGURED]. [src] defaults to this module's; prefer passing the
    endpoint's own. *)
val log_unavailable :
  ?src:Logs.src ->
  ('a, 'b) Brtl_ctx.t ->
  [< `Orchestration_disabled | `Oauth_not_configured ] ->
  unit

(** The failures of reading a caller's proof: the membership check, the session keys that verify the
    proof, and the proof itself. *)
type proof_access_err =
  [ Sgs_service_orchestration_github_claim_proof.err
  | `Key_not_found_err
  | `Bad_signing_key_err of string
  | Sgs_eplib.tenant_access_err
  ]

(** Answer, and log, a {!proof_access_err}:
    - [412] [GITHUB_PROOF_REQUIRED] when the proof cookie is absent, expired, or not this user's for
      this tenant. The caller must complete the GitHub handshake first, which is neither a
      permission problem nor a bad request, so the console offers the handshake again instead of an
      error.
    - As {!Sgs_eplib.respond_signing_key_err} and {!Sgs_eplib.respond_tenant_access_err} for the
      other failures.

    [src] is the log source of the [412], and it defaults to this module's; prefer passing the
    endpoint's own. *)
val respond_proof_access_err :
  ?src:Logs.src -> ('a, 'b) Brtl_ctx.t -> proof_access_err -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Where the console is returned to when no destination was given, or the given one failed
    {!Sgs_redirect.url}. *)
val default_redirect : string

(** [redirect_target ~config ctx rd] is [rd] when {!Sgs_redirect.url} accepts it for the console's
    [ui_base], and {!default_redirect} for [None] or for a target it rejects, which is logged as
    [UNSAFE_REDIRECT]. *)
val redirect_target : config:Sgs_config.t -> ('a, 'b) Brtl_ctx.t -> string option -> string

(** The [github_claim] query parameter start and the callback send the console back with. *)
type redirect_result =
  [ `Ready
  | `Installed
  | `No_admin
  | `Forbidden
  | `Expired
  | `Error
  | `Unavailable
  | `Not_member
  ]

(** Redirect the browser to [rd], or to {!default_redirect} for [None], with [github_claim] set to
    [result]; with [proof], also set the HttpOnly, [SameSite=Strict] proof cookie the claim
    endpoints read. [rd] is checked with {!Sgs_redirect.url} again, since this is where the
    [Location] header is written: a target that fails is logged as [UNSAFE_REDIRECT] and replaced by
    {!default_redirect}.

    For the endpoints the browser reaches by full-page navigation, where an API error would be
    rendered as a raw page. *)
val redirect_with :
  ?proof:string ->
  config:Sgs_config.t ->
  rd:string option ->
  result:redirect_result ->
  ('a, 'b) Brtl_ctx.t ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t

(** The internal failures a caller can do nothing about: the session signing keys cannot be read, or
    the database failed. *)
type fault_err =
  [ `Key_not_found_err
  | `Bad_signing_key_err of string
  | Pgsql_io.err
  | Pgsql_pool.err
  ]

(** Log a {!fault_err} with the line {!Sgs_eplib.respond_signing_key_err} or
    {!Sgs_eplib.respond_db_err} writes, then {!redirect_with} [~result:`Error]. [src] is the log
    source of a database fault, and it defaults to {!Sgs_eplib}'s; prefer passing the endpoint's
    own. *)
val redirect_fault :
  ?src:Logs.src ->
  config:Sgs_config.t ->
  rd:string option ->
  ('a, 'b) Brtl_ctx.t ->
  [< fault_err ] ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t

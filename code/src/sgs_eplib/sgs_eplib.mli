(** The error answers, and their log lines, that endpoints share whatever they do. *)

(** JSON body of an [error-response] with the given [id] and [data]. *)
val error_response_body : id:string -> data:string -> string

(** Answer with an [error-response] body under [status]: [id] is the machine-readable error id the
    API conventions call for, [data] the human-readable detail. The neutral counterpart of the
    per-family [respond_error]s, for endpoints that do not belong to one of those families. *)
val respond_error :
  status:Cohttp.Code.status_code ->
  id:string ->
  data:string ->
  ('a, 'b) Brtl_ctx.t ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [500], by default with an empty body: an internal fault usually gives the caller nothing
    to act on, so the detail belongs in the logs. Log at the call site, then respond with this.

    [body] is for the endpoints that do have something to say — pass {!error_response_body} to send
    the [error-response] the API conventions describe, and make sure [api.json] declares it. *)
val respond_internal_error : ?body:string -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer, and log, a database fault as [500]. What an endpoint should call directly when it allows
    to keep the [Pgsql_io]/[Pgsql_pool] arms disjoints from other arms.

    [body] is the [500] body, for an endpoint whose schema declares one; it defaults to empty, as
    {!respond_internal_error} does.

    [src] is the log source the fault is reported under, and it defaults to this module's [src].
    Prefer passing the endpoint's own [src]. *)
val respond_db_err :
  ?src:Logs.src ->
  ?body:string ->
  ('a, 'b) Brtl_ctx.t ->
  [< Pgsql_io.err | Pgsql_pool.err ] ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Log a database fault with the line {!respond_db_err} writes, without answering: for an endpoint
    that answers the fault some other way, such as a redirect back to the console. [src] defaults to
    this module's [src]; prefer passing the endpoint's own. *)
val log_db_err : ?src:Logs.src -> ('a, 'b) Brtl_ctx.t -> [< Pgsql_io.err | Pgsql_pool.err ] -> unit

(** Answer, and log, a failure to read the session signing material: [500] either way, since neither
    is anything the caller can act on. Every endpoint that mints a session fails these same two
    ways, so sharing them is what keeps the status, the id and the log line from drifting apart.

    The two are logged apart because they are different operator problems: [`Key_not_found_err] is
    an [encryption_keys] with no [rsa] row, [`Bad_signing_key_err] a row that is not a usable RSA
    private key.

    Name the two constructors at the call site rather than matching
    [#Sgs_user_session.Session.fetch_key_err]: that union also subsumes [Pgsql_io.err], so the wider
    pattern would report a deadlock or a statement timeout as a missing key.

    [body] is the [500] body, for an endpoint whose schema declares one; it defaults to empty, as
    {!respond_internal_error} does. *)
val respond_signing_key_err :
  ?body:string ->
  ('a, 'b) Brtl_ctx.t ->
  [< `Key_not_found_err | `Bad_signing_key_err of string ] ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Log a failure to read the session signing material with the lines {!respond_signing_key_err}
    writes, without answering: for an endpoint that answers it some other way, such as a redirect.
*)
val log_signing_key_err :
  ('a, 'b) Brtl_ctx.t -> [< `Key_not_found_err | `Bad_signing_key_err of string ] -> unit

(** The two failures every tenant-scoped endpoint answers identically, whatever it was trying to do:
    a caller who is not a member of the tenant, and a database fault. The two are unrelated as
    failures ([403] and [500]) and are grouped only because no endpoint has anything of its own to
    say about either. [Sgs_tenant.enforce_user_err] already subsumes [Pgsql_io.err], so only the
    pool error has to be added. *)
type tenant_access_err =
  [ Sgs_tenant.enforce_user_err
  | Pgsql_pool.err
  ]

(** Answer, and log, a {!tenant_access_err}: [403] [TENANT_MEMBERSHIP_REQUIRED] for a caller who
    holds the capability but is not a member of the tenant, [500] for a database fault. The 403 is
    distinct from the [401] a missing session produces, so the console can tell "you don't belong to
    this tenant" from "sign in again" -- it retries a 401 and then sends the user to sign in, which
    is wrong when the session is perfectly good.

    Logging lives here rather than at the call site because the line is identical at every one.

    Use this rather than matching [#Sgs_tenant.enforce_user_err] and [#Pgsql_pool.err] as separate
    arms: that first pattern subsumes [Pgsql_io.err], so a hand-written pair answers a deadlock or a
    statement timeout as a denial. *)
val respond_tenant_access_err :
  ('a, 'b) Brtl_ctx.t -> tenant_access_err -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Log a caller who is not a member of the tenant with the [ACCESS_DENIED] line
    {!respond_tenant_access_err} writes, without answering: for an endpoint that answers the refusal
    some other way, such as a redirect. *)
val log_tenant_access_denied :
  ('a, 'b) Brtl_ctx.t -> [< `User_not_in_tenant_err of Uuidm.t * Uuidm.t ] -> unit

(** The cursor a keyset-paged listing hands its client, opaque to that client, which only echoes it
    back. It carries the last row of the page as the [(timestamp, id)] pair the query orders and
    pages by.

    Both halves are needed. Rows created in the same instant share a timestamp -- a bulk import, or
    any two inserts inside one transaction -- so a timestamp-only cursor drops every row holding the
    one a page boundary lands on, silently: the pages still look well-formed and the total still
    counts the rows never handed out. The pair is unique because the id is a primary key, so every
    row falls on exactly one side of every boundary. *)
module Cursor : sig
  (** [encode ~timestamp ~id] renders the pair as ["<timestamp>|<id>"]. Neither half can contain the
      separator: the timestamp is this codebase's rendered ISO 8601 and the id a UUID. *)
  val encode : timestamp:string -> id:Uuidm.t -> string

  (** Inverse of {!encode}. [None] for anything malformed, which callers turn into "start from the
      first page" rather than an error -- the cursor is the client's to lose. *)
  val decode : string -> (string * Uuidm.t) option
end

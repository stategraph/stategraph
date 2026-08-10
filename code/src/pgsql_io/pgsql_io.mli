(** A connection to the database *)
type t

exception Nested_tx_not_supported

module Io : sig
  type err = [ `Parse_error of Pgsql_codec.Decode.err ] [@@deriving show]
end

type frame_err =
  [ `Unmatching_frame of Pgsql_codec.Frame.Backend.t list
  | Io.err
  | `Disconnected
  ]
[@@deriving show]

type integrity_err = {
  code : string;
  message : string;
  detail : string option;
  constraint_name : string option;
  table_name : string option;
  schema_name : string option;
  column_name : string option;
}
[@@deriving show]

type pgsql_err = {
  code : string;
  message : string;
  detail : string option;
  hint : string option;
}
[@@deriving show]

type sql_parse_err =
  [ `Empty_variable_name
  | `Unclosed_quote of string
  | `Unknown_variable of string
  ]
[@@deriving show]

type err =
  [ `Pgsql_err of pgsql_err
  | frame_err
  | `Disconnected
  | `Bad_result of string option list
  | `Integrity_err of integrity_err
  | `Unique_violation_err of integrity_err
  | `Foreign_key_err of integrity_err
  | `Deadlock_detected of pgsql_err
  | `Lock_timeout of pgsql_err
  | `Statement_timeout
  | `Syntax_err of pgsql_err
  | sql_parse_err
  ]
[@@deriving show]

module Typed_sql : sig
  module Var : sig
    type 'a t

    (** Little wrapper type to include the name *)
    type 'a v = string -> 'a t

    (** Numeric types *)
    val smallint : int v

    val integer : int32 v
    val bigint : int64 v
    val decimal : Z.t v
    val numeric : Z.t v
    val real : float v
    val double : float v
    val smallserial : int v
    val serial : int32 v
    val bigserial : int64 v

    (** Monetary *)
    val money : int64 v

    (** Text types *)
    val text : string v

    val varchar : string v
    val char : string v
    val bytea : string v
    val tsquery : string v
    val uuid : Uuidm.t v
    val json : Yojson.Safe.t v
    val jsonpath : string v

    (** Boolean types *)
    val boolean : bool v

    val date : string v
    val time : string v
    val timetz : string v
    val timestamp : string v
    val timestamptz : string v
    val ud : 'b t -> ('a -> 'b) -> 'a t
    val option : 'a t -> 'a option t

    (** Type for any array that is NOT a string. Strings require a special representation that this
        does not account for. *)
    val array : 'a t -> 'a list t

    (** Any kind of string array. *)
    val str_array : 'a t -> 'a list t
  end

  module Ret : sig
    type 'a t

    val smallint : int t
    val integer : int32 t
    val bigint : int64 t
    val decimal : Z.t t
    val numeric : Z.t t
    val real : float t
    val double : float t
    val smallserial : int t
    val serial : int32 t
    val bigserial : int64 t
    val money : int64 t
    val text : string t
    val varchar : string t
    val char : string t
    val bytea : string t
    val json : Yojson.Safe.t t
    val jsonb : Yojson.Safe.t t
    val uuid : Uuidm.t t
    val boolean : bool t

    (** Binary-format variants. These use PostgreSQL binary wire format for decoding. They are more
        efficient but less forgiving: using the wrong type (e.g. [smallint_b] on an INTEGER column)
        will cause a runtime parse failure. Prefer the text-format versions above unless you need
        binary format for performance and can guarantee type correctness. *)
    val smallint_b : int t

    val integer_b : int32 t
    val bigint_b : int64 t
    val real_b : float t
    val double_b : float t
    val smallserial_b : int t
    val serial_b : int32 t
    val bigserial_b : int64 t
    val money_b : int64 t
    val boolean_b : bool t
    val varchar_b : string t
    val char_b : string t
    val u : 'a t -> ('a -> 'b option) -> 'b t

    val ud : (string option list -> ('a * string option list) option) -> 'a t
    [@@ocaml.deprecated "Use u instead"]

    val ud' : (string -> 'a option) -> 'a t [@@ocaml.deprecated "Use u instead"]
    val option : 'a t -> 'a option t
    val debug : (string option list -> unit) -> 'a t -> 'a t
  end

  type ('q, 'qr, 'p, 'pr) t

  val sql : ('qr, 'qr, 'pr, 'pr) t
  val ( /^ ) : ('q, 'qr, 'p, 'pr) t -> string -> ('q, 'qr, 'p, 'pr) t

  (** Concatenate the right query to the left. *)
  val ( /^^ ) : ('q, 'qr, 'p, 'pr) t -> ('qr, 'qqr, 'pr, 'ppr) t -> ('q, 'qqr, 'p, 'ppr) t

  val ( /% ) : ('q, 'a -> 'qr, 'p, 'pr) t -> 'a Var.t -> ('q, 'qr, 'p, 'pr) t
  val ( // ) : ('q, 'qr, 'p, 'a -> 'pr) t -> 'a Ret.t -> ('q, 'qr, 'p, 'pr) t
  val to_query : ('q, 'qr, 'p, 'pr) t -> (string, sql_parse_err) result
  val kbind : (string option list -> 'qr) -> ('q, 'qr, 'p, 'pr) t -> 'q
end

module Row_func : sig
  type ('f, 'fr, 'acc, 'r) t

  val make :
    ('q, 'qr, 'p, 'pr) Typed_sql.t ->
    init:'acc ->
    f:('acc -> 'p) ->
    post_f:('acc -> 'pr -> 'acc) ->
    fin:('acc -> 'r) ->
    ('p, 'pr, 'acc, 'r) t

  val ignore : ('q, 'qr, unit, unit) Typed_sql.t -> (unit, unit, unit, unit) t
  val fold : ('q, 'qr, 'p, 'r) Typed_sql.t -> init:'r -> f:('r -> 'p) -> ('p, 'r, 'r, 'r) t
  val map : ('q, 'qr, 'p, 'r) Typed_sql.t -> f:'p -> ('p, 'r, 'r list, 'r list) t
end

module Cursor : sig
  type ('p, 'pr, 'acc, 'qr) t

  val execute : ('p, 'pr, 'acc, unit) t -> (unit, [> err ]) result Abb.Future.t
  val fetch : ?n:int -> ('p, 'pr, 'acc, 'r list) t -> ('r list, [> err ]) result Abb.Future.t
  val destroy : ('p, 'pr, 'acc, 'qr) t -> (unit, [> err ]) result Abb.Future.t

  val with_cursor :
    ('p, 'pr, 'acc, 'qr) t ->
    f:(('p, 'pr, 'acc, 'qr) t -> ('a, ([> err ] as 'e)) result Abb.Future.t) ->
    ('a, 'e) result Abb.Future.t
end

module Prepared_stmt : sig
  type conn = t
  type ('q, 'qr, 'p, 'pr) t

  val create :
    conn -> ('q, 'qr, 'p, 'pr) Typed_sql.t -> (('q, 'qr, 'p, 'pr) t, [> err ]) result Abb.Future.t

  val bind :
    ('q, (('p, 'pr, 'acc, 'r) Cursor.t, [> err ]) result Abb.Future.t, 'p, 'pr) t ->
    ('p, 'pr, 'acc, 'r) Row_func.t ->
    'q

  (** Perform the create, bind, cursor execute, and cleanup of an SQL statement. *)
  val execute : conn -> ('q, (unit, [> err ]) result Abb.Future.t, unit, unit) Typed_sql.t -> 'q

  (** Perform the bind and execute, useful when executing the same statement multiple times. *)
  val bind_execute : ('q, (unit, [> err ]) result Abb.Future.t, unit, unit) t -> 'q

  (** Perform the create, bind, cursor fetch, and cleanup of an SQL statement. *)
  val fetch :
    conn -> ('q, ('r list, [> err ]) result Abb.Future.t, 'p, 'r) Typed_sql.t -> f:'p -> 'q

  val destroy : ('q, 'qr, 'p, 'pr) t -> (unit, [> err ]) result Abb.Future.t

  val kbind :
    conn ->
    ('q, ('ret, ([> err ] as 'err)) result Abb.Future.t, 'p, 'pr) Typed_sql.t ->
    ('p, 'pr, 'acc, 'r) Row_func.t ->
    (('p, 'pr, 'acc, 'r) Cursor.t -> ('ret, 'err) result Abb.Future.t) ->
    'q
end

type create_err =
  [ `Unexpected of exn
  | `Connection_failed
  | `Connect_missing_password_err
  | `Tls_negotiate_err of Abb_tls.err
  | `Tls_required_but_denied_err
  | `Tls_unexpected_response of int * string
  | `Unsupported_auth_gss_err
  | `Unsupported_auth_sasl_err
  | `Unsupported_auth_scm_credential_err
  | `Unsupported_auth_sspi_err
  | frame_err
  ]
[@@deriving show]

(** Create a connection. [buf_size_threshold] is a threshold for how large the protocol debugging
    buffer can get before decoding is pushed to another thread. *)
val create :
  ?tls_config:[ `Require of Otls.Tls_config.t | `Prefer of Otls.Tls_config.t ] ->
  ?passwd:string ->
  ?port:int ->
  ?notice_response:((char * string) list -> unit) ->
  ?buf_size_threshold:int ->
  host:string ->
  user:string ->
  string ->
  (t, [> create_err ]) result Abb.Future.t

val destroy : t -> unit Abb.Future.t

(** Return if the connection is considered connected. A connection can be set to disconnected by an
    earlier operation failing. This does not perform any network operations to test if the
    connection is still alive. *)
val connected : t -> bool

(** Each connection is given a unique ID *)
val id : t -> Uuidm.t

(** Perform a network operation to test if the connection is alive. Return [true] if it succeeds and
    [false] if it not. This also sets [connected] to [false] if the connection is not alive. *)
val ping : t -> bool Abb.Future.t

(** Execute the function inside a transaction. If the function fails, either by returning [Error _]
    or throwing an exception or being aborted, the exception will be rolled back. Otherwise it will
    be commited.

    Nested transactions are not supported. *)
val tx : t -> f:(unit -> ('a, ([> err ] as 'e)) result Abb.Future.t) -> ('a, 'e) result Abb.Future.t

(** {1 Asynchronous notifications (LISTEN / NOTIFY)}

    A single NOTIFY received on the connection, carrying the originating backend [pid], the
    [channel], and the [payload]. *)
type notification = {
  pid : int32;
  channel : string;
  payload : string;
}

(** Notifications received on a connection (for channels it has [listen]ed to) are enqueued on the
    connection as they are decoded — both while blocked in [wait_for_notification] and while
    consuming the results of any ordinary query/fetch on the connection. [wait_for_notification]
    pops the oldest, blocking for the next if the queue is empty; [get_notification] pops without
    blocking. The usual flow is [listen] on one or more channels, then drain via either function.

    [wait_for_notification] is a single reader: while it is blocked the connection must not be used
    for queries (a concurrent query raises ["SQL connection busy"]). Dedicate a connection to
    listening. *)

(** Issue [LISTEN] on [channel] so this connection begins receiving its NOTIFYs. *)
val listen : t -> channel:string -> (unit, [> err ]) result Abb.Future.t

(** Issue [UNLISTEN] on [channel]. *)
val unlisten : t -> channel:string -> (unit, [> err ]) result Abb.Future.t

(** Issue [UNLISTEN *], removing all of this connection's channel registrations in a single round
    trip, and clear the connection's "may have listens" flag. Pending notifications committed before
    this runs are flushed into the queue as its response is consumed; pair with
    [drain_notifications] to discard them. *)
val unlisten_all : t -> (unit, [> err ]) result Abb.Future.t

(** Whether [listen] has ever been issued on this connection (and not since cleared by
    [unlisten_all]). A conservative flag — not a per-channel set. Lets a caller (e.g. a connection
    pool) skip the [unlisten_all] round trip on a connection that never listened. *)
val has_listens : t -> bool

(** Issue [NOTIFY] on [channel] with [payload] (default empty). Channel and payload are sent as
    bound parameters via [pg_notify]. *)
val notify : t -> channel:string -> ?payload:string -> unit -> (unit, [> err ]) result Abb.Future.t

(** Pop the oldest queued notification, or — if the queue is empty — block until the next one
    arrives, then return it ([Error `Disconnected] if the connection drops). Takes no timeout
    argument: bound it with [Abbs_future_combinators.timeout]. An abort (e.g. from a wrapping
    [timeout]) leaves the connection valid and reusable. *)
val wait_for_notification : t -> (notification, [> err ]) result Abb.Future.t

(** Pop the oldest queued notification if one is present, else return [None] immediately. Use to
    drain already-received notifications without blocking. *)
val get_notification : t -> notification option

(** Discard all queued notifications without any database round trip. *)
val drain_notifications : t -> unit

(** Help function that takes a string representing SQL and removes any comments (lines that start
    with --). This DOES NOT remove comments if they are not the very first entry on a line. *)
val clean_string : string -> string

(** Split a multi-statement SQL script into its individual statements, trimmed, with empties
    dropped. PostgreSQL refuses to prepare a multi-statement string and {!Prepared_stmt.execute}
    prepares each call as one statement, so scripts must be run a statement at a time. The boundary
    is a semicolon followed by a blank line ([";\n\n"]) rather than a bare semicolon, so that
    semicolons inside function bodies do not split them; SQL files meant to be run this way follow
    that convention. *)
val split_statements : string -> string list

(** Run every statement of a multi-statement script in order, stopping at the first error. The
    statements take no parameters; a script with a parameterized statement must be split with
    {!split_statements} and executed by the caller. *)
val execute_script : t -> string -> (unit, [> err ]) result Abb.Future.t

module Copy_to : sig
  type t

  val null : t
  val smallint : int -> t
  val integer : int32 -> t
  val bigint : int64 -> t
  val real : float -> t
  val double : float -> t
  val money : int64 -> t
  val boolean : bool -> t
  val text : string -> t
  val varchar : string -> t
  val char : string -> t
  val json : Yojson.Safe.t -> t
  val jsonb : Yojson.Safe.t -> t
  val bytea : string -> t
  val uuid : Uuidm.t -> t
end

val copy_to :
  table:string ->
  cols:string list ->
  t ->
  Copy_to.t list list ->
  (int, [> err ]) result Abb.Future.t

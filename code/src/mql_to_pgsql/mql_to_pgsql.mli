module Page : sig
  type dir =
    | Affirm  (** The page is going in the direction of the query. *)
    | Negate  (** The page is going in the opposite direction of the query *)
  [@@deriving show, eq, yojson]

  type t = {
    dir : dir;
    cursor : Yojson.Safe.t;
  }
  [@@deriving show, eq, yojson]
end

module Pages : sig
  type t = {
    prev : Page.t;
    next : Page.t;
  }
  [@@deriving show, eq]
end

module Schema : sig
  module Column : sig
    module Type_ : sig
      type t =
        | Bigint
        | Bool
        | Complex of string
        | Float
        | Integer
        | Jsonb
        | Smallint
        | Text
        | Timestamptz
        | Uuid
      [@@deriving show, eq]
    end

    type t

    val make : name:string -> type_:Type_.t -> unit -> t
  end

  module Table : sig
    type t

    val make : ?table_expr:bool -> name:string -> Column.t list -> t
    val name : t -> string
  end

  type t [@@deriving to_yojson]

  val make : Table.t list -> t
end

type of_mql_err =
  [ `Table_access_err of string
  | `Ambiguous_column_err of string
  | `Unknown_column_err of string
  | `Func_access_err of string
  | (* A construct MQL reads so that it can read the SQL of this repository,
       but that a query from outside must not get. The string names it. A
       schema-qualified name gives access to data outside the tenant-scoped copies of the
       tables; a window makes the cost of a query hard to bound; a call in a
       FROM clause makes columns the schema does not know. *)
    `Construct_not_allowed_err of string
  | `Cast_err of string
  | `Invalid_identifier_err of string
  | `Type_mismatch_err of Schema.Column.Type_.t * Mql_ast.expr
  | `Variable_err of string
    (** A [$name] variable. The user-facing query must not carry one: it would be rendered verbatim
        into the compiled SQL and resolved against that template's own parameters. The same closed
        door {!Mql.Ast.of_string} presents with [variables:false]. *)
  | `Locking_not_allowed_err
    (** A row-locking clause ([FOR UPDATE] and friends). Refused independently of {!Mql.Feature}, so
        enabling the parse-level feature for a trusted caller still does not let a lock reach the
        database through this path. *)
  | `Data_modifying_not_allowed_err
    (** [INSERT] / [UPDATE] / [DELETE], including as a CTE. Refused independently of {!Mql.Feature},
        so enabling the parse-level feature for a trusted caller still does not let a write reach
        the database through this path. *)
  | `Ddl_not_allowed_err
    (** A schema statement ([CREATE]/[ALTER]/[DROP]/...). Same posture as the DML above: MQL can
        read them, this module never compiles one. *)
  ]
[@@deriving show, eq]

(** Failures of the post-condition audit {!of_mql} runs over its own output.

    These are distinct from {!of_mql_err} on purpose: an {!of_mql_err} is this module correctly
    refusing a bad query, whereas an [audit_err] means a guard did NOT fire and the emitted query
    named something outside the schema. Reaching one is a bug in this module, not caller error. They
    are returned rather than raised so the endpoint degrades to a 500 instead of crashing. *)
type audit_err =
  [ `Audit_table_err of string
  | `Audit_func_err of string
  | `Audit_construct_err of string
  | `Audit_cast_err of string
  | `Audit_identifier_err of string
  | `Audit_variable_err of string
  | `Audit_data_modifying_err
  | `Audit_locking_err
    (** A row-locking clause. The rewrite emits none, so a [FOR UPDATE] in an audited AST can only
        mean the AST did not come from the rewrite. *)
  | `Audit_ddl_err
  ]
[@@deriving show, eq]

(** Everything {!of_mql} can return. Callers that need to tell the two apart should match
    [#of_mql_err] before [#audit_err]. The HTTP status is the caller's decision, and it depends on
    who built the AST: a query the request carried is caller error, so the MQL endpoint answers an
    [of_mql_err] with 400; an AST this codebase built that {!of_mql} refuses means this codebase
    made a bad query, so the paged endpoint answers with 500. An [audit_err] is always 500: the
    audit judges this module's own output, so reaching one is a bug here no matter who built the
    AST. *)
type err =
  [ of_mql_err
  | audit_err
  ]
[@@deriving show, eq]

type pages_err =
  [ `Column_not_in_row_err of string
  | `Order_by_col_not_identifier_err of Mql_ast.expr
    (** Ordering by anything but a name ([select ... order by d->>'k']) — the cursor is built from
        the ordered column's value keyed by name, so a value that is not a name has no key. *)
  | `Cursor_value_not_scalar_err of string * Yojson.Safe.t
    (** Ordering by a column whose values are not scalars (jsonb, bool, an array) — there is no
        cursor to build from such a value, so the query cannot be keyset-paginated. *)
  ]
[@@deriving show, eq]

type apply_page_err =
  [ `Distinct_cannot_paginate_err
    (** A [DISTINCT] query cannot be keyset-paginated: the keyset predicate is applied before the
        dedup, so a cursor taken from a returned row does not name a boundary of the result the
        caller saw. *)
  | `Order_by_mismatch_err
  | `Missing_order_by_err
  | `Missing_group_by_err
  | `Missing_cursor_col_err of string
  | `Order_by_col_not_identifier_err of Mql_ast.expr
  | `Page_invalid_type_err of Yojson.Safe.t
  ]
[@@deriving show, eq]

type t [@@deriving show, eq]

val query : t -> Mql.Ast.t
val texts : t -> string CCVector.vector

(** The timestamptz literals of the query. The caller binds them as the [timestamptz[]] parameter
    [$timestamptzs].

    #2469: A cast from text to [timestamptz] is not immutable. PostgreSQL does not make it a
    constant, and postgres_fdw does not send it to the remote server. Then a filter on a foreign
    table stays local. A typed parameter prevents this. This is necessary only because the foreign
    data wrapper abstraction is leaky. *)
val timestamptzs : t -> string CCVector.vector

val json : t -> string CCVector.vector
val smallints : t -> int CCVector.vector
val integers : t -> Int32.t CCVector.vector
val bigints : t -> Int64.t CCVector.vector
val floats : t -> float CCVector.vector

(** The schema tables that the query reads, without duplicates. CTEs and unnests are not included.

    #2469: The caller uses this list to find a query that reads foreign tables. Such a query needs
    other planner settings. This is necessary only because the foreign data wrapper abstraction is
    leaky. *)
val tables : t -> string list

(** The functions that a query from outside may call. Give this list, or a subset of it, as
    [~func_allow_list] of {!of_mql}.

    Each function operates only on the values passed to it: it reads no table by a name in a value,
    no file, no server setting and no system catalog, it reaches no network, it cannot delay the
    server, and it returns one row. Thus a call cannot read data outside the schema, and it does not
    change the number of rows that [LIMIT] and pagination count.

    The list:
    - Conditional: [coalesce], [nullif], [greatest], [least].
    - Aggregate: [count], [sum], [avg], [min], [max], [bool_and], [bool_or], [string_agg],
      [array_agg], [json_agg], [jsonb_agg].
    - String: [lower], [upper], [length], [trim], [ltrim], [rtrim], [substr], [replace],
      [split_part], [strpos], [starts_with], [concat], [concat_ws], [regexp_replace], [to_char].
    - Numeric: [abs], [ceil], [floor], [round], [trunc].
    - JSON: [to_jsonb], [json_build_object], [jsonb_build_object], [json_build_array],
      [jsonb_build_array], [json_array_length], [jsonb_array_length], [json_typeof], [jsonb_typeof],
      [jsonb_extract_path_text], [jsonb_pretty].
    - Array: [array_length], [cardinality], [array_to_string].
    - Date and time: [now], [date_trunc], [date_part], [age]. *)
val default_func_allow_list : string list

(** The cast targets that a query from outside may use. Give this list, or a subset of it, as
    [~cast_allow_list] of {!of_mql}.

    Each target is a type of values. None names a database object, as [regclass] or [regproc] do, so
    a cast cannot turn a string into access to a table or a function.

    The list: [bigint], [bool], [boolean], [integer], [jsonb], [real], [smallint], [text],
    [timestamptz], [uuid]. *)
val default_cast_allow_list : string list

(** Given an AST, a defined schema, and some other constraints, turn the AST into a valid query that
    can be safely executed via pgsql.

    The safety guarantee: for any AST, this either fails or returns a query that reads nothing
    outside [schema] — every table is in the schema or is a CTE the query itself binds, every
    function is in [func_allow_list], every cast is in [cast_allow_list], every identifier is
    in-charset, and no [$name] variable survives. That guarantee is what lets the caller substitute
    the rendered query into a template whose tenant-scoped CTEs shadow the real tables (see
    [code/src/sgs_mql/sql/select_mql_page.sql]); a name that escaped the schema would resolve to the
    real, unscoped table.

    A function or cast name is compared with the lists as PostgreSQL resolves it: an unquoted name
    in lower case, a quoted name as written. Thus each list holds lower-case names.

    The guarantee is enforced twice — by the rewrite itself, and by an independent audit of the
    result, which is what {!audit_err} reports. *)
val of_mql :
  ?max_limit:int ->
  func_allow_list:string list ->
  cast_allow_list:string list ->
  schema:Schema.t ->
  Mql.Ast.t ->
  (t, [> err ]) result

(** Check a query against the safety guarantee described on {!of_mql}, without compiling it.

    {!of_mql} runs this over its own output, so a caller does not need to. No production caller
    names it: the audits that matter run inside {!of_mql}. It is a test hook -- the guarantee is
    worth being able to assert directly, over any AST, including one no parser would produce -- and
    it lives in {!Tests} for that reason.

    Deliberately shares no code with the rewrite's own guards. That is the whole point: it is a
    second opinion, so a guard that fails to fire is still caught. *)
module Tests : sig
  val audit_query :
    func_allow_list:string list ->
    cast_allow_list:string list ->
    schema:Schema.t ->
    Mql.Ast.t ->
    (unit, [> audit_err ]) result
end

(** A query can only automatically be paginated if it has an [ORDER BY] clause. Using the results we
    construct cursors for the previous and next page. This does not validate that there ARE actually
    more pages, simply if you wanted to a previous or next page, what the cursor value would be. It
    is up to the caller to decide if there are previous pages. [None] is returned if the query is
    lacks an [ORDER BY]. *)
val pages : Yojson.Safe.t list -> t -> (Pages.t option, [> pages_err ]) result

(** Given a query and a page, apply the page to the query. Fail if the query does not have any
    corresponding *)
val apply_page : Page.t -> Mql_ast.t -> (Mql_ast.t, [> apply_page_err ]) result

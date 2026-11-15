(** Constructs that are unsafe to accept from an untrusted source.

    Same posture as {!Ast.of_string}'s [variables]: absent by default, and a caller has to name one
    to get it. The HTTP endpoint names none, so it cannot parse any of these at all — that is the
    first of two gates. The second is {!Mql_to_pgsql.of_mql}, which refuses them independently even
    when parsing was allowed to produce them, so a single mistake does not open a hole. *)
module Feature : sig
  type t =
    | Data_modifying  (** [INSERT] / [UPDATE] / [DELETE], and a CTE that is one *)
    | Locking_clause  (** [FOR UPDATE] and friends *)
    | Ddl  (** [CREATE] / [ALTER] / [DROP] and the other schema statements *)
  [@@deriving show, eq]

  val all : t list
end

module Ast : sig
  type pos = {
    lnum : int;
    offset : int;
  }
  [@@deriving show, eq]

  type err = [ `Error of pos option * string * string ] [@@deriving show, eq]
  type t = Mql_ast.t [@@deriving show, eq]

  (** The query's [LIMIT], when it is an integer literal. A [$name] limit has no statically known
      value and returns [None]. *)
  val limit : t -> int option

  val set_limit : int -> t -> t

  (** Parse an MQL query. [variables] (default [false]) admits the [$name] named-variable syntax
      understood by {!Pgsql_io.Typed_sql}, in every position PostgreSQL admits a prepared-statement
      parameter. Leave it [false] for any query originating outside this codebase: the parsed text
      is substituted into a SQL template that is itself scanned for [$].

      PostgreSQL's comment forms are accepted -- [--] to end of line and nesting [/* ... */] -- and
      are discarded, so {!to_string} does not reproduce them.

      [features] (default [[]]) admits the constructs in {!Feature}. Leave it empty for any query
      originating outside this codebase. *)
  val of_string : ?variables:bool -> ?features:Feature.t list -> string -> (t, [> err ]) result

  (** Parse one or more queries separated by [;]. A single query needs no [;]; a trailing one after
      the last query is accepted and is not reproduced by {!to_string_multi}. Statement boundaries
      are decided by the parser, so a [;] inside a string literal or a subquery is not one. See
      {!of_string} for [variables]. *)
  val of_string_multi :
    ?variables:bool -> ?features:Feature.t list -> string -> (t list, [> err ]) result

  (** Read one expression. A filter that another module builds as text arrives here, thus its tree
      can take the place of a [$name] variable in a query this repository holds.

      Takes no [features]: an expression holds no gated construct at its top level, so a gate here
      would say more than it does. Give it text from this codebase only. *)
  val expr_of_string : ?variables:bool -> string -> (Mql_ast.expr, [> err ]) result

  (** Render a query. Fails, rather than raising, on an AST with no rendering (one [Mql.Build] can
      construct but the grammar cannot express). *)
  val to_string : t -> (string, [> err ]) result

  (** Render queries separated by ["; "] with no trailing [;], so [to_string_multi [ q ]] equals
      [to_string q]. An empty list renders as [""].

      To execute the queries, map {!to_string} over the list rather than re-splitting this output:
      the parser already decided the statement boundaries, which is the point of parsing [;]. *)
  val to_string_multi : t list -> (string, [> err ]) result

  val expr_to_string : Mql_ast.expr -> (string, [> err ]) result
end

module Build : sig
  (** {1 Expressions} *)

  val id : string -> Mql_ast.expr
  val string : string -> Mql_ast.expr
  val int : int -> Mql_ast.expr
  val float : float -> Mql_ast.expr
  val true_ : Mql_ast.expr
  val false_ : Mql_ast.expr
  val null : Mql_ast.expr
  val eq : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val not_eq : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val gt : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val gte : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val lt : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val lte : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val and_ : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val or_ : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val not_ : Mql_ast.expr -> Mql_ast.expr
  val is : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val is_not : Mql_ast.expr -> Mql_ast.expr -> Mql_ast.expr
  val in_ : Mql_ast.expr -> Mql_ast.expr list -> Mql_ast.expr

  (** [in_query e q] builds [e IN (q)] where [q] is a subquery. *)
  val in_query : Mql_ast.expr -> Mql_ast.t -> Mql_ast.expr

  (** [field table column] builds [table.column]. *)
  val field : string -> string -> Mql_ast.expr

  (** [func name args] builds the call [name(args)]. *)
  val func : string -> Mql_ast.expr list -> Mql_ast.expr

  (** The [count] aggregate over [*]. *)
  val count_star : Mql_ast.expr

  (** {1 Tables} *)

  (** One entry of a FROM clause: a table with no join attached to it. *)
  val table : ?alias:string -> string -> Mql_ast.from_entry

  (** {1 Groups} *)

  (** A [GROUP BY] over plain expressions. *)
  val group_by : Mql_ast.expr list -> Mql_ast.group_by

  (** {1 Order} *)

  (** One entry of an [ORDER BY]. *)
  val order_by :
    ?order:Mql_ast.sort_order -> ?nulls:Mql_ast.nulls_order -> Mql_ast.expr -> Mql_ast.order_by_item

  (** {1 Columns} *)

  val col : ?alias:string -> Mql_ast.expr -> Mql_ast.column
  val columns : Mql_ast.column list -> Mql_ast.select_list
  val star : Mql_ast.select_list

  (** {1 Queries} *)

  val select :
    ?where:Mql_ast.expr ->
    ?joins:Mql_ast.join list ->
    ?group_by:Mql_ast.group_by ->
    ?having:Mql_ast.expr ->
    ?order_by:Mql_ast.order_by ->
    ?limit:int ->
    from:Mql_ast.from_entry list ->
    cols:Mql_ast.select_list ->
    unit ->
    Mql_ast.t

  (** [union_all a b] builds [a UNION ALL b]. The operands' bodies are combined; any
      [order_by]/[limit] on [a] or [b] is dropped (in this AST those belong to the wrapping query,
      not to a union operand). Chain by nesting on the left, e.g. [union_all (union_all a b) c],
      since a union's right operand must be a single select. *)
  val union_all : Mql_ast.t -> Mql_ast.t -> Mql_ast.t

  (** {1 Schema statements} *)

  (** [drop_table ?if_exists n] builds [DROP TABLE [IF EXISTS] n]; [if_exists] defaults to false,
      the plain statement. *)
  val drop_table : ?if_exists:bool -> string -> Mql_ast.t

  (** [analyze_table n] builds [ANALYZE n] over one table. It takes one name and not a list, so that
      a call cannot make the [ANALYZE] of every table of the database. *)
  val analyze_table : string -> Mql_ast.t

  (** [create_temp_table_as ?on_commit_drop n q] builds [CREATE TEMP TABLE n AS q], with
      [ON COMMIT DROP] between the name and [AS] when [on_commit_drop] is true. *)
  val create_temp_table_as : ?on_commit_drop:bool -> string -> Mql_ast.t -> Mql_ast.t

  (** [lock_table ?mode n] builds [LOCK TABLE n IN <mode> MODE]. [mode] defaults to
      [Lock_mode_access_exclusive], the strongest mode. A caller that needs less names the mode it
      takes. *)
  val lock_table : ?mode:Mql_ast.lock_table_mode -> string -> Mql_ast.t

  (** [range_bound ~from ~to_] builds [FOR VALUES FROM ('from') TO ('to')], the bound of one range
      partition; both bounds go in as string literals. *)
  val range_bound : from:string -> to_:string -> Mql_ast.partition_bound

  (** [create_table_partition_of ?if_not_exists ~parent ~bound n] builds
      [CREATE [IF NOT EXISTS] TABLE n PARTITION OF parent bound]. *)
  val create_table_partition_of :
    ?if_not_exists:bool -> parent:string -> bound:Mql_ast.partition_bound -> string -> Mql_ast.t

  (** [delete_where ~where n] builds [DELETE FROM n WHERE where]. *)
  val delete_where : where:Mql_ast.expr -> string -> Mql_ast.t

  (** [insert_select ~query n] builds [INSERT INTO n query]. *)
  val insert_select : query:Mql_ast.t -> string -> Mql_ast.t
end

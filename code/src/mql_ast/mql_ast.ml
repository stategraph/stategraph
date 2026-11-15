(* An SQL identifier, carrying whether it was written quoted.

   The flag is not decoration: a quoted [Foo] and a bare [Foo] are different
   names to PostgreSQL, which folds an unquoted name to lower case, and a quoted
   [select] is a legal name while a bare one is a keyword. So the printer has to
   reproduce the spelling it was given, which means the AST has to remember it.
   [name] is always the name itself, with the quotes stripped and any doubled
   quote already collapsed. *)
type ident = {
  name : string;
  quoted : bool;
}

and t =
  (* Schema statements. Present so MQL can READ the repo's migrations; like DML
     they are gated behind [Mql.Feature.Ddl] at parse and refused by
     [Mql_to_pgsql.of_mql]. *)
  | Create_table of {
      if_not_exists : bool;
      temp : bool;
      name : table_name;
      body : create_table_body;
      (* [ON COMMIT DROP] -- a temporary table that PostgreSQL deletes at the end
         of the transaction. *)
      on_commit_drop : bool;
      (* [PARTITION BY strategy (key)] -- how the table splits its rows across
         its partitions.  Absent for an unpartitioned table. *)
      partition : table_partition option;
    }
  | Create_index of {
      unique : bool;
      concurrently : bool;
      if_not_exists : bool;
      name : ident option;  (** [CREATE INDEX ON t (..)] names no index *)
      table : table_name;
      method_ : ident option;  (** [USING gin] *)
      columns : index_element list;
      (* [INCLUDE (a, b)] -- columns that the index holds but does not sort on. *)
      include_ : ident list;
      (* [NULLS NOT DISTINCT] -- a unique index holds one row for each set of
         empty values, and not one row for every row that holds one.  PostgreSQL
         15 and later.  [NULLS DISTINCT] is the default and no statement of this
         repository writes it, thus the reader takes only the [NOT] form. *)
      nulls_not_distinct : bool;
      where : expr option;
    }
  | Create_view of {
      or_replace : bool;
      name : table_name;
      columns : ident list;
      query : t;
    }
  (* The argument list and the trailing clauses are structured; the BODY is not.
     A function body is plpgsql (or SQL) in its own right and is deliberately
     kept verbatim rather than parsed -- see [Func_as]. *)
  | Create_function of {
      or_replace : bool;
      name : table_name;
      args : func_arg list;
      clauses : func_clause list;
    }
  | Create_trigger of {
      or_replace : bool;
      name : ident;
      timing : trigger_timing;
      events : trigger_event list;
      table : table_name;
      for_each_row : bool;
      execute : table_name;
    }
  | Create_extension of {
      if_not_exists : bool;
      name : ident;
    }
  | Set_stmt of {
      local : bool;
      name : table_name;
      value : expr;
    }
  (* [SET CONSTRAINTS ALL DEFERRED] -- when PostgreSQL checks a foreign key: at the end of the
     transaction rather than at each statement.  An empty [names] is [ALL]. *)
  | Set_constraints of {
      names : table_name list;
      deferred : bool;
    }
  (* [ALTER FUNCTION f() SET search_path = public, pg_catalog] -- a setting
     that PostgreSQL applies each time the function runs.  This repository
     writes only an empty argument list. *)
  | Alter_function_set of {
      name : table_name;
      setting : ident;
      values : expr list;
    }
  | Alter_table of {
      if_exists : bool;
      only : bool;
      name : table_name;
      actions : alter_action list;
    }
  | Drop of {
      object_ : ident list;  (** [table], [foreign; table], [trigger], ... *)
      concurrently : bool;
      (* [DROP FUNCTION f()] -- an argument list. It makes one function
         different from another function with the same name. This repository
         writes only an empty list. *)
      empty_args : bool;
      if_exists : bool;
      names : table_name list;
      on_table : table_name option;  (** [DROP TRIGGER x ON t] *)
      behavior : drop_behavior option;
    }
  | Comment_on of {
      object_ : ident;
      name : table_name;
      comment : string option;
    }
  (* [GRANT SELECT (a, b) ON t TO r] and [REVOKE ...]. The privilege is a name
     and the column list is empty when the grant is on the whole table. *)
  | Grant of {
      revoke : bool;
      privilege : ident;
      columns : ident list;
      table : table_name;
      role : ident;
    }
  (* [CREATE ROLE r LOGIN PASSWORD 'x'] and [CREATE DATABASE d]. Only the
     forms that this repository writes at the first start. *)
  | Create_role of {
      name : ident;
      login : bool;
      password : string option;
    }
  | Create_database of ident
  | Truncate of {
      names : table_name list;
      behavior : drop_behavior option;
    }
  | Analyze of table_name list  (** empty means every table *)
  (* [LOCK TABLE t IN EXCLUSIVE MODE] -- a lock that holds until the
     transaction ends.  Gated as DDL, like the other schema statements. *)
  | Lock_table of {
      name : table_name;
      (* Absent is [LOCK TABLE t] with no [IN ... MODE] phrase. *)
      mode : lock_table_mode option;
    }
  | Insert of {
      table : table;
      columns : ident list;  (** empty when the statement names no column list *)
      source : insert_source;
      on_conflict : on_conflict option;
      returning : select_list option;
    }
  | Update of {
      table : table;
      set_ : assignment list;
      from : from_tables;
      where : expr option;
      returning : select_list option;
    }
  | Delete of {
      table : table;
      (* [DELETE FROM t USING u WHERE ...] -- the rows to read during the delete operation. *)
      using : from_tables;
      where : expr option;
      returning : select_list option;
    }
  | With of {
      materialized : cte_materialization;
      (* [WITH RECURSIVE] -- the CTE can name itself. *)
      recursive : bool;
      name : ident;
      (* [WITH c(a, b) AS (...)] -- the names of the columns of the CTE.  An
         empty list means the CTE names no column. *)
      columns : ident list;
      query : t;
      body : t;
    }
  | Query of {
      body : query_body;
      order_by : order_by option;
      (* [OFFSET n] -- the quantity of rows to omit. *)
      offset : expr option;
      (* The grammar only ever puts [Int] or [Variable] here.  It is typed as a
         general [expr] so that a [$name] limit is representable at all. *)
      limit : expr option;
      (* [FOR UPDATE] and friends. A read API has no use for row locks, so this
         is refused by [Mql_to_pgsql.of_mql]; it exists so MQL can represent the
         repo's own queries. *)
      locking : locking option;
    }

(* How PostgreSQL holds a CTE. [Cte_default] gives the selection to
   PostgreSQL. The other two values make the selection. *)
and cte_materialization =
  | Cte_default
  | Cte_materialized
  | Cte_not_materialized

and locking = {
  strength : lock_strength;
  wait : lock_wait;
  (* [FOR UPDATE OF t] -- the tables that the lock holds. An empty list means all the
     tables. *)
  of_ : ident list;
}

and lock_strength =
  | Lock_update
  | Lock_no_key_update
  | Lock_share
  | Lock_key_share

and lock_wait =
  | Lock_wait
  | Lock_nowait
  | Lock_skip_locked

(* How [LOCK TABLE] locks the table.  PostgreSQL spells each mode as the whole
   phrase [in <words> mode]; the lexer reads that phrase as one token, so
   [share], [exclusive] and [mode] stay ordinary names. *)
and lock_table_mode =
  | Lock_mode_access_share
  | Lock_mode_row_share
  | Lock_mode_row_exclusive
  | Lock_mode_share
  | Lock_mode_share_row_exclusive
  | Lock_mode_exclusive
  | Lock_mode_access_exclusive

(* Data-modifying statements. Present so MQL can READ the repo's own SQL; they
   are gated behind [Mql.Feature.Data_modifying] at parse and refused outright by
   [Mql_to_pgsql.of_mql], which compiles the user-facing read query. *)
and insert_source =
  | Insert_values of expr list list
  | Insert_query of t
  | Insert_default_values

and on_conflict_action =
  | Do_nothing
  | Do_update of {
      set_ : assignment list;
      where : expr option;
    }

and on_conflict = {
  target : on_conflict_target;
  action : on_conflict_action;
}

(* What PostgreSQL matches the new row against. *)
and on_conflict_target =
  | On_conflict_none
  (* [(a, b)], and also [(repo, (params->>'branch'))]. *)
  | On_conflict_elems of {
      elems : on_conflict_elem list;
      (* [ON CONFLICT (a) WHERE p] -- which partial index to match. *)
      where : expr option;
    }
  (* [ON CONFLICT ON CONSTRAINT c] *)
  | On_conflict_constraint of ident

(* One entry of a conflict target. PostgreSQL accepts a name with no
   parentheses.  PostgreSQL needs parentheses around each other form.  Thus the
   two forms are separate. *)
and on_conflict_elem =
  | Conflict_col of ident
  | Conflict_expr of expr

(* [SET a = 1] and [SET (a, b) = (1, 2)] -- the second one sets more than
   one column from one row of values. *)
and assignment =
  | Assign of (ident * expr)
  | Assign_row of (ident list * expr list)

(* A possibly schema-qualified name, as DDL writes them. *)
and table_name = {
  qualifier : ident option;
  base : ident;
}

and func_arg = {
  arg_name : ident option;
  arg_type : type_name;
}

and func_clause =
  | Func_returns of func_return
  | Func_language of ident
  (* The body, verbatim, with the dollar-quote delimiter it was written with. *)
  | Func_as_body of (string * string)
  | Func_as_string of string
  | Func_volatility of ident  (** [immutable] / [stable] / [volatile] *)
  | Func_strict
  | Func_security of ident  (** [definer] / [invoker] *)
  | Func_parallel of ident
  | Func_cost of int
  | Func_rows of int

and func_return =
  | Ret_type of type_name
  | Ret_setof of type_name
  | Ret_table of column_def list
  | Ret_trigger

and trigger_timing =
  | Trg_before
  | Trg_after
  | Trg_instead_of

and trigger_event =
  | Trg_insert
  (* [UPDATE OF a, b] -- the trigger operates only for these columns. *)
  | Trg_update of ident list
  | Trg_delete
  | Trg_truncate

and drop_behavior =
  | Cascade
  | Restrict

and type_name = {
  type_ident : table_name;
  (* Some SQL type names are several words -- [timestamp with time zone],
     [double precision]. Held as a variant rather than extra identifiers so the
     printer emits the right tokens and the result re-parses. *)
  type_extra : type_extra;
  args : int list;  (** [varchar(255)], [numeric(10, 2)] *)
  array_dims : int;  (** how many [[]] suffixes *)
}

and type_extra =
  | No_extra
  | With_time_zone
  | Without_time_zone
  | Precision
  | Varying

and table_item =
  | Column_def of column_def
  | Table_constraint of table_constraint

and column_def = {
  col_name : ident;
  col_type : type_name;
  col_constraints : column_constraint list;
}

(* How a partitioned table splits its rows: by value ranges or by value lists. *)
and partition_strategy =
  | Ps_range
  | Ps_list

(* The slice of the parent's values that one partition holds: a range with a
   lower and an upper bound, a list of values, or the catch-all default. *)
and partition_bound =
  | Pb_range of (expr list * expr list)
  | Pb_in of expr list
  | Pb_default

(* [PARTITION BY strategy (key)]. *)
and table_partition = {
  strategy : partition_strategy;
  key : expr list;
}

(* What a CREATE TABLE gives to the table: a list of columns and constraints,
   or the rows of a query. *)
and create_table_body =
  | Table_items of table_item list
  | Table_as_query of t
  (* [CREATE FOREIGN TABLE ... SERVER s OPTIONS (...)] -- a table that is in
     another database. *)
  | Table_foreign of {
      items : table_item list;
      server : ident;
      options : (ident * string) list;
    }
  (* [CREATE TABLE ... PARTITION OF parent FOR VALUES ...] -- a partition of a
     partitioned table.  The parent gives the columns; the bound gives the
     slice of its values. *)
  | Table_partition_of of {
      parent : table_name;
      bound : partition_bound;
    }

and column_constraint =
  | Not_null
  | Null_allowed
  | Default_value of expr
  | Col_primary_key
  | Col_unique
  | Col_check of expr
  | Col_references of references
  | Col_named_constraint of (ident * column_constraint)
  (* [GENERATED ALWAYS AS (e) STORED] -- PostgreSQL calculates the value from the row.
     [GENERATED ALWAYS AS IDENTITY] -- PostgreSQL gives the value. *)
  | Col_generated_stored of expr
  | Col_generated_identity

and references = {
  ref_table : table_name;
  ref_columns : ident list;
  ref_actions : ref_action list;
}

and ref_action =
  | On_delete of ref_act
  | On_update of ref_act

and ref_act =
  | Ract_cascade
  | Ract_restrict
  | Ract_set_null
  | Ract_set_default
  | Ract_no_action

and table_constraint =
  | Tbl_primary_key of {
      columns : ident list;
      (* [INCLUDE (a, b)] -- columns the constraint's index holds but does not
         sort on, so a read that projects them stays index-only.  PostgreSQL 11
         and later. *)
      include_ : ident list;
    }
  (* [PRIMARY KEY USING INDEX i] and [UNIQUE USING INDEX i] -- change an index that
     is already present to a constraint. *)
  | Tbl_primary_key_using_index of ident
  | Tbl_unique_using_index of ident
  | Tbl_unique of {
      columns : ident list;
      include_ : ident list;
    }
  | Tbl_check of expr
  | Tbl_foreign_key of (ident list * references)
  | Tbl_named_constraint of (ident * table_constraint)

and index_element = {
  idx_expr : expr;
  (* [gin_trgm_ops] -- the operator class that the index uses for this entry. *)
  idx_opclass : ident option;
  idx_order : sort_order option;
}

and alter_action =
  | Add_column of {
      if_not_exists : bool;
      column : column_def;
    }
  | Drop_column of {
      if_exists : bool;
      name : ident;
      behavior : drop_behavior option;
    }
  | Alter_column of (ident * alter_column_action)
  | Add_constraint of table_constraint
  (* [NOT VALID] prevents a read of the rows that are already
     present. *)
  | Add_constraint_not_valid of table_constraint
  (* [SET (autovacuum_enabled = true, ...)] -- the settings of the table. *)
  | Set_options of (ident * expr) list
  | Drop_constraint of {
      if_exists : bool;
      name : ident;
      behavior : drop_behavior option;
    }
  | Rename_to of ident
  | Rename_column of (ident * ident)
  (* [ALTER TABLE ... ATTACH PARTITION t FOR VALUES ...] -- a table that already
     holds rows joins a partitioned table. *)
  | Attach_partition of {
      name : table_name;
      bound : partition_bound;
    }

and alter_column_action =
  | Set_not_null
  | Drop_not_null
  | Set_default of expr
  | Drop_default
  | Set_type of {
      type_ : type_name;
      (* [TYPE t USING e] -- how to change the old value to the new value. *)
      using : expr option;
    }

and query_body =
  | Select of select
  (* [UNION], [EXCEPT] and [INTERSECT] join two bodies the same way, thus one
     shape holds all three. *)
  | Set_op of {
      op : set_op;
      all : bool;
      left : query_body;
      right : query_body;
    }
  | Paren of t

and set_op =
  | Union
  | Except
  | Intersect

and select = {
  distinct : distinct option;
  select_list : select_list;
  (* Each entry of a FROM clause is a table with the joins that attach to it.
     A comma separates the entries, thus [from a join b on x, c] is two entries
     and not a flat list. *)
  from : from_tables;
  where : where option;
  group_by : group_by option;
  having : expr option;
}

(* [DISTINCT] and [DISTINCT ON (..)]. Kept as a property of the select rather
   than of the select list, because it changes which ROWS come back, not which
   columns -- which is also why it defeats keyset pagination (see
   [Mql_to_pgsql.pages]). *)
and distinct =
  | Distinct
  | Distinct_on of expr list

and select_list =
  | Star
  | Columns of column list

and column = {
  expr : expr;
  alias : ident option;
}

and table = {
  (* [information_schema.tables].  A name in this repository almost always has
     no schema.  The SQL writes the schema only to get a catalogue. *)
  table_qualifier : ident option;
  name : ident;
  alias : ident option;
}

and table_ref =
  | Table_ref of table
  (* [UNNEST(a, b) AS v(x, y)].  More than one array makes more than one
     column, thus [exprs] is a list and a column alias list can name the
     columns. *)
  | Unnest of {
      exprs : expr list;
      alias : ident;
      columns : column_alias list;  (** empty when the item names no column *)
    }
  (* A derived table: [FROM (SELECT ...) AS t]. Its column set is unknown to the
     schema, which is why [Mql_to_pgsql] treats it as a [table_expr]. *)
  | Derived_table of {
      query : t;
      alias : ident;
      columns : column_alias list;
      (* [LATERAL] permits the item to read the columns of the items
         before it. *)
      lateral_ : bool;
    }
  (* A call in a FROM clause: [jsonb_array_elements_text(x) AS e]. It makes rows,
     thus it is in the position of a table. *)
  | Func_table of {
      expr : expr;
      (* [WITH ORDINALITY] -- the call gives one more column, the number of each
         row. *)
      ordinality : bool;
      alias : ident option;
      columns : column_alias list;
      lateral_ : bool;
    }

(* One column name that a FROM item gives to its result. A call that makes a
   record needs a type for each column: [jsonb_to_recordset(d) AS e(a text)]. *)
and column_alias = {
  ca_name : ident;
  ca_type : type_name option;
}

and from_tables = from_entry list

and from_entry = {
  fe_table : table_ref;
  fe_joins : join list;
}

and join_list = join list

and join = {
  join_type : join_type;
  (* A join target is each form that a FROM clause accepts, not only a table: this
     repository joins onto derived tables and onto calls. *)
  table : table_ref;
  on_ : join_cond;
}

(* [ON <expr>] or [USING (cols)].  A [CROSS JOIN] has neither, which is what
   [No_cond] spells -- SQL forbids a condition there. *)
and join_cond =
  | On of expr
  | Using of ident list
  | No_cond

and join_type =
  | Inner
  | Left
  | Right
  | Full
  | Cross

and where = expr

(* What a [GROUP BY] groups on. [Group_sets] holds the form
   [GROUPING SETS ((a), ())].  A set can be empty, and an empty set is not an
   expression. *)
and group_by =
  | Group_exprs of expr list
  | Group_sets of expr list list

and order_by = order_by_item list

and order_by_item = {
  ob_expr : expr;
  ob_order : sort_order option;
  (* [NULLS FIRST] / [NULLS LAST] -- the position of the empty values. *)
  ob_nulls : nulls_order option;
}

and nulls_order =
  | Nulls_first
  | Nulls_last

and sort_order =
  | Asc
  | Desc

and tuple = expr list

and expr =
  | Add of (expr * expr)
  | And of (expr * expr)
  | Cast of (expr * type_name)
  | Concat of (expr * expr)
  | Div of (expr * expr)
  | Eq of (expr * expr)
  | Exists of t
  | False
  | Field_select of (expr * ident)
  | Float of float
  | Func of func
  | Gt of (expr * expr)
  | Gte of (expr * expr)
  | Identifier of ident
  | Ilike of (expr * expr)
  | In of (expr * tuple)
  | In_query of (expr * t)
  | Index of (expr * expr)
  | Int of int
  | Is of (expr * expr)
  | Is_distinct_from of (expr * expr)
  | Is_not of (expr * expr)
  | Is_not_distinct_from of (expr * expr)
  | Json_obj_query of (expr * string)
  | Json_subset of (expr * expr)
  | Json_text of (expr * expr)
  | Json_val of (expr * expr)
  | Like of (expr * expr)
  | Lt of (expr * expr)
  | Lte of (expr * expr)
  | Mult of (expr * expr)
  | Negate of expr
  | Not of expr
  | Not_eq of (expr * expr)
  | Not_ilike of (expr * expr)
  | Not_like of (expr * expr)
  | Null
  | Or of (expr * expr)
  | String of string
  | Sub of (expr * expr)
  | True
  | Tuple of tuple
  | At_time_zone of (expr * expr)  (** [ts AT TIME ZONE 'utc'] *)
  | Not_in of (expr * tuple)
  (* [a not in (select ...)] *)
  | Not_in_query of (expr * t)
  (* A query in the position of a value: [where a = (select b from t)]. *)
  | Scalar_subquery of t
  (* [t.*] in a select list. *)
  | Qualified_star of expr
  (* [array[1, 2]].  The list can be empty: [array[]::text[]]. *)
  | Array_lit of expr list
  (* [array(select ...)] -- the rows of a query, as one array. *)
  | Array_query of t
  (* [d ? 'k'] -- does the object hold the key [k]. *)
  | Json_has_key of (expr * expr)
  (* [a like b escape c] -- the character that makes the next character plain. *)
  | Like_escape of (expr * expr * expr)
  (* [extract(epoch from x)] -- the word before [from] is the name of a field
     of a date, thus it is a name and not an expression. *)
  | Extract of (ident * expr)
  (* [substring(x from 'pattern')] *)
  | Substring_from of (expr * expr)
  (* [position('/' in x)] *)
  | Position_in of (expr * expr)
  (* [a % b] -- the remainder of a division. *)
  | Mod of (expr * expr)
  (* [a[1 : 2]] -- a part of an array. *)
  | Slice of (expr * expr * expr)
  (* [CASE WHEN c THEN v ... ELSE e END], and the [CASE operand WHEN ...] form.
     [branches] is non-empty: SQL requires at least one WHEN. *)
  | Case of {
      operand : expr option;
      branches : (expr * expr) list;
      else_ : expr option;
    }
  | Interval of string  (** [INTERVAL '1 day'] -- the literal is opaque to us *)
  | Json_obj_val of (expr * string)  (** [#>], the jsonb-returning sibling of [#>>] *)
  | Regex_match of (expr * expr)  (** [~] *)
  | Regex_not_match of (expr * expr)  (** [!~] *)
  | Regex_imatch of (expr * expr)  (** [~*], the match that ignores case *)
  | Regex_not_imatch of (expr * expr)  (** [!~*] *)
  (* [a COLLATE "C"] -- the rules that sort and compare the text. *)
  | Collate of (expr * ident)
  (* [a & b] -- the bits that are in each of the two integers. *)
  | Bit_and of (expr * expr)
  (* [#>] and [#>>] with a path that is not a literal: [ro.tx #> r.path].
     [Json_obj_val] and [Json_obj_query] hold the literal form, which a query
     from outside can use. *)
  | Json_obj_val_path of (expr * expr)
  | Json_obj_query_path of (expr * expr)
  | Variable of string
      (** A [pgsql_io] named variable, [$name], carrying [name] without the [$]. It is rendered
          verbatim by {!Mql.Ast.to_string} and resolved to a positional parameter by
          {!Pgsql_io.Typed_sql}. *)

and func = {
  (* [pg_temp.mask_sensitive_attributes(...)].  A call almost always has no schema.
     The SQL writes the schema only to get a temporary function. *)
  qualifier : ident option;
  name : ident;
  (* [count(DISTINCT x)] *)
  distinct : bool;
  args : func_args;
  (* [string_agg(x, ',' ORDER BY y)] -- the sort order of an aggregate.  It is not
     the sort order of the query. *)
  agg_order_by : order_by option;
  (* [FILTER (WHERE p)] -- the aggregate reads only the rows that agree with [p]. *)
  filter : expr option;
  (* [row_number() OVER (...)] *)
  over : window option;
}

(* An aggregate over a star takes no expression. A star is not an expression,
   thus it is a separate shape. *)
and func_args =
  | Func_star
  | Func_exprs of func_arg_value list

(* An argument of a call. PostgreSQL permits a call to give a name to each
   argument: [make_interval(secs => 1)]. *)
and func_arg_value =
  | Arg of expr
  | Arg_named of (ident * expr)

(* The window of an [OVER] clause. This grammar has no frame clause and no
   [WINDOW] clause.  This repository writes no such clause. *)
and window = {
  partition_by : expr list;
  window_order_by : order_by option;
}
[@@deriving show { with_path = false }, eq, yojson]

(* An ordinary, unquoted identifier -- what code building an AST in OCaml wants.
   A quoted one only arises from parsing a quoted name. *)
let ident name = { name; quoted = false }

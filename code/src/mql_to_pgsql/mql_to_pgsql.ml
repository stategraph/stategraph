module String_map = Sln_map.String

module Col_expr = struct
  type t =
    | Id of string
    | Field of (string * string)
    | Count_star
  [@@deriving ord]
end

module Col_expr_map = CCMap.Make (Col_expr)

(* The MQL function allow-list.

   SECURITY -- a function named here may be called by any MQL query, so only
   pure, value-level scalar and aggregate functions belong in this list. An
   entry MUST NOT: read the filesystem, server settings, or system catalogs
   (e.g. [pg_read_file], [current_setting], [pg_ls_dir]); reach the network
   (e.g. the [dblink] family); enable a denial-of-service (e.g. [pg_sleep],
   [generate_series]); or return a set of rows, which would multiply result
   rows and break [LIMIT] and pagination (e.g. [unnest], [jsonb_array_elements],
   [regexp_matches], [jsonb_object_keys]). Every entry below operates only on
   the values passed to it. *)
let default_func_allow_list =
  [
    (* Conditional *)
    "coalesce";
    "nullif";
    "greatest";
    "least";
    (* Aggregates *)
    (* [count] is in this list because a call over a star is now an ordinary
       call.  It is an aggregate like the others: it reads no new data. *)
    "count";
    "sum";
    "avg";
    "min";
    "max";
    "bool_and";
    "bool_or";
    "string_agg";
    "array_agg";
    "json_agg";
    "jsonb_agg";
    (* String *)
    "lower";
    "upper";
    "length";
    "trim";
    "ltrim";
    "rtrim";
    "substr";
    "replace";
    "split_part";
    "strpos";
    "starts_with";
    "concat";
    "concat_ws";
    "regexp_replace";
    "to_char";
    (* Numeric *)
    "abs";
    "ceil";
    "floor";
    "round";
    "trunc";
    (* JSON *)
    "to_jsonb";
    "json_build_object";
    "jsonb_build_object";
    "json_build_array";
    "jsonb_build_array";
    "json_array_length";
    "jsonb_array_length";
    "json_typeof";
    "jsonb_typeof";
    "jsonb_extract_path_text";
    "jsonb_pretty";
    (* Array *)
    "array_length";
    "cardinality";
    "array_to_string";
    (* Date/time *)
    "now";
    "date_trunc";
    "date_part";
    "age";
  ]

let default_cast_allow_list =
  [
    "bigint";
    "bool";
    "boolean";
    "integer";
    "jsonb";
    "real";
    "smallint";
    "text";
    "timestamptz";
    "uuid";
  ]

module Page = struct
  type dir =
    | Affirm
    | Negate
  [@@deriving show, eq, yojson]

  type t = {
    dir : dir;
    cursor : Yojson.Safe.t;
  }
  [@@deriving show, eq, yojson]
end

module Pages = struct
  type t = {
    prev : Page.t;
    next : Page.t;
  }
  [@@deriving show, eq]
end

module Schema = struct
  module Column = struct
    module Type_ = struct
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
      [@@deriving show { with_path = false }, eq]

      let to_string = function
        | Bigint -> "bigint"
        | Bool -> "bool"
        | Complex type_ -> type_
        | Float -> "float"
        | Integer -> "integer"
        | Jsonb -> "jsonb"
        | Smallint -> "smallint"
        | Text -> "text"
        | Timestamptz -> "timestamptz"
        | Uuid -> "uuid"
    end

    type t = {
      name : string;
      type_ : Type_.t;
    }

    let make ~name ~type_ () = { name; type_ }
  end

  module Table = struct
    type t = {
      name : string;
      columns : Column.t String_map.t;
      table_expr : bool;
    }

    let make ?(table_expr = false) ~name columns =
      {
        name;
        columns =
          String_map.of_list @@ CCList.map (fun ({ Column.name; _ } as c) -> (name, c)) columns;
        table_expr;
      }

    let name t = t.name
  end

  type t = { tables : Table.t String_map.t }

  let make tables =
    { tables = String_map.of_list @@ CCList.map (fun ({ Table.name; _ } as t) -> (name, t)) tables }

  let to_yojson { tables } =
    `Assoc
      [
        ( "tables",
          `Assoc
            (CCList.map (fun (name, { Table.name = _; columns; table_expr = _ }) ->
                 ( name,
                   `Assoc
                     [
                       ( "columns",
                         `Assoc
                           (CCList.map (fun (col_name, { Column.name = _; type_ }) ->
                                ( col_name,
                                  `Assoc [ ("type", `String (Column.Type_.to_string type_)) ] ))
                           @@ String_map.to_list columns) );
                     ] ))
            @@ String_map.to_list tables) );
      ]
end

module Rw = struct
  type t = {
    texts : string CCVector.vector;
    timestamptzs : string CCVector.vector;
    json : string CCVector.vector;
    smallints : int CCVector.vector;
    integers : Int32.t CCVector.vector;
    bigints : Int64.t CCVector.vector;
    floats : float CCVector.vector;
    tables : string CCVector.vector;
    func_allow_list : string list;
    cast_allow_list : string list;
    schema : Schema.t;
    (* The names of the CTEs in scope.  [schema] holds a table for each of
       them, which hides a schema table of the same name. *)
    ctes : string list;
    col_name_to_columns : (string * Schema.Column.t) list String_map.t;
    tab_name_to_table : Schema.Table.t String_map.t;
    (* The columns that the select of this scope makes, or [None] if a star
       reads a source whose columns are unknown.  A CTE makes a table of them. *)
    output : Schema.Column.t list option;
  }
end

type of_mql_err =
  [ `Table_access_err of string
  | `Ambiguous_column_err of string
  | `Unknown_column_err of string
  | `Func_access_err of string
  | (* A construct MQL reads so that it can read the SQL of this repository,
     but that a query from outside must not get. The string names it. A
     schema-qualified name gives access to data outside the tenant-scoped copies of the
     tables; a window makes the cost of a query hard to bound; a call in a FROM
     clause makes columns the schema does not know. *)
    `Construct_not_allowed_err of string
  | `Cast_err of string
  | `Invalid_identifier_err of string
  | `Type_mismatch_err of Schema.Column.Type_.t * Mql_ast.expr
  | `Variable_err of string
  | (* A row-locking clause on a read endpoint. Refused independently of the
     parse-level [Mql.Feature] gate, so enabling the feature for a trusted caller
     still does not let a locking clause reach the database through [of_mql]. *)
    `Locking_not_allowed_err
  | (* [INSERT] / [UPDATE] / [DELETE], including as a CTE. This module compiles the
     read query behind a read-only endpoint; a write has no business reaching it,
     and is refused independently of the parse-level [Mql.Feature] gate. *)
    `Data_modifying_not_allowed_err
  | (* A schema statement. Same posture as the DML above: readable, never
     compiled by the read endpoint. *)
    `Ddl_not_allowed_err
  ]
[@@deriving show, eq]

type pages_err =
  [ `Column_not_in_row_err of string
  | `Order_by_col_not_identifier_err of Mql_ast.expr
  | (* A cursor is a scalar the keyset comparison can be run against. Ordering by
     a jsonb, bool or array column reaches here with a value that is none of
     those: [assert_order_by_cols_can_paginate] checks the ORDER BY entry is an
     identifier, not what type it has. Reported rather than asserted -- the query
     is reachable from an untrusted caller, and a crash is a worse answer than
     "this cannot be paginated". *)
    `Cursor_value_not_scalar_err of string * Yojson.Safe.t
  ]
[@@deriving show, eq]

type apply_page_err =
  [ `Distinct_cannot_paginate_err
  | `Order_by_mismatch_err
  | `Missing_order_by_err
  | `Missing_group_by_err
  | `Missing_cursor_col_err of string
  | `Order_by_col_not_identifier_err of Mql_ast.expr
  | `Page_invalid_type_err of Yojson.Safe.t
  ]
[@@deriving show, eq]

(* The post-condition audit's own errors, kept separate from [of_mql_err] so a
   failure here is unmistakably "a guard did not fire" rather than ordinary
   rejection of a bad query. Reaching one of these is a bug in this module. *)
type audit_err =
  [ `Audit_table_err of string
  | `Audit_func_err of string
  | `Audit_construct_err of string
  | `Audit_cast_err of string
  | `Audit_identifier_err of string
  | `Audit_variable_err of string
  | `Audit_data_modifying_err
  | `Audit_locking_err
  | `Audit_ddl_err
  ]
[@@deriving show, eq]

type err =
  [ of_mql_err
  | audit_err
  ]
[@@deriving show, eq]

exception Rw_exn of of_mql_err
exception Audit_exn of audit_err

type t = {
  query : Mql.Ast.t;
  rw : Rw.t; [@opaque] [@equal fun _ _ -> true]
}
[@@deriving show, eq]

let query t = t.query
let texts t = t.rw.Rw.texts
let timestamptzs t = t.rw.Rw.timestamptzs
let json t = t.rw.Rw.json
let smallints t = t.rw.Rw.smallints
let integers t = t.rw.Rw.integers
let bigints t = t.rw.Rw.bigints
let floats t = t.rw.Rw.floats
let tables t = Sln_list.String.sort_uniq @@ CCVector.to_list t.rw.Rw.tables

(* Identifier charset guard (defense in depth).

   Identifiers (table/column/alias/CTE/function/cast-type names) are rendered
   verbatim by [Mql.Ast.to_string] and the result is text-substituted into the
   SQL template. Today the MQL lexer only admits [A-Za-z_][A-Za-z0-9_]*
   identifiers, so nothing dangerous can reach here -- but [of_mql] re-checks
   every identifier so that a future lexer change (quoted identifiers, unicode,
   dotted names, ...) cannot silently turn identifier rendering into a
   SQL-injection vector. This fails closed: any out-of-charset identifier is
   rejected with [`Invalid_identifier_err]. *)
let valid_identifier s =
  (not (CCString.is_empty s))
  && (match s.[0] with
    | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
    | _ -> false)
  && CCString.for_all
       (function
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
         | _ -> false)
       s

(* The charset guard runs on the name with its quotes stripped, so a QUOTED
   identifier gets no extra latitude. That is deliberate: quoting is how SQL
   spells a name containing spaces or punctuation, and admitting those would
   widen what can be rendered into the template for no benefit the schema can
   use -- no such column exists in it. Fails closed. *)
let check_identifier { Mql_ast.name; quoted = _ } =
  if not (valid_identifier name) then raise (Rw_exn (`Invalid_identifier_err name))

(* The name that PostgreSQL resolves.  PostgreSQL folds an unquoted name to lower case, so
   [COUNT] calls [count] and [::UUID] casts to [uuid]. *)
let folded_name { Mql_ast.name; quoted } = if quoted then name else CCString.lowercase_ascii name

(* A call to [count] over a star, with no decoration. This is the form of the page count of
   a read query, and the only form that the pagination code can give a value
   to.  A call with a decoration is a different value. *)
let is_plain_count_star = function
  | Mql_ast.Func
      {
        Mql_ast.qualifier = None;
        name;
        distinct = false;
        args = Mql_ast.Func_star;
        agg_order_by = None;
        filter = None;
        over = None;
      } -> CCString.equal (folded_name name) "count"
  | _ -> false

(* The decorations of a call, for the error and for the refusal. *)
let agg_decoration { Mql_ast.distinct; agg_order_by; filter; over; _ } =
  if distinct then Some "distinct"
  else if CCOption.is_some agg_order_by then Some "order by"
  else if CCOption.is_some filter then Some "filter"
  else if CCOption.is_some over then Some "over"
  else None

let rec check_identifiers_ast =
  let open Mql_ast in
  function
  | With { name; columns; query; body; _ } ->
      check_identifier name;
      CCList.iter check_identifier columns;
      check_identifiers_ast query;
      check_identifiers_ast body
  | Insert _ | Update _ | Delete _ -> raise (Rw_exn `Data_modifying_not_allowed_err)
  | Create_table _
  | Create_index _
  | Create_view _
  | Create_function _
  | Alter_function_set _
  | Alter_table _
  | Drop _
  | Comment_on _
  | Truncate _
  | Analyze _
  | Create_trigger _
  | Create_extension _
  | Set_stmt _
  | Set_constraints _
  | Grant _
  | Create_role _
  | Create_database _
  | Lock_table _ -> raise (Rw_exn `Ddl_not_allowed_err)
  | Query { body; order_by; limit; offset; locking; _ } ->
      (match locking with
      | None -> ()
      | Some _ -> raise (Rw_exn `Locking_not_allowed_err));
      check_identifiers_query_body body;
      CCOption.iter
        (CCList.iter (fun { Mql_ast.ob_expr; _ } -> check_identifiers_expr ob_expr))
        order_by;
      (* A limit and an offset can hold a [$name] variable.  Thus the
         code examines each one like each other expression. *)
      CCOption.iter check_identifiers_expr limit;
      CCOption.iter check_identifiers_expr offset

and check_identifiers_query_body =
  let open Mql_ast in
  function
  | Select s -> check_identifiers_select s
  | Set_op { left; right; _ } ->
      check_identifiers_query_body left;
      check_identifiers_query_body right
  | Paren q -> check_identifiers_ast q

and check_identifiers_select { Mql_ast.distinct; select_list; from; where; group_by; having } =
  (* [DISTINCT ON] carries expressions, so they are checked like any others. *)
  (match distinct with
  | None | Some Mql_ast.Distinct -> ()
  | Some (Mql_ast.Distinct_on es) -> CCList.iter check_identifiers_expr es);
  check_identifiers_select_list select_list;
  CCList.iter check_identifiers_from_entry from;
  CCOption.iter check_identifiers_expr where;
  CCOption.iter check_identifiers_group_by group_by;
  CCOption.iter check_identifiers_expr having

and check_identifiers_select_list =
  let open Mql_ast in
  function
  | Star -> ()
  | Columns cols ->
      CCList.iter
        (fun { expr; alias } ->
          check_identifiers_expr expr;
          CCOption.iter check_identifier alias)
        cols

and check_identifiers_func_arg = function
  | Mql_ast.Arg e -> check_identifiers_expr e
  | Mql_ast.Arg_named (n, e) ->
      check_identifier n;
      check_identifiers_expr e

and check_identifiers_group_by = function
  | Mql_ast.Group_exprs es -> CCList.iter check_identifiers_expr es
  | Mql_ast.Group_sets gs -> CCList.iter (CCList.iter check_identifiers_expr) gs

and check_identifiers_table { Mql_ast.table_qualifier; name; alias } =
  CCOption.iter check_identifier table_qualifier;
  check_identifier name;
  CCOption.iter check_identifier alias

and check_identifiers_from_entry { Mql_ast.fe_table; fe_joins } =
  check_identifiers_table_ref fe_table;
  CCList.iter check_identifiers_join fe_joins

and check_identifiers_table_ref =
  let open Mql_ast in
  function
  | Table_ref t -> check_identifiers_table t
  | Derived_table { query; alias; columns; lateral_ = _ } ->
      check_identifiers_ast query;
      check_identifier alias;
      CCList.iter check_identifiers_column_alias columns
  | Unnest { exprs; alias; columns } ->
      CCList.iter check_identifiers_expr exprs;
      check_identifier alias;
      CCList.iter check_identifiers_column_alias columns
  | Func_table { expr; ordinality = _; alias; columns; lateral_ = _ } ->
      check_identifiers_expr expr;
      CCOption.iter check_identifier alias;
      CCList.iter check_identifiers_column_alias columns

and check_identifiers_column_alias { Mql_ast.ca_name; ca_type } =
  check_identifier ca_name;
  CCOption.iter
    (fun { Mql_ast.type_ident; _ } ->
      CCOption.iter check_identifier type_ident.Mql_ast.qualifier;
      check_identifier type_ident.Mql_ast.base)
    ca_type

and check_identifiers_join { Mql_ast.join_type = _; table; on_ } =
  check_identifiers_table_ref table;
  check_identifiers_join_cond on_

(* A [USING (a, b)] names columns; they are identifiers and get the same charset
   guard as any other. *)
and check_identifiers_join_cond = function
  | Mql_ast.On e -> check_identifiers_expr e
  | Mql_ast.Using cs -> CCList.iter check_identifier cs
  | Mql_ast.No_cond -> ()

and check_identifiers_expr =
  let open Mql_ast in
  function
  | Add (e1, e2)
  | And (e1, e2)
  | Concat (e1, e2)
  | Div (e1, e2)
  | Eq (e1, e2)
  | Gt (e1, e2)
  | Gte (e1, e2)
  | Ilike (e1, e2)
  | Index (e1, e2)
  | Is (e1, e2)
  | Is_distinct_from (e1, e2)
  | Is_not (e1, e2)
  | Is_not_distinct_from (e1, e2)
  | Json_subset (e1, e2)
  | Json_text (e1, e2)
  | Json_val (e1, e2)
  | Like (e1, e2)
  | Lt (e1, e2)
  | Lte (e1, e2)
  | Mult (e1, e2)
  | Not_eq (e1, e2)
  | Not_ilike (e1, e2)
  | Not_like (e1, e2)
  | Or (e1, e2)
  | Sub (e1, e2) ->
      check_identifiers_expr e1;
      check_identifiers_expr e2
  | Cast (e, type_) ->
      check_identifiers_expr e;
      check_identifier type_.Mql_ast.type_ident.Mql_ast.base
  | Exists q -> check_identifiers_ast q
  | False | True | Null | Float _ | Int _ | String _ -> ()
  | Field_select (e, field) ->
      check_identifiers_expr e;
      check_identifier field
  | Func { qualifier; name; args; distinct = _; agg_order_by; filter; over } ->
      CCOption.iter check_identifier qualifier;
      check_identifier name;
      (match args with
      | Func_star -> ()
      | Func_exprs args -> CCList.iter check_identifiers_func_arg args);
      CCOption.iter
        (CCList.iter (fun { Mql_ast.ob_expr; _ } -> check_identifiers_expr ob_expr))
        agg_order_by;
      CCOption.iter check_identifiers_expr filter;
      CCOption.iter
        (fun { partition_by; window_order_by } ->
          CCList.iter check_identifiers_expr partition_by;
          CCOption.iter
            (CCList.iter (fun { Mql_ast.ob_expr; _ } -> check_identifiers_expr ob_expr))
            window_order_by)
        over
  | Identifier s -> check_identifier s
  | In (e, tuple) ->
      check_identifiers_expr e;
      CCList.iter check_identifiers_expr tuple
  | In_query (e, q) ->
      check_identifiers_expr e;
      check_identifiers_ast q
  | Json_obj_query (e, _path) ->
      (* [_path] is a string literal operand of [#>>], not an identifier;
         it is escaped at render time, not emitted as an identifier. *)
      check_identifiers_expr e
  | Negate e | Not e -> check_identifiers_expr e
  | Tuple tuple -> CCList.iter check_identifiers_expr tuple
  | Not_in (e, tuple) ->
      check_identifiers_expr e;
      CCList.iter check_identifiers_expr tuple
  | Not_in_query (e, q) ->
      check_identifiers_expr e;
      check_identifiers_ast q
  | At_time_zone (e1, e2)
  | Regex_match (e1, e2)
  | Regex_not_match (e1, e2)
  | Regex_imatch (e1, e2)
  | Regex_not_imatch (e1, e2)
  | Json_obj_val_path (e1, e2)
  | Json_obj_query_path (e1, e2)
  | Bit_and (e1, e2) ->
      check_identifiers_expr e1;
      check_identifiers_expr e2
  (* [_path] is a string literal operand, not an identifier -- as for [#>>]. *)
  | Json_obj_val (e, _path) -> check_identifiers_expr e
  | Collate (e, c) ->
      check_identifiers_expr e;
      check_identifier c
  (* The literal is opaque text, escaped at render, so nothing to check. *)
  | Interval _ -> ()
  | Case { operand; branches; else_ } ->
      CCOption.iter check_identifiers_expr operand;
      CCList.iter
        (fun (c, v) ->
          check_identifiers_expr c;
          check_identifiers_expr v)
        branches;
      CCOption.iter check_identifiers_expr else_
  (* [of_mql] compiles the user-facing query, where a [$name] variable is never
     wanted -- it would be rendered verbatim into [select_mql_page.sql] and
     resolved against that template's own parameters.  Fail closed, the same
     answer [Mql.Ast.of_string] gives with [variables:false].  A query that
     legitimately carries variables is rendered with [Mql.Ast.to_string] into
     its own [Typed_sql] and never comes through here. *)
  | Variable v -> raise (Rw_exn (`Variable_err v))
  | Scalar_subquery q | Array_query q -> check_identifiers_ast q
  | Qualified_star e -> check_identifiers_expr e
  | Array_lit es -> CCList.iter check_identifiers_expr es
  | Json_has_key (e1, e2) | Substring_from (e1, e2) | Position_in (e1, e2) ->
      check_identifiers_expr e1;
      check_identifiers_expr e2
  | Like_escape (e1, e2, e3) ->
      check_identifiers_expr e1;
      check_identifiers_expr e2;
      check_identifiers_expr e3
  (* The word before [from] is the name of a field of a date.  It has the same
     character-set check as each other name. *)
  | Extract (field, e) ->
      check_identifier field;
      check_identifiers_expr e
  | Mod (e1, e2) ->
      check_identifiers_expr e1;
      check_identifiers_expr e2
  | Slice (e1, e2, e3) ->
      check_identifiers_expr e1;
      check_identifiers_expr e2;
      check_identifiers_expr e3

let lookup_col_type ?table ~rw col =
  match table with
  | Some table_name -> (
      match String_map.find_opt table_name rw.Rw.tab_name_to_table with
      | Some table -> (
          match
            CCOption.or_
              ~else_:
                (if table.Schema.Table.table_expr then Some (Schema.Column.Type_.Complex "unknown")
                 else None)
            @@ CCOption.map (fun column -> column.Schema.Column.type_)
            @@ String_map.find_opt col table.Schema.Table.columns
          with
          | Some type_ -> Some type_
          | None -> raise (Rw_exn (`Unknown_column_err col)))
      | None -> raise (Rw_exn (`Table_access_err table_name)))
  | None -> (
      match String_map.find_opt col rw.Rw.col_name_to_columns with
      | Some [] -> None
      | Some [ (_, col) ] -> Some col.Schema.Column.type_
      | Some (_ :: _) -> raise (Rw_exn (`Ambiguous_column_err col))
      (* A name that is no column but a table in scope is the whole row of that
         table, as in PostgreSQL.  Its value holds only the columns of that
         table: a schema table resolves to the tenant-scoped CTE of the page
         query, whose columns are the columns of the schema. *)
      | None when String_map.mem col rw.Rw.tab_name_to_table -> None
      | None
        (* An unrecognised bare column is only tolerated when a table with an
         unknown column set (a CTE / [unnest] / subquery-derived table) is
         actually IN SCOPE for this select -- the column could belong to it. *)
        when String_map.exists
               (fun _ { Schema.Table.table_expr; _ } -> table_expr)
               rw.Rw.tab_name_to_table -> None
      | None -> raise (Rw_exn (`Unknown_column_err col)))

let identifier_type ~rw =
  let open Mql_ast in
  function
  | Identifier id -> lookup_col_type ~rw id.name
  | Field_select (Identifier id, c) -> lookup_col_type ~rw ~table:id.name c.name
  | _ -> None

let rw_lit_bigint ~rw =
  let open Mql_ast in
  function
  | Int i ->
      CCVector.push rw.Rw.bigints (Int64.of_int i);
      let idx = CCVector.size rw.Rw.bigints in
      Index (Identifier (Mql_ast.ident "$bigints"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Bigint, v)))

let rw_lit_float ~rw =
  let open Mql_ast in
  function
  | Float fl ->
      CCVector.push rw.Rw.floats fl;
      let idx = CCVector.size rw.Rw.floats in
      Index (Identifier (Mql_ast.ident "$floats"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Float, v)))

let rw_lit_integer ~rw =
  let open Mql_ast in
  function
  | Int i ->
      CCVector.push rw.Rw.integers (Int32.of_int i);
      let idx = CCVector.size rw.Rw.integers in
      Index (Identifier (Mql_ast.ident "$integers"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Integer, v)))

let rw_lit_json ~rw =
  let open Mql_ast in
  function
  | String s ->
      CCVector.push rw.Rw.json s;
      let idx = CCVector.size rw.Rw.json in
      Index (Identifier (Mql_ast.ident "$json"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Jsonb, v)))

let rw_lit_smallint ~rw =
  let open Mql_ast in
  function
  | Int i ->
      CCVector.push rw.Rw.smallints i;
      let idx = CCVector.size rw.Rw.smallints in
      Index (Identifier (Mql_ast.ident "$smallints"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Smallint, v)))

let rw_lit_text ~rw =
  let open Mql_ast in
  function
  | String s ->
      CCVector.push rw.Rw.texts s;
      let idx = CCVector.size rw.Rw.texts in
      Index (Identifier (Mql_ast.ident "$texts"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Text, v)))

(* The name of a cast target, for the allow-list check.  A target that is
   qualified, that takes arguments, that has a trailing word, or that is an
   array, is not a plain type name.  The allow-list holds plain names only,
   thus such a target is refused. *)
let cast_type_name { Mql_ast.type_ident; type_extra; args; array_dims } =
  match (type_ident.Mql_ast.qualifier, type_extra, args) with
  | None, Mql_ast.No_extra, [] when array_dims = 0 -> Some type_ident.Mql_ast.base
  | _ -> None

(* The name of a target that the allow-list cannot hold.  The error message
   shows this name. *)
let cast_type_show { Mql_ast.type_ident; _ } =
  match type_ident.Mql_ast.qualifier with
  | Some q -> q.Mql_ast.name ^ "." ^ type_ident.Mql_ast.base.Mql_ast.name
  | None -> type_ident.Mql_ast.base.Mql_ast.name

(* The name that PostgreSQL gives to an output column without an alias.  The
   names this function does not know are ["?column?"], thus a query cannot
   refer to them by name. *)
let rec output_name =
  let open Mql_ast in
  function
  | Identifier id | Field_select (_, id) -> id.name
  | Func { name; _ } -> folded_name name
  | Cast (e, _) -> output_name e
  | _ -> "?column?"

(* A plain, unqualified cast target, as [rw_lit] writes them. *)
let plain_cast_type name =
  {
    Mql_ast.type_ident = { Mql_ast.qualifier = None; base = Mql_ast.ident name };
    type_extra = Mql_ast.No_extra;
    args = [];
    array_dims = 0;
  }

let rw_lit_timestamptz ~rw =
  let open Mql_ast in
  function
  | String s ->
      CCVector.push rw.Rw.timestamptzs s;
      let idx = CCVector.size rw.Rw.timestamptzs in
      Index (Identifier (Mql_ast.ident "$timestamptzs"), Int idx)
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Timestamptz, v)))

let rw_lit_uuid ~rw =
  let open Mql_ast in
  function
  | String s ->
      CCVector.push rw.Rw.texts s;
      let idx = CCVector.size rw.Rw.texts in
      Cast (Index (Identifier (Mql_ast.ident "$texts"), Int idx), plain_cast_type "uuid")
  | (Null | True | False) as e -> e
  | v -> raise (Rw_exn (`Type_mismatch_err (Schema.Column.Type_.Uuid, v)))

(* A literal that [rw_lit] makes a parameter of the type of a column.  Each
   other expression is not a value that [rw_lit] can type. *)
let is_literal = function
  | Mql_ast.String _ | Mql_ast.Int _ | Mql_ast.Float _ | Mql_ast.Null | Mql_ast.True | Mql_ast.False
    -> true
  | _ -> false

let rw_lit ~rw type_ expr =
  match type_ with
  | Schema.Column.Type_.Bigint -> rw_lit_bigint ~rw expr
  | Schema.Column.Type_.Bool -> expr
  | Schema.Column.Type_.Float -> rw_lit_float ~rw expr
  | Schema.Column.Type_.Integer -> rw_lit_integer ~rw expr
  | Schema.Column.Type_.Jsonb -> rw_lit_json ~rw expr
  | Schema.Column.Type_.Smallint -> rw_lit_smallint ~rw expr
  | Schema.Column.Type_.Text -> rw_lit_text ~rw expr
  | Schema.Column.Type_.Timestamptz -> rw_lit_timestamptz ~rw expr
  | Schema.Column.Type_.Complex _ -> expr
  | Schema.Column.Type_.Uuid -> rw_lit_uuid ~rw expr

let rec rw_expr ~rw =
  let open Mql_ast in
  function
  | Add (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Add (e1, e2)) e1 e2
  | And (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> And (e1, e2)) e1 e2
  | Cast (e1, type_) -> (
      match cast_type_name type_ with
      | Some name when Sln_list.String.mem (folded_name name) rw.Rw.cast_allow_list ->
          Cast (rw_expr ~rw e1, type_)
      | Some name -> raise (Rw_exn (`Cast_err name.name))
      | None -> raise (Rw_exn (`Cast_err (cast_type_show type_))))
  | Concat (e1, e2) -> Concat (rw_expr ~rw e1, rw_expr ~rw e2)
  | Div (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Div (e1, e2)) e1 e2
  | Eq (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Eq (e1, e2)) e1 e2
  | Exists q -> Exists (rw_ast ~rw q)
  | False -> False
  | Field_select (Identifier table, field) as e ->
      (* Qualified column reference [table.field]. Validate it against the
         schema; [Identifier table] is a table reference (not a column) so it
         is not recursively rewritten. [lookup_col_type] raises
         [`Table_access_err] / [`Unknown_column_err] as appropriate and is a
         no-op for [table_expr] tables (CTEs/unnest), whose columns are
         genuinely unknown. *)
      ignore (lookup_col_type ~rw ~table:table.name field.name);
      e
  | Field_select (e1, field) -> Field_select (rw_expr ~rw e1, field)
  | Float _ as e -> rw_lit_float ~rw e
  (* A schema before the name of a call is refused before the allow list is
     read: the allow list holds names without a schema. *)
  | Func { qualifier = Some q; _ } ->
      raise (Rw_exn (`Construct_not_allowed_err ("schema-qualified call " ^ q.name)))
  | Func { qualifier = None; name; distinct = _; args = _; agg_order_by = _; filter = _; over = _ }
    when not @@ Sln_list.String.mem (folded_name name) rw.Rw.func_allow_list ->
      raise (Rw_exn (`Func_access_err name.name))
  (* The rewriter refuses a decoration.  The audit refuses it a second time.  A
     window makes the cost of a query difficult to calculate.  A sort order or
     a filter in a call has no function in a read endpoint. *)
  | Func f when CCOption.is_some (agg_decoration f) ->
      raise (Rw_exn (`Construct_not_allowed_err (CCOption.get_exn_or "" (agg_decoration f))))
  | Func { args = Func_star; _ } as e -> e
  | Func { args = Func_exprs []; _ } as e -> e
  | Func ({ args = Func_exprs args; _ } as f) ->
      Func
        {
          f with
          args =
            Func_exprs
              (CCList.map
                 (function
                   (* An argument with a name before it identifies a
                      parameter of the function. This repository writes such a call; a
                      query from outside must not get one. *)
                   | Arg_named _ -> raise (Rw_exn (`Construct_not_allowed_err "a named argument"))
                   | Arg e -> Arg (rw_expr ~rw e))
                 args);
        }
  | Gt (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Gt (e1, e2)) e1 e2
  | Gte (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Gte (e1, e2)) e1 e2
  | Identifier id as e ->
      (* Bare column reference. Validate it against the schema for every
         position it can appear in (select list, group by, order by, ...), not
         just comparison operands. [lookup_col_type] raises
         [`Unknown_column_err] / [`Ambiguous_column_err], and tolerates unknown
         columns only when a [table_expr] table is in scope. *)
      ignore (lookup_col_type ~rw id.name);
      e
  | Ilike (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Ilike (e1, e2)) e1 e2
  | In (e, tuple) -> (
      (* Coerce literal list elements to the column's type, mirroring
         [rw_bin_op] for [=]. Without this, [uuid_col in ('...')] emits an
         uncast text placeholder and PostgreSQL rejects the type mismatch.
         List elements that are not literals are rewritten as-is. *)
      match identifier_type ~rw e with
      | Some type_ ->
          let rw_elem elem =
            match identifier_type ~rw elem with
            | None when is_literal elem -> rw_lit ~rw type_ elem
            | Some _ | None -> rw_expr ~rw elem
          in
          In (e, CCList.map rw_elem tuple)
      | None -> In (rw_expr ~rw e, CCList.map (rw_expr ~rw) tuple))
  | In_query (e, q) -> In_query (rw_expr ~rw e, rw_ast ~rw q)
  | Not_in_query (e, q) -> Not_in_query (rw_expr ~rw e, rw_ast ~rw q)
  | Index (e1, e2) -> Index (rw_expr ~rw e1, rw_expr ~rw e2)
  | Int _ as e -> rw_lit_bigint ~rw e
  | Is (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Is (e1, e2)) e1 e2
  | Is_distinct_from (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Is_distinct_from (e1, e2)) e1 e2
  | Is_not (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Is_not (e1, e2)) e1 e2
  | Is_not_distinct_from (e1, e2) ->
      rw_bin_op ~rw ~c:(fun e1 e2 -> Is_not_distinct_from (e1, e2)) e1 e2
  | Json_obj_query (e1, s) -> Json_obj_query (rw_expr ~rw e1, s)
  | Json_subset (e1, e2) -> Json_subset (rw_expr ~rw e1, rw_expr ~rw e2)
  | Json_text (e1, e2) -> Json_text (rw_expr ~rw e1, rw_expr ~rw e2)
  | Json_val (e1, e2) -> Json_val (rw_expr ~rw e1, rw_expr ~rw e2)
  | Like (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Like (e1, e2)) e1 e2
  | Lt (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Lt (e1, e2)) e1 e2
  | Lte (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Lte (e1, e2)) e1 e2
  | Mult (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Mult (e1, e2)) e1 e2
  | Negate e1 -> Negate (rw_expr ~rw e1)
  | Not e1 -> Not (rw_expr ~rw e1)
  | Not_eq (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Not_eq (e1, e2)) e1 e2
  | Not_ilike (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Not_ilike (e1, e2)) e1 e2
  | Not_like (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Not_like (e1, e2)) e1 e2
  | Null -> Null
  | Or (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Or (e1, e2)) e1 e2
  | String _ as e -> rw_lit_text ~rw e
  | Sub (e1, e2) -> rw_bin_op ~rw ~c:(fun e1 e2 -> Sub (e1, e2)) e1 e2
  | True -> True
  | Tuple tuple -> Tuple (CCList.map (rw_expr ~rw) tuple)
  (* Mirrors [In]: coerce literal elements to the column's type when the left
     side is a typed identifier, so they are parameterised rather than inlined. *)
  | Not_in (e, tuple) -> (
      match identifier_type ~rw e with
      | Some type_ ->
          let rw_elem elem =
            match identifier_type ~rw elem with
            | None when is_literal elem -> rw_lit ~rw type_ elem
            | Some _ | None -> rw_expr ~rw elem
          in
          Not_in (e, CCList.map rw_elem tuple)
      | None -> Not_in (rw_expr ~rw e, CCList.map (rw_expr ~rw) tuple))
  | At_time_zone (e1, e2) -> At_time_zone (rw_expr ~rw e1, rw_expr ~rw e2)
  | Regex_match (e1, e2) -> Regex_match (rw_expr ~rw e1, rw_expr ~rw e2)
  | Regex_not_match (e1, e2) -> Regex_not_match (rw_expr ~rw e1, rw_expr ~rw e2)
  | Json_obj_val (e, path) -> Json_obj_val (rw_expr ~rw e, path)
  | Interval _ as e -> e
  | Case { operand; branches; else_ } ->
      Case
        {
          operand = CCOption.map (rw_expr ~rw) operand;
          branches = CCList.map (fun (c, v) -> (rw_expr ~rw c, rw_expr ~rw v)) branches;
          else_ = CCOption.map (rw_expr ~rw) else_;
        }
  (* MQL parses each of these, thus MQL can parse the SQL of this repository.  A
     query from outside must not get them: a query in an expression, an array
     that the schema cannot type, and the SQL special forms each make what the
     query reads hard to check. *)
  | Scalar_subquery _ -> raise (Rw_exn (`Construct_not_allowed_err "a query in an expression"))
  | Qualified_star _ -> raise (Rw_exn (`Construct_not_allowed_err "a star on a name"))
  | Array_lit _ -> raise (Rw_exn (`Construct_not_allowed_err "an array"))
  | Array_query _ -> raise (Rw_exn (`Construct_not_allowed_err "an array from a query"))
  | Json_has_key _ -> raise (Rw_exn (`Construct_not_allowed_err "the ? operator"))
  | Like_escape _ -> raise (Rw_exn (`Construct_not_allowed_err "like with an escape"))
  | Extract _ -> raise (Rw_exn (`Construct_not_allowed_err "extract"))
  | Substring_from _ -> raise (Rw_exn (`Construct_not_allowed_err "substring from"))
  | Position_in _ -> raise (Rw_exn (`Construct_not_allowed_err "position in"))
  | Mod _ -> raise (Rw_exn (`Construct_not_allowed_err "the % operator"))
  | Slice _ -> raise (Rw_exn (`Construct_not_allowed_err "a part of an array"))
  | Regex_imatch _ -> raise (Rw_exn (`Construct_not_allowed_err "the ~* operator"))
  | Regex_not_imatch _ -> raise (Rw_exn (`Construct_not_allowed_err "the !~* operator"))
  | Collate _ -> raise (Rw_exn (`Construct_not_allowed_err "collate"))
  | Bit_and _ -> raise (Rw_exn (`Construct_not_allowed_err "the & operator"))
  | Json_obj_val_path _ | Json_obj_query_path _ ->
      raise (Rw_exn (`Construct_not_allowed_err "a json path that is not a literal"))
  (* Unreachable: [check_identifiers_ast] rejects variables before any rewriting
     happens.  Kept explicit so this fails closed rather than falling through. *)
  | Variable v -> raise (Rw_exn (`Variable_err v))

(* A literal on one side of a column gets the type of the column.  Each other
   expression is rewritten as it is: a call or an operator makes a value that
   is no literal. *)
and rw_bin_op ~rw ~c e1 e2 =
  match (identifier_type ~rw e1, identifier_type ~rw e2) with
  | Some type_, None when is_literal e2 -> c (rw_expr ~rw e1) (rw_lit ~rw type_ e2)
  | None, Some type_ when is_literal e1 -> c (rw_lit ~rw type_ e1) (rw_expr ~rw e2)
  | (Some _ | None), (Some _ | None) -> c (rw_expr ~rw e1) (rw_expr ~rw e2)

and rw_select_list ~rw =
  let open Mql_ast in
  function
  | Star -> Star
  | Columns cols ->
      Columns (CCList.map (fun { expr; alias } -> { expr = rw_expr ~rw expr; alias }) cols)

and rw_from ~rw from =
  let open Mql_ast in
  CCList.map
    (fun { fe_table; fe_joins } ->
      { fe_table = rw_table_ref ~rw fe_table; fe_joins = rw_joins ~rw fe_joins })
    from

and rw_table_ref ~rw =
  let open Mql_ast in
  function
  | Table_ref { table_qualifier = Some q; _ } ->
      (* A schema before a name gives access to data outside the tenant-scoped copies
         of the tables that the query is substituted into. *)
      raise (Rw_exn (`Construct_not_allowed_err ("schema-qualified table " ^ q.name)))
  | Table_ref _ as t -> t
  | Unnest { columns = _ :: _; _ } ->
      raise (Rw_exn (`Construct_not_allowed_err "column alias list"))
  | Unnest { exprs = [ expr ]; alias; columns } ->
      Unnest { exprs = [ rw_expr ~rw expr ]; alias; columns }
  | Unnest _ -> raise (Rw_exn (`Construct_not_allowed_err "unnest of more than one array"))
  | Derived_table { lateral_ = true; _ } -> raise (Rw_exn (`Construct_not_allowed_err "lateral"))
  | Derived_table { columns = _ :: _; _ } ->
      raise (Rw_exn (`Construct_not_allowed_err "column alias list"))
  | Derived_table { query; alias; columns; lateral_ } ->
      Derived_table { query = rw_ast ~rw query; alias; columns; lateral_ }
  | Func_table _ ->
      (* A call makes columns that the schema does not contain.  Thus
         the checks that read the schema cannot examine the data that the query
         reads. *)
      raise (Rw_exn (`Construct_not_allowed_err "a call in a from clause"))

and rw_joins ~rw joins =
  let open Mql_ast in
  CCList.map
    (fun ({ join_type = _; table; on_ } as j) ->
      {
        j with
        (* The table of a join gets the same checks as the table of a FROM clause. *)
        table = rw_table_ref ~rw table;
        on_ =
          (match on_ with
          | On e -> On (rw_expr ~rw e)
          (* [USING] names columns of the joined tables; there is nothing to
             rewrite, and the charset guard already ran over them. *)
          | Using _ | No_cond -> on_);
      })
    joins

and rw_where ~rw e = rw_expr ~rw e

and rw_group_by ~rw = function
  | Mql_ast.Group_exprs exprs -> Mql_ast.Group_exprs (CCList.map (rw_expr ~rw) exprs)
  (* A group over sets makes rows that the schema cannot type.  Thus the checks
     that read the schema cannot examine the data that the query gives back. *)
  | Mql_ast.Group_sets _ -> raise (Rw_exn (`Construct_not_allowed_err "grouping sets"))

and rw_having ~rw e = rw_expr ~rw e

and rw_order_by ~rw order_by =
  CCList.map
    (fun ({ Mql_ast.ob_expr; _ } as item) -> { item with Mql_ast.ob_expr = rw_expr ~rw ob_expr })
    order_by

and col_alias_to_expr select_list =
  let open Mql_ast in
  match select_list with
  | Star -> String_map.empty
  | Columns cols ->
      CCListLabels.fold_left
        ~init:String_map.empty
        ~f:(fun acc col ->
          match col with
          | { expr; alias = Some alias } -> String_map.add alias.name expr acc
          | _ -> acc)
        cols

and expr_to_col_alias select_list =
  let open Mql_ast in
  match select_list with
  | Star -> Col_expr_map.empty
  | Columns cols ->
      CCListLabels.fold_left
        ~init:Col_expr_map.empty
        ~f:(fun acc col ->
          match col with
          | { expr = Identifier col; alias = Some alias } ->
              Col_expr_map.add (Col_expr.Id col.name) alias.name acc
          | { expr = Field_select (Identifier table, col); alias = Some alias } ->
              Col_expr_map.add (Col_expr.Field (table.name, col.name)) alias.name acc
          | { expr; alias = Some alias } when is_plain_count_star expr ->
              Col_expr_map.add Col_expr.Count_star alias.name acc
          | _ -> acc)
        cols

and rw_ast ~rw ast = fst (rw_ast_scope ~rw ast)

(* Rewrite a query, and give the scope of its leftmost select.  The output
   columns of that select are the columns of the query. *)
and rw_ast_scope ~rw =
  let open Mql_ast in
  function
  (* A recursive CTE refers to itself.  Thus the checks that read the schema
     cannot examine the data that it reads. *)
  | With { recursive = true; _ } -> raise (Rw_exn (`Construct_not_allowed_err "with recursive"))
  (* The names of the columns of a CTE hide the names that its query gives.
     Thus the checks that read the query cannot find the columns. *)
  | With { columns = _ :: _; _ } -> raise (Rw_exn (`Construct_not_allowed_err "a CTE column list"))
  | With ({ name; query; body; _ } as w) ->
      let query, query_rw = rw_ast_scope ~rw query in
      (* The CTE hides a table of the same name, thus a query can read only
         the columns that the body of the CTE makes. *)
      let table =
        match query_rw.Rw.output with
        | Some columns -> Schema.Table.make ~name:name.name columns
        | None -> Schema.Table.make ~table_expr:true ~name:name.name []
      in
      let schema = { Schema.tables = String_map.add name.name table rw.Rw.schema.Schema.tables } in
      let body, scope_rw =
        rw_ast_scope ~rw:{ rw with Rw.schema; ctes = name.name :: rw.Rw.ctes } body
      in
      (With { w with query; body }, scope_rw)
  (* Unreachable: [check_identifiers_ast] refused these before any rewriting.
     Explicit so this fails closed rather than falling through. *)
  | Insert _ | Update _ | Delete _ -> raise (Rw_exn `Data_modifying_not_allowed_err)
  | Create_table _
  | Create_index _
  | Create_view _
  | Create_function _
  | Alter_function_set _
  | Alter_table _
  | Drop _
  | Comment_on _
  | Truncate _
  | Analyze _
  | Create_trigger _
  | Create_extension _
  | Set_stmt _
  | Set_constraints _
  | Grant _
  | Create_role _
  | Create_database _
  | Lock_table _ -> raise (Rw_exn `Ddl_not_allowed_err)
  | Query { body; order_by; limit; offset; locking; _ } ->
      (* Rewrite the body; [scope_rw] is the (leftmost) select-core's scope, used to
         rewrite the query-level [order_by] (whose columns name the body's output). *)
      let body, scope_rw = rw_query_body ~rw body in
      let order_by = CCOption.map (rw_order_by ~rw:scope_rw) order_by in
      (Query { body; order_by; limit; offset; locking }, scope_rw)

(* Each select-core in the body -- in every UNION branch and every parenthesized
   sub-query -- is rewritten here, so its tables/columns/functions/casts are all
   schema-validated. UNION introduces no path to an unvalidated table. *)
and rw_query_body ~rw =
  let open Mql_ast in
  function
  | Select sc ->
      let sc, scope_rw = rw_select_core ~rw sc in
      (Select sc, scope_rw)
  | Paren q ->
      let q, scope_rw = rw_ast_scope ~rw q in
      (Paren q, scope_rw)
  | Set_op ({ left; right; _ } as so) ->
      let left, left_scope = rw_query_body ~rw left in
      let right, _ = rw_query_body ~rw right in
      (Set_op { so with left; right }, left_scope)

and rw_select_core ~rw select =
  let open Mql_ast in
  let { distinct; select_list; from; where; group_by; having } = select in
  let schema = rw.Rw.schema in
  (* The tables of the FROM clause, and the tables of each join that attaches to one of them. *)
  let from_tables = CCList.map (fun { fe_table; _ } -> fe_table) from in
  let joins = CCList.flat_map (fun { fe_joins; _ } -> fe_joins) from in
  let join_tables = CCList.map (fun { table; _ } -> table) joins in
  let tab_alias_to_table =
    (* Resolve each aliased table name to its schema table. An unknown table
       must raise [`Table_access_err] (a caught [Rw_exn]) -- using
       [String_map.find] here let an aliased unknown table escape as an
       uncaught [Not_found], surfacing as a 500 instead of a 400. *)
    String_map.map (fun table_name ->
        match String_map.find_opt table_name schema.Schema.tables with
        | Some table -> table
        | None -> raise (Rw_exn (`Table_access_err table_name)))
    @@ String_map.union
         (fun _ _ v -> Some v)
         (String_map.of_list
         @@ CCList.filter_map
              (function
                | Table_ref { name; alias = Some alias; _ } -> Some (alias.name, name.name)
                | Table_ref { alias = None; _ } -> None
                | Unnest _ | Derived_table _ | Func_table _ -> None)
              from_tables)
         (String_map.of_list
         @@ CCList.filter_map
              (function
                | { join_type = _; table = Table_ref { name; alias = Some alias; _ }; on_ = _ } ->
                    Some (alias.name, name.name)
                | _ -> None)
              joins)
  in
  let unnest_tables =
    String_map.of_list
    @@ CCList.filter_map
         (function
           | Unnest { alias; _ } | Derived_table { alias; _ } ->
               Some (alias.name, Schema.Table.make ~table_expr:true ~name:alias.name [])
           | Func_table { alias = Some alias; _ } ->
               Some (alias.name, Schema.Table.make ~table_expr:true ~name:alias.name [])
           | Func_table { alias = None; _ } | Table_ref _ -> None)
         (from_tables @ join_tables)
  in
  let tab_name_to_table =
    String_map.union (fun _ _ v -> Some v) unnest_tables
    @@ String_map.union (fun _ _ v -> Some v) tab_alias_to_table
    @@ String_map.union
         (fun _ _ v -> Some v)
         (String_map.of_list
         @@ CCList.filter_map
              (function
                | Table_ref { name; _ } -> (
                    match String_map.find_opt name.name schema.Schema.tables with
                    | Some table -> Some (name.name, table)
                    | None -> raise (Rw_exn (`Table_access_err name.name)))
                | Unnest _ | Derived_table _ | Func_table _ -> None)
              from_tables)
         (String_map.of_list
         @@ CCList.filter_map
              (function
                | { table = Table_ref { name; _ }; join_type = _; on_ = _ } -> (
                    match String_map.find_opt name.name schema.Schema.tables with
                    | Some table -> Some (name.name, table)
                    | None -> raise (Rw_exn (`Table_access_err name.name)))
                (* The other forms enter the scope through [unnest_tables]. *)
                | _ -> None)
              joins)
  in
  (* #2469: Only schema tables are recorded, not CTEs or unnests. Every name
     was validated above. *)
  CCList.iter
    (fun name ->
      match String_map.find_opt name schema.Schema.tables with
      | Some { Schema.Table.table_expr = false; _ }
        when not (CCList.mem ~eq:CCString.equal name rw.Rw.ctes) -> CCVector.push rw.Rw.tables name
      | Some _ | None -> ())
    (CCList.filter_map
       (function
         | Table_ref { name; _ } -> Some name.name
         | Unnest _ | Derived_table _ | Func_table _ -> None)
       (from_tables @ CCList.map (fun { table; _ } -> table) joins));
  let expr_to_col_alias = expr_to_col_alias select_list in
  let all_cols =
    String_map.fold
      (fun _ table acc ->
        String_map.fold
          (fun _ column acc ->
            String_map.add_to_list column.Schema.Column.name (table.Schema.Table.name, column) acc)
          table.Schema.Table.columns
          acc)
      tab_name_to_table
      String_map.empty
  in
  let dedupe =
    String_map.map (fun columns ->
        let module M = CCMap.Make (struct
          type t = string * string [@@deriving ord]
        end) in
        Iter.to_list
        @@ M.values
        @@ M.of_list
        @@ CCList.map
             (fun ((table_name, column) as v) -> ((table_name, column.Schema.Column.name), v))
             columns)
  in
  (* Correlation: the freshly-computed scope shadows, but does not erase, the
     enclosing query's scope. For a top-level / CTE-definition query the incoming
     maps are empty, so this is a no-op there; for an In_query/Exists subquery the
     incoming maps are the enclosing select's scope, so correlated references
     resolve. The subquery's own tables are still validated against [rw.schema]. *)
  let correlated_tab_name_to_table =
    String_map.union (fun _ _outer inner -> Some inner) rw.Rw.tab_name_to_table tab_name_to_table
  in
  let aliases =
    Col_expr_map.fold
      (fun expr alias acc ->
        match expr with
        | Col_expr.Id col ->
            String_map.add
              alias
              (CCOption.get_or ~default:[] @@ String_map.find_opt col all_cols)
              acc
        | Col_expr.Field (tab, col) -> (
            (* The correlated scope, not the local one: the select list of a
               subquery can name a table of the enclosing query ([t.c as a]),
               and the alias then stands for the outer column. *)
            match String_map.find_opt tab correlated_tab_name_to_table with
            | Some tab ->
                CCOption.map_or ~default:acc (fun column ->
                    String_map.add_to_list col (tab.Schema.Table.name, column) acc)
                @@ String_map.find_opt col tab.Schema.Table.columns
            | None ->
                (* No scope names [tab].  The select list is validated after
                   this fold, so such a query is refused below; leave the alias
                   out and let that refusal happen. *)
                acc)
        | Col_expr.Count_star ->
            (* A count-star output column aliased as [alias]. Record the
               alias with an empty column list so that referring to it
               (e.g. in an order-by) resolves instead of raising
               [`Unknown_column_err] now that bare identifiers are
               validated. *)
            String_map.add alias [] acc)
      expr_to_col_alias
      String_map.empty
  in
  (* The alias of each other expression names an output column of unknown
     type. *)
  let aliases =
    String_map.fold
      (fun alias _ acc -> if String_map.mem alias acc then acc else String_map.add alias [] acc)
      (col_alias_to_expr select_list)
      aliases
  in
  (* A column alias names an output column, not a column of a table.
     PostgreSQL reads it only in [GROUP BY], [DISTINCT ON] and [ORDER BY], thus
     the other clauses get the scope without the aliases. *)
  let col_name_to_columns = dedupe all_cols in
  let alias_col_name_to_columns =
    dedupe @@ String_map.union (fun _ v1 v2 -> Some (v1 @ v2)) aliases all_cols
  in
  let own_tables = tab_name_to_table in
  (* The correlated scope, computed above for the alias fold. *)
  let tab_name_to_table = correlated_tab_name_to_table in
  let scope col_name_to_columns =
    {
      rw with
      Rw.schema;
      col_name_to_columns =
        String_map.union
          (fun _ _outer inner -> Some inner)
          rw.Rw.col_name_to_columns
          col_name_to_columns;
      tab_name_to_table;
    }
  in
  let alias_rw = scope alias_col_name_to_columns in
  let rw = scope col_name_to_columns in
  let select =
    {
      (* [DISTINCT ON]'s expressions are rewritten like any others, so their
         literals are parameterised and their columns schema-checked. *)
      distinct =
        CCOption.map
          (function
            | Distinct -> Distinct
            | Distinct_on es -> Distinct_on (CCList.map (rw_expr ~rw:alias_rw) es))
          distinct;
      select_list = rw_select_list ~rw select_list;
      from = rw_from ~rw from;
      where = CCOption.map (rw_where ~rw) where;
      group_by = CCOption.map (rw_group_by ~rw:alias_rw) group_by;
      having = CCOption.map (rw_having ~rw) having;
    }
  in
  let output = select_output ~rw ~own_tables ~sources:(from_tables @ join_tables) select_list in
  (select, { alias_rw with Rw.output })

(* The columns that a select makes.  A named column gets the type of the
   column it reads; each other column gets an unknown type.  A star makes the
   columns of each source, thus a star over a source with unknown columns
   makes unknown output. *)
and select_output ~rw ~own_tables ~sources =
  let open Mql_ast in
  function
  | Star ->
      CCList.fold_left
        (fun acc source ->
          match (acc, source) with
          | None, _ -> None
          | Some columns, Table_ref { name; alias; _ } -> (
              let key =
                CCOption.map_or ~default:name.name (fun { Mql_ast.name; quoted = _ } -> name) alias
              in
              match String_map.find_opt key own_tables with
              | Some { Schema.Table.table_expr = false; columns = table_columns; _ } ->
                  Some (columns @ CCList.map snd (String_map.to_list table_columns))
              | Some { Schema.Table.table_expr = true; _ } | None -> None)
          | Some _, (Unnest _ | Derived_table _ | Func_table _) -> None)
        (Some [])
        sources
  | Columns cols ->
      Some
        (CCList.map
           (fun { expr; alias } ->
             let name =
               CCOption.map_or
                 ~default:(output_name expr)
                 (fun { Mql_ast.name; quoted = _ } -> name)
                 alias
             in
             let type_ =
               CCOption.get_or ~default:(Schema.Column.Type_.Complex "unknown")
               @@ identifier_type ~rw expr
             in
             Schema.Column.make ~name ~type_ ())
           cols)

let mk_rw ~func_allow_list ~cast_allow_list schema =
  {
    Rw.texts = CCVector.create ();
    timestamptzs = CCVector.create ();
    json = CCVector.create ();
    smallints = CCVector.create ();
    integers = CCVector.create ();
    bigints = CCVector.create ();
    floats = CCVector.create ();
    tables = CCVector.create ();
    func_allow_list;
    cast_allow_list;
    schema;
    ctes = [];
    col_name_to_columns = String_map.empty;
    tab_name_to_table = String_map.empty;
    output = None;
  }

let rec rw_limit ~max_limit =
  let open Mql_ast in
  function
  | With w -> With { w with body = rw_limit ~max_limit w.body }
  | Insert _ | Update _ | Delete _ -> raise (Rw_exn `Data_modifying_not_allowed_err)
  | Create_table _
  | Create_index _
  | Create_view _
  | Create_function _
  | Alter_function_set _
  | Alter_table _
  | Drop _
  | Comment_on _
  | Truncate _
  | Analyze _
  | Create_trigger _
  | Create_extension _
  | Set_stmt _
  | Set_constraints _
  | Grant _
  | Create_role _
  | Create_database _
  | Lock_table _ -> raise (Rw_exn `Ddl_not_allowed_err)
  | Query { body; order_by; limit; offset; locking; _ } ->
      let limit =
        match limit with
        | None -> max_limit
        | Some (Int i) -> CCInt.min max_limit i
        (* [max_limit] is a cap the caller relies on, so a limit whose value is
           not visible here is refused rather than passed through uncapped.
           Unreachable via [of_string]; reachable from a hand-built AST. *)
        | Some e ->
            raise
              (Rw_exn
                 (`Variable_err
                    (CCResult.get_or ~default:(Mql_ast.show_expr e) @@ Mql.Ast.expr_to_string e)))
      in
      Query { body; order_by; limit = Some (Int limit); offset; locking }

(* The parameter vectors [rw_lit_*] emits. They are this module's own names, not
   anything a caller wrote, and [Pgsql_io]'s named-variable substitution resolves
   them -- so the audit recognises them rather than rejecting them for failing
   [audit_valid_name], which no name starting with [$] can pass. *)
let emitted_param_names =
  [ "$bigints"; "$floats"; "$integers"; "$json"; "$smallints"; "$texts"; "$timestamptzs" ]

(* What the audit reads: the inputs of [of_mql], not the state of the rewrite. *)
type audit_env = {
  tables : Schema.Table.t String_map.t;
  func_allow_list : string list;
  cast_allow_list : string list;
}

(* The audit's own character set check: a letter or [_], then letters, digits
   and [_]. *)
let audit_valid_name name =
  let letter c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_' in
  let letter_or_digit c = letter c || (c >= '0' && c <= '9') in
  String.length name > 0 && letter name.[0] && String.for_all letter_or_digit name

(* Post-condition audit (defense in depth).

   Re-derives the safety guarantee from the query [of_mql] is about to return,
   instead of trusting that every guard above fired: every table is in the schema
   or is a CTE bound by this query, every function is in [func_allow_list], every
   cast is in [cast_allow_list], every identifier is in-charset, and no [$name]
   variable survived.

   The point is that this does NOT share code with the guards. A new AST
   constructor whose handling in [rw_expr] or [check_identifiers_ast] forgets a
   check still has to get past this walk, which fails closed on anything it does
   not recognise.

   Columns are deliberately NOT re-checked here. Column scope is resolved
   thoroughly by [lookup_col_type], and a column that is not projected by the
   caller's schema is a SQL error rather than a disclosure -- the wrapper CTEs in
   [select_mql_page.sql] project a fixed column list, so an unprojected name
   cannot resolve to anything. Names of tables, functions and casts are the
   disclosure surface, and those are what this checks. *)
let audit_identifier { Mql_ast.name; quoted = _ } =
  if not (audit_valid_name name || CCList.mem ~eq:CCString.equal name emitted_param_names) then
    raise (Audit_exn (`Audit_identifier_err name))

let rec audit_ast ~env ~ctes =
  let open Mql_ast in
  function
  (* A recursive CTE reads itself, thus the table check cannot bound what it
     reads. *)
  | With { recursive = true; _ } -> raise (Audit_exn (`Audit_construct_err "with recursive"))
  | With { columns = _ :: _; _ } -> raise (Audit_exn (`Audit_construct_err "a CTE column list"))
  | With { name; query; body; _ } ->
      audit_identifier name;
      (* A CTE cannot see itself: audit its body in the scope that excludes it,
         matching [rw_ast]'s treatment. *)
      audit_ast ~env ~ctes query;
      audit_ast ~env ~ctes:(name.name :: ctes) body
  | Insert _ | Update _ | Delete _ -> raise (Audit_exn `Audit_data_modifying_err)
  | Create_table _
  | Create_index _
  | Create_view _
  | Create_function _
  | Alter_function_set _
  | Alter_table _
  | Drop _
  | Comment_on _
  | Truncate _
  | Analyze _
  | Create_trigger _
  | Create_extension _
  | Set_stmt _
  | Set_constraints _
  | Grant _
  | Create_role _
  | Create_database _
  | Lock_table _ -> raise (Audit_exn `Audit_ddl_err)
  | Query { body; order_by; limit; offset; locking } ->
      (* The audit is a standalone second opinion over any AST, including one no
         parser would produce (see {!Tests.audit_query}).  The rewrite emits no row
         lock, and a locking clause carries table names in [of_], so [Some _]
         can only mean the AST did not come from the rewrite -- refuse it. *)
      (match locking with
      | Some _ -> raise (Audit_exn `Audit_locking_err)
      | None -> ());
      audit_query_body ~env ~ctes body;
      CCOption.iter
        (CCList.iter (fun { Mql_ast.ob_expr; _ } -> audit_expr ~env ~ctes ob_expr))
        order_by;
      CCOption.iter (audit_expr ~env ~ctes) offset;
      CCOption.iter (audit_expr ~env ~ctes) limit

and audit_query_body ~env ~ctes =
  let open Mql_ast in
  function
  | Select { distinct; select_list; from; where; group_by; having } ->
      (match distinct with
      | None | Some Mql_ast.Distinct -> ()
      | Some (Mql_ast.Distinct_on es) -> CCList.iter (audit_expr ~env ~ctes) es);
      audit_select_list ~env ~ctes select_list;
      CCList.iter
        (fun { fe_table; fe_joins } ->
          audit_table_ref ~env ~ctes fe_table;
          CCList.iter
            (fun { join_type = _; table; on_ } ->
              audit_table_ref ~env ~ctes table;
              match on_ with
              | On e -> audit_expr ~env ~ctes e
              | Using cs -> CCList.iter audit_identifier cs
              | No_cond -> ())
            fe_joins)
        from;
      CCOption.iter (audit_expr ~env ~ctes) where;
      CCOption.iter
        (function
          | Group_exprs es -> CCList.iter (audit_expr ~env ~ctes) es
          | Group_sets _ -> raise (Audit_exn (`Audit_construct_err "grouping sets")))
        group_by;
      CCOption.iter (audit_expr ~env ~ctes) having
  | Set_op { left; right; _ } ->
      audit_query_body ~env ~ctes left;
      audit_query_body ~env ~ctes right
  | Paren q -> audit_ast ~env ~ctes q

and audit_select_list ~env ~ctes =
  let open Mql_ast in
  function
  | Star -> ()
  | Columns cols ->
      CCList.iter
        (fun { expr; alias } ->
          audit_expr ~env ~ctes expr;
          CCOption.iter audit_identifier alias)
        cols

and audit_table_ref ~env ~ctes =
  let open Mql_ast in
  function
  | Table_ref t -> audit_table ~env ~ctes t
  | Unnest { exprs; alias; columns } ->
      if not (CCList.is_empty columns) then
        raise (Audit_exn (`Audit_construct_err "column alias list"));
      (match exprs with
      | [ _ ] -> ()
      | _ -> raise (Audit_exn (`Audit_construct_err "unnest of more than one array")));
      CCList.iter (audit_expr ~env ~ctes) exprs;
      audit_identifier alias
  (* The derived query is audited in full, so its tables must still be in the
     schema -- a derived table is not a way to name something new. *)
  | Derived_table { query; alias; columns; lateral_ } ->
      if lateral_ then raise (Audit_exn (`Audit_construct_err "lateral"));
      if not (CCList.is_empty columns) then
        raise (Audit_exn (`Audit_construct_err "column alias list"));
      audit_ast ~env ~ctes query;
      audit_identifier alias
  (* A call makes columns that the schema does not contain.  Thus no check that
     reads the schema can examine the data that the query reads. *)
  | Func_table _ -> raise (Audit_exn (`Audit_construct_err "a call in a from clause"))

(* The disclosure control: a table name must resolve to the caller's schema or to
   a CTE this query binds. A schema-qualified name reaches here whole and matches
   neither, which is exactly how [from public.resources] is refused. *)
and audit_table ~env ~ctes { Mql_ast.table_qualifier; name; alias } =
  let table_name = name.Mql_ast.name in
  (* A schema before a name gives access to data outside the tenant-scoped copies of
     the tables that the query is substituted into. *)
  (match table_qualifier with
  | Some q -> raise (Audit_exn (`Audit_table_err (q.Mql_ast.name ^ "." ^ table_name)))
  | None -> ());
  audit_identifier name;
  CCOption.iter audit_identifier alias;
  if not (String_map.mem table_name env.tables || CCList.mem ~eq:CCString.equal table_name ctes)
  then raise (Audit_exn (`Audit_table_err table_name))

and audit_expr ~env ~ctes =
  let open Mql_ast in
  function
  | Identifier id -> audit_identifier id
  | Field_select (e, field) ->
      audit_expr ~env ~ctes e;
      audit_identifier field
  | Func ({ qualifier; name; args; _ } as f) -> (
      (match qualifier with
      | Some q -> raise (Audit_exn (`Audit_construct_err ("schema-qualified call " ^ q.name)))
      | None -> ());
      if not (Sln_list.String.mem (folded_name name) env.func_allow_list) then
        raise (Audit_exn (`Audit_func_err name.name));
      (* A decoration of a call: a window, a sort order or a filter. *)
      if f.distinct then raise (Audit_exn (`Audit_construct_err "distinct"));
      if CCOption.is_some f.agg_order_by then raise (Audit_exn (`Audit_construct_err "order by"));
      if CCOption.is_some f.filter then raise (Audit_exn (`Audit_construct_err "filter"));
      if CCOption.is_some f.over then raise (Audit_exn (`Audit_construct_err "over"));
      match args with
      | Func_star -> ()
      | Func_exprs args ->
          CCList.iter
            (function
              | Arg_named _ -> raise (Audit_exn (`Audit_construct_err "a named argument"))
              | Arg e -> audit_expr ~env ~ctes e)
            args)
  (* The allow list holds plain type names, thus only a plain target can
     match. *)
  | Cast
      ( e,
        {
          type_ident = { qualifier = None; base };
          type_extra = No_extra;
          args = [];
          array_dims = 0;
        } ) ->
      audit_expr ~env ~ctes e;
      if not (Sln_list.String.mem (folded_name base) env.cast_allow_list) then
        raise (Audit_exn (`Audit_cast_err base.name))
  | Cast (_, _) -> raise (Audit_exn (`Audit_construct_err "a cast target that is not a plain name"))
  | Variable v -> raise (Audit_exn (`Audit_variable_err v))
  | Exists q -> audit_ast ~env ~ctes q
  | In_query (e, q) ->
      audit_expr ~env ~ctes e;
      audit_ast ~env ~ctes q
  (* [_path] is a string literal operand of [#>>], escaped at render time, not an
     identifier -- the same reasoning as [check_identifiers_expr]. *)
  | Json_obj_query (e, _path) -> audit_expr ~env ~ctes e
  | Add (e1, e2)
  | And (e1, e2)
  | Concat (e1, e2)
  | Div (e1, e2)
  | Eq (e1, e2)
  | Gt (e1, e2)
  | Gte (e1, e2)
  | Ilike (e1, e2)
  | Index (e1, e2)
  | Is (e1, e2)
  | Is_distinct_from (e1, e2)
  | Is_not (e1, e2)
  | Is_not_distinct_from (e1, e2)
  | Json_subset (e1, e2)
  | Json_text (e1, e2)
  | Json_val (e1, e2)
  | Like (e1, e2)
  | Lt (e1, e2)
  | Lte (e1, e2)
  | Mult (e1, e2)
  | Not_eq (e1, e2)
  | Not_ilike (e1, e2)
  | Not_like (e1, e2)
  | Or (e1, e2)
  | Sub (e1, e2) ->
      audit_expr ~env ~ctes e1;
      audit_expr ~env ~ctes e2
  | In (e, tuple) ->
      audit_expr ~env ~ctes e;
      CCList.iter (audit_expr ~env ~ctes) tuple
  | Tuple tuple -> CCList.iter (audit_expr ~env ~ctes) tuple
  | Not_in (e, tuple) ->
      audit_expr ~env ~ctes e;
      CCList.iter (audit_expr ~env ~ctes) tuple
  | Not_in_query (e, q) ->
      audit_expr ~env ~ctes e;
      audit_ast ~env ~ctes q
  | At_time_zone (e1, e2) | Regex_match (e1, e2) | Regex_not_match (e1, e2) ->
      audit_expr ~env ~ctes e1;
      audit_expr ~env ~ctes e2
  | Json_obj_val (e, _path) -> audit_expr ~env ~ctes e
  | Interval _ -> ()
  | Case { operand; branches; else_ } ->
      CCOption.iter (audit_expr ~env ~ctes) operand;
      CCList.iter
        (fun (c, v) ->
          audit_expr ~env ~ctes c;
          audit_expr ~env ~ctes v)
        branches;
      CCOption.iter (audit_expr ~env ~ctes) else_
  | Negate e | Not e -> audit_expr ~env ~ctes e
  | False | True | Null | Float _ | Int _ | String _ -> ()
  (* The rewriter refused each of these.  The audit refuses them a second time.
     Thus one error does not permit one to pass. *)
  | Scalar_subquery _ -> raise (Audit_exn (`Audit_construct_err "a query in an expression"))
  | Qualified_star _ -> raise (Audit_exn (`Audit_construct_err "a star on a name"))
  | Array_lit _ -> raise (Audit_exn (`Audit_construct_err "an array"))
  | Array_query _ -> raise (Audit_exn (`Audit_construct_err "an array from a query"))
  | Json_has_key _ -> raise (Audit_exn (`Audit_construct_err "the ? operator"))
  | Like_escape _ -> raise (Audit_exn (`Audit_construct_err "like with an escape"))
  | Extract _ -> raise (Audit_exn (`Audit_construct_err "extract"))
  | Substring_from _ -> raise (Audit_exn (`Audit_construct_err "substring from"))
  | Position_in _ -> raise (Audit_exn (`Audit_construct_err "position in"))
  | Mod _ -> raise (Audit_exn (`Audit_construct_err "the % operator"))
  | Slice _ -> raise (Audit_exn (`Audit_construct_err "a part of an array"))
  | Regex_imatch _ -> raise (Audit_exn (`Audit_construct_err "the ~* operator"))
  | Regex_not_imatch _ -> raise (Audit_exn (`Audit_construct_err "the !~* operator"))
  | Collate _ -> raise (Audit_exn (`Audit_construct_err "collate"))
  | Bit_and _ -> raise (Audit_exn (`Audit_construct_err "the & operator"))
  | Json_obj_val_path _ | Json_obj_query_path _ ->
      raise (Audit_exn (`Audit_construct_err "a json path that is not a literal"))

let audit ~env query =
  try
    audit_ast ~env ~ctes:[] query;
    Ok ()
  with Audit_exn (#audit_err as err) -> Error err

let audit_query ~func_allow_list ~cast_allow_list ~schema query =
  audit ~env:{ tables = schema.Schema.tables; func_allow_list; cast_allow_list } query

(* The test hook of the [Tests] submodule: the same audit that [of_mql] runs over its own output,
   exposed so a test can put an AST in front of it directly. *)
module Tests = struct
  let audit_query = audit_query
end

let of_mql ?(max_limit = 20) ~func_allow_list ~cast_allow_list ~schema ast =
  let open CCResult.Infix in
  (try
     (* Fail closed on any out-of-charset identifier before doing anything
        else; see [check_identifiers_ast]. *)
     check_identifiers_ast ast;
     let rw = mk_rw ~func_allow_list ~cast_allow_list schema in
     let query = rw_limit ~max_limit @@ rw_ast ~rw ast in
     Ok (query, rw)
   with Rw_exn (#of_mql_err as err) -> Error err)
  >>= fun (query, rw) ->
  (* Re-derive the guarantee from the output before handing it back.  The audit
     gets the inputs of this function, not the state of the rewrite. *)
  audit_query ~func_allow_list ~cast_allow_list ~schema query >|= fun () -> { query; rw }

let assert_order_by_cols_can_paginate order_by =
  let module A = Mql_ast in
  let open CCResult.Infix in
  CCResult.map_l
    (function
      | { A.ob_expr = A.Identifier _; _ } | { A.ob_expr = A.Field_select _; _ } -> Ok ()
      | { A.ob_expr; _ } when is_plain_count_star ob_expr -> Ok ()
      | { A.ob_expr; _ } -> Error (`Order_by_col_not_identifier_err ob_expr))
    order_by
  >>= fun _ -> Ok ()

(* One cursor component: the row's value for [expr], keyed by its select-list
   alias when it has one and by the bare column name otherwise. *)
let lookup_col_in_row expr_to_col_alias expr col row =
  let scalar key = function
    | (`Null | `String _ | `Int _ | `Float _) as v -> Ok (key, v)
    | v -> Error (`Cursor_value_not_scalar_err (key, v))
  in
  let by_col () =
    match CCList.Assoc.get ~eq:CCString.equal col @@ Yojson.Safe.Util.to_assoc row with
    | Some v -> scalar col v
    | None -> Error (`Column_not_in_row_err col)
  in
  match Col_expr_map.find_opt expr expr_to_col_alias with
  | Some alias -> (
      match CCList.Assoc.get ~eq:CCString.equal alias @@ Yojson.Safe.Util.to_assoc row with
      | Some v -> scalar alias v
      | None -> by_col ())
  | None -> by_col ()

let mk_cursor expr_to_col_alias row order_by =
  let module A = Mql_ast in
  let open CCResult.Infix in
  CCResult.map_l
    (function
      | { A.ob_expr = A.Identifier col; _ } ->
          lookup_col_in_row expr_to_col_alias (Col_expr.Id col.A.name) col.A.name row
      | { A.ob_expr = A.Field_select (A.Identifier table, col); _ } ->
          lookup_col_in_row
            expr_to_col_alias
            (Col_expr.Field (table.A.name, col.A.name))
            col.A.name
            row
      | { A.ob_expr; _ } when is_plain_count_star ob_expr ->
          lookup_col_in_row expr_to_col_alias Col_expr.Count_star "count" row
      (* [assert_order_by_cols_can_paginate] runs before every caller, so this is
         unreachable -- but it is the ONLY thing making it so. Report rather than
         assert: a new orderable construct that slips past that gate must not be
         able to crash a request. *)
      | { A.ob_expr; _ } -> Error (`Order_by_col_not_identifier_err ob_expr))
    order_by
  >>= fun cursor -> Ok (`Assoc cursor)

(* Walk past any leading [With] CTEs to the [Query], returning its body and order_by. *)
let rec query_parts = function
  | Mql_ast.With { body; _ } -> query_parts body
  | Mql_ast.Query { body; order_by; _ } -> Some (body, order_by)
  (* A data-modifying statement has no page. [of_mql] refused it long before
     this, so [pages] never sees one -- but there is no query body to report
     either, which is what [None] says. *)
  | Mql_ast.Insert _
  | Mql_ast.Update _
  | Mql_ast.Delete _
  | Mql_ast.Create_table _
  | Mql_ast.Create_index _
  | Mql_ast.Create_view _
  | Mql_ast.Create_function _
  | Mql_ast.Alter_function_set _
  | Mql_ast.Alter_table _
  | Mql_ast.Drop _
  | Mql_ast.Comment_on _
  | Mql_ast.Truncate _
  | Mql_ast.Analyze _
  | Mql_ast.Create_trigger _
  | Mql_ast.Create_extension _
  | Mql_ast.Set_stmt _
  | Mql_ast.Set_constraints _
  | Mql_ast.Grant _
  | Mql_ast.Create_role _
  | Mql_ast.Create_database _
  | Mql_ast.Lock_table _ -> None

let pages results t =
  let module A = Mql_ast in
  match results with
  | [] -> Ok None
  | results -> (
      let min_row = CCList.hd results in
      let max_row = CCList.hd @@ CCList.rev results in
      match query_parts t.query with
      | None -> Ok None
      (* A DISTINCT query is not keyset-paginable (see [apply_page]), so no
         cursor is offered for it at all -- the caller is told it cannot page
         rather than handed a cursor that would later be refused. *)
      | Some (A.Select { A.distinct = Some _; _ }, _) -> Ok None
      | Some (A.Select { A.select_list; _ }, Some order_by) ->
          let open CCResult.Infix in
          assert_order_by_cols_can_paginate order_by
          >>= fun () ->
          let expr_to_col_alias = expr_to_col_alias select_list in
          mk_cursor expr_to_col_alias min_row order_by
          >>= fun min_cursor ->
          mk_cursor expr_to_col_alias max_row order_by
          >>= fun max_cursor ->
          Ok
            (Some
               {
                 Pages.prev = { Page.dir = Page.Negate; cursor = min_cursor };
                 next = { Page.dir = Page.Affirm; cursor = max_cursor };
               })
      (* No order_by, or a UNION / parenthesized body -- not paginable. *)
      | _ -> Ok None)

(* Look up the cursor value for [col] and return it as an AST literal. *)
let mk_page_value page col =
  match CCList.Assoc.get ~eq:CCString.equal col @@ Yojson.Safe.Util.to_assoc page.Page.cursor with
  | None -> Error (`Missing_cursor_col_err col)
  | Some `Null -> Ok Mql_ast.Null
  | Some (`String s) -> Ok (Mql_ast.String s)
  | Some (`Float fl) -> Ok (Mql_ast.Float fl)
  | Some (`Int i) -> Ok (Mql_ast.Int i)
  | Some ((`Bool _ | `Intlit _ | `Assoc _ | `List _) as v) -> Error (`Page_invalid_type_err v)

(* Keyset (lexicographic) pagination predicate over the whole ORDER BY tuple.

   For ORDER BY c1, c2, ..., cn going forward this is the standard OR-expansion

     c1 > v1
     OR (c1 = v1 AND c2 > v2)
     OR (c1 = v1 AND c2 = v2 AND ... AND cn >= vn)

   -- a true lexicographic comparison, NOT the flat [c1 >= v1 AND c2 >= v2 ...]
   conjunction, which under-selects whenever a trailing column is not monotonic
   across the leading one (e.g. instances.address restarting per state).  The
   final column stays inclusive (>=/<=) so the cursor row is re-selected and
   then dropped by the endpoint's [trim_rows]; every earlier column is strict.

   Direction is per-column: [greater] combines the page direction (Affirm /
   Negate) with the column's own Asc/Desc.  Equality links use [IS NULL] for a
   null cursor value and plain [=] otherwise, so a NULL in a leading order
   column chains (as [ck IS NULL]) instead of annihilating the conjunction,
   while non-null links stay index-friendly. *)
let lex_keyset page_dir cols =
  let module A = Mql_ast in
  let greater dir =
    match (page_dir, dir) with
    | Page.Affirm, (None | Some A.Asc) | Page.Negate, Some A.Desc -> true
    | Page.Affirm, Some A.Desc | Page.Negate, (None | Some A.Asc) -> false
  in
  let strict expr value dir = if greater dir then A.Gt (expr, value) else A.Lt (expr, value) in
  let inclusive expr value dir = if greater dir then A.Gte (expr, value) else A.Lte (expr, value) in
  let equal expr = function
    | A.Null -> A.Is (expr, A.Null)
    | value -> A.Eq (expr, value)
  in
  let n = CCList.length cols in
  let term k (expr, value, dir) =
    let cmp = if k = n - 1 then inclusive expr value dir else strict expr value dir in
    CCList.take k cols
    |> CCListLabels.fold_right ~init:cmp ~f:(fun (e, v, _) acc -> A.And (equal e v, acc))
  in
  match CCList.mapi term cols with
  | [] -> None
  | t :: ts -> Some (CCListLabels.fold_left ~init:t ~f:(fun acc t -> A.Or (acc, t)) ts)

(* Resolve one ORDER BY entry to [(expr, cursor_value, dir, is_aggregate)].
   [expr] is the SQL expression the keyset comparison runs against; the cursor
   value is keyed exactly as [mk_cursor] stored it.  [is_aggregate] marks
   count-star columns, which can only be compared in HAVING. *)
let order_col_term col_alias_to_expr expr_to_col_alias page { Mql_ast.ob_expr; ob_order = dir; _ } =
  let module A = Mql_ast in
  let open CCResult.Infix in
  match ob_expr with
  | A.Identifier col -> (
      let key = col.A.name in
      match String_map.find_opt key col_alias_to_expr with
      | Some expr when is_plain_count_star expr ->
          mk_page_value page key >>= fun v -> Ok (expr, v, dir, true)
      | Some expr -> mk_page_value page key >>= fun v -> Ok (expr, v, dir, false)
      | None -> mk_page_value page key >>= fun v -> Ok (A.Identifier col, v, dir, false))
  | A.Field_select (A.Identifier _table, col) as expr ->
      mk_page_value page col.A.name >>= fun v -> Ok (expr, v, dir, false)
  | expr when is_plain_count_star expr ->
      let key =
        match Col_expr_map.find_opt Col_expr.Count_star expr_to_col_alias with
        | Some alias -> alias
        | None -> "count"
      in
      mk_page_value page key >>= fun v -> Ok (expr, v, dir, true)
  (* Unreachable for the same reason as [mk_cursor]'s arm above, and refused for
     the same reason. *)
  | e -> Error (`Order_by_col_not_identifier_err e)

(* The keyset predicate over the whole ORDER BY tuple, plus whether any ordered
   column is an aggregate (which forces the predicate into HAVING). *)
let mk_keyset_cond col_alias_to_expr expr_to_col_alias page order_by =
  let open CCResult.Infix in
  CCResult.map_l (order_col_term col_alias_to_expr expr_to_col_alias page) order_by
  >>= fun terms ->
  let has_aggregate = CCList.exists (fun (_, _, _, agg) -> agg) terms in
  let cols = CCList.map (fun (expr, value, dir, _) -> (expr, value, dir)) terms in
  Ok (lex_keyset page.Page.dir cols, has_aggregate)

let negate_dir = function
  | None | Some Mql_ast.Asc -> Some Mql_ast.Desc
  | Some Mql_ast.Desc -> Some Mql_ast.Asc

let apply_page_dir order_by = function
  | Page.Affirm -> order_by
  | Page.Negate ->
      CCList.map
        (fun ({ Mql_ast.ob_order; _ } as item) ->
          { item with Mql_ast.ob_order = negate_dir ob_order })
        order_by

let rec apply_page page t =
  let module A = Mql_ast in
  match t with
  | A.With { materialized; recursive; name; columns; query; body } ->
      CCResult.map
        (fun body -> A.With { materialized; recursive; name; columns; query; body })
        (apply_page page body)
  | A.Query
      {
        body = A.Select ({ A.distinct; select_list; from = _; where; group_by; having } as select);
        order_by = Some order_by;
        limit;
        offset;
        locking;
      } -> (
      let open CCResult.Infix in
      (* Keyset pagination is unsound over DISTINCT. The keyset predicate is
         ANDed into WHERE (or HAVING), which PostgreSQL evaluates BEFORE the
         dedup -- so the cursor names a row of the pre-dedup result, while the
         caller saw a row of the post-dedup one. Paging from it skips or repeats
         rows. Refuse rather than return a wrong page; [pages] correspondingly
         never offers a cursor for such a query. *)
      (match distinct with
        | None -> Ok ()
        | Some _ -> Error `Distinct_cannot_paginate_err)
      >>= fun () ->
      assert_order_by_cols_can_paginate order_by
      >>= fun () ->
      let col_alias_to_expr = col_alias_to_expr select_list in
      let expr_to_col_alias = expr_to_col_alias select_list in
      mk_keyset_cond col_alias_to_expr expr_to_col_alias page order_by
      >>= fun (keyset, has_aggregate) ->
      let order_by = apply_page_dir order_by page.Page.dir in
      match keyset with
      | None ->
          Ok (A.Query { body = A.Select select; order_by = Some order_by; limit; offset; locking })
      | Some keyset when has_aggregate -> (
          (* An aggregate in the ORDER BY forces the whole keyset into HAVING:
             WHERE cannot see aggregates, and a lexicographic OR-expansion cannot
             be split across the WHERE/HAVING boundary without reintroducing the
             flat-conjunction defect. *)
          match group_by with
          | None -> Error `Missing_group_by_err
          | Some _ ->
              let having =
                Some (CCOption.map_or ~default:keyset (fun having -> A.And (keyset, having)) having)
              in
              Ok
                (A.Query
                   {
                     body = A.Select { select with A.having };
                     order_by = Some order_by;
                     limit;
                     offset;
                     locking;
                   }))
      | Some keyset ->
          let where =
            Some (CCOption.map_or ~default:keyset (fun where -> A.And (keyset, where)) where)
          in
          Ok
            (A.Query
               {
                 body = A.Select { select with A.where };
                 order_by = Some order_by;
                 limit;
                 offset;
                 locking;
               }))
  | A.Query { body = A.Select _; order_by = None; _ } -> Error `Missing_order_by_err
  (* Keyset pagination of a UNION / parenthesized query would need a derived table to
     hang the WHERE off of -- out of scope. *)
  | A.Query { body = A.Set_op _ | A.Paren _; _ } -> Error `Missing_order_by_err
  (* A data-modifying statement has no page to apply. Unreachable -- [of_mql]
     refuses these -- but reported rather than left to a partial match. *)
  | A.Insert _
  | A.Update _
  | A.Delete _
  | A.Create_table _
  | A.Create_index _
  | A.Create_view _
  | A.Create_function _
  | A.Alter_function_set _
  | A.Alter_table _
  | A.Drop _
  | A.Comment_on _
  | A.Truncate _
  | A.Analyze _
  | A.Create_trigger _
  | A.Create_extension _
  | A.Set_stmt _
  | A.Set_constraints _
  | A.Grant _
  | A.Create_role _
  | A.Create_database _
  | A.Lock_table _ -> Error `Missing_order_by_err

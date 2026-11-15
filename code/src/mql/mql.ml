(* Constructs that are unsafe to accept from an untrusted source.

   Same posture as [Ast.of_string]'s [variables]: absent by default, and a
   caller has to name one to get it. The endpoint names none, so it cannot parse
   any of these at all -- which is the first of the two gates. The second is
   [Mql_to_pgsql.of_mql], which refuses them independently even when parsing was
   allowed to produce them. *)
module Feature = struct
  type t =
    | Data_modifying  (** [INSERT] / [UPDATE] / [DELETE], and a CTE that is one *)
    | Locking_clause  (** [FOR UPDATE] and friends *)
    | Ddl  (** [CREATE] / [ALTER] / [DROP] and the other schema statements *)
  [@@deriving show, eq]

  let all = [ Data_modifying; Locking_clause; Ddl ]
end

module Ast = struct
  module M = Mql_ast

  type t = Mql_ast.t [@@deriving show, eq]

  type pos = {
    lnum : int;
    offset : int;
  }
  [@@deriving show, eq]

  type err = [ `Error of pos option * string * string ] [@@deriving show, eq]

  let rec limit t =
    let open Mql_ast in
    match t with
    | With { body; query = _; materialized = _; recursive = _; name = _; columns = _ } -> limit body
    | Query { limit = Some (Int i); body = _; order_by = _; offset = _; locking = _ } -> Some i
    (* A [$name] limit has no statically known value, and a data-modifying
       statement has no LIMIT at all. *)
    | Query _ | Insert _ | Update _ | Delete _ -> None
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
    | Lock_table _ -> None

  let rec set_limit limit t =
    let open Mql_ast in
    match t with
    | With f -> With { f with body = set_limit limit f.body }
    | Query f -> Query { f with limit = Some (Int limit) }
    (* Nothing to set a LIMIT on. *)
    | (Insert _ | Update _ | Delete _) as t -> t
    | ( Create_table _
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
      | Lock_table _ ) as t -> t

  let state checkpoint =
    let module I = Mql_parser.MenhirInterpreter in
    match I.top checkpoint with
    | None -> 0
    | Some (I.Element (s, _, _, _)) -> I.number s

  let position checkpoint =
    let module I = Mql_parser.MenhirInterpreter in
    match I.top checkpoint with
    | None -> None
    | Some (I.Element (_, _, { Lexing.pos_lnum; pos_bol; pos_cnum = _; pos_fname = _ }, _)) ->
        Some { lnum = pos_lnum; offset = pos_bol }

  (* Very useful for debugging *)
  (* let print_token (token, _, _) = *)
  (*   let open Mql_parser in *)
  (*   print_endline *)
  (*   @@ *)
  (*   match token with *)
  (*   | AND -> "and" *)
  (*   | AS -> "as" *)
  (*   | ASC -> "asc" *)
  (*   | BY -> "by" *)
  (*   | COMMA -> "comma" *)
  (*   | COUNT -> "count" *)
  (*   | DESC -> "desc" *)
  (*   | DIV -> "div" *)
  (*   | DOT -> "dot" *)
  (*   | DOUBLE_COLON -> "double_colon" *)
  (*   | DOUBLE_PIPE -> "||" *)
  (*   | EOF -> "eof" *)
  (*   | EQUAL -> "equal" *)
  (*   | FALSE -> "false" *)
  (*   | FLOAT _ -> "float" *)
  (*   | FROM -> "from" *)
  (*   | GROUP -> "group" *)
  (*   | GT -> "gt" *)
  (*   | GTE -> "gte" *)
  (*   | HAVING -> "having" *)
  (*   | IDENTIFIER _ -> "identifier" *)
  (*   | IN -> "in" *)
  (*   | INNER -> "inner" *)
  (*   | INTEGER _ -> "integer" *)
  (*   | IS -> "is" *)
  (*   | IS_DISTINCT_FROM -> "is_distinct_from" *)
  (*   | IS_NOT -> "is not" *)
  (*   | IS_NOT_DISTINCT_FROM -> "is_not_distinct_from" *)
  (*   | JOIN -> "join" *)
  (*   | JSON_OBJ_QUERY -> "json_obj_query" *)
  (*   | JSON_SUBSET -> "json_subset" *)
  (*   | JSON_TEXT -> "json_text" *)
  (*   | JSON_VAL -> "json_val" *)
  (*   | LBRACKET -> "lbracket" *)
  (*   | LEFT -> "left" *)
  (*   | LIMIT -> "limit" *)
  (*   | LPAREN -> "lparen" *)
  (*   | LT -> "lt" *)
  (*   | LTE -> "lte" *)
  (*   | MINUS -> "minus" *)
  (*   | NOT -> "not" *)
  (*   | NOT_EQUAL -> "not_equal" *)
  (*   | NULL -> "null" *)
  (*   | ON -> "on" *)
  (*   | OR -> "or" *)
  (*   | ORDER -> "order" *)
  (*   | PLUS -> "plus" *)
  (*   | RBRACKET -> "rbracket" *)
  (*   | RIGHT -> "right" *)
  (*   | RPAREN -> "rparen" *)
  (*   | SELECT -> "select" *)
  (*   | STAR -> "star" *)
  (*   | STRING _ -> "string" *)
  (*   | TRUE -> "true" *)
  (*   | UNNEST -> "unnest" *)
  (*   | WHERE -> "where" *)
  (*   | WITH -> "with" *)

  let rec loop next_token lexbuf checkpoint =
    let module I = Mql_parser.MenhirInterpreter in
    match checkpoint with
    | I.InputNeeded _ ->
        let token = next_token () in
        (* print_token token; *)
        let checkpoint = I.offer checkpoint token in
        loop next_token lexbuf checkpoint
    | I.Shifting (_, _, _) | I.AboutToReduce (_, _) ->
        let checkpoint = I.resume checkpoint in
        loop next_token lexbuf checkpoint
    | I.HandlingError env ->
        Error
          (try (position env, Mql_parser_errors.message (state env))
           with Not_found ->
             (* No entry of the catalogue covers this state, so say what is
                always true rather than the state number, which means nothing
                to a reader.  The position and the text that the error carries
                show where.  To name more states, put entries in
                [mql_parser_errors.messages] -- [menhir --list-errors] writes
                one entry per state, and [menhir --compile-errors] refuses a
                leftover placeholder. *)
             (position env, "syntax error"))
    | I.Accepted ast -> Ok ast
    (* Unreachable in practice -- [HandlingError] above returns before the
       interpreter can reject -- but the parse path never raises. *)
    | I.Rejected -> Error (None, "Rejected")

  let parse ~variables ~start s =
    (* Guarantee there is a new line at the end of the file.  The HCL spec
       requires a new line after a block but looks like it will accept files that do
       not have a new line. *)
    let lexbuf = Sedlexing.Utf8.from_string (s ^ "\n") in
    let lexer = Sedlexing.with_tokenizer (Mql_lexer.token ~variables) lexbuf in
    match loop lexer lexbuf (start (fst @@ Sedlexing.lexing_positions lexbuf)) with
    | Ok r -> Ok r
    | Error (pos, err) -> Error (`Error (pos, s, CCString.trim err))
    (* The lexer signals failure by exception, so convert it here rather than
       letting it escape the result type. *)
    | exception Mql_lexer.Lex_err msg ->
        let { Lexing.pos_lnum; pos_bol; pos_cnum = _; pos_fname = _ } =
          fst @@ Sedlexing.lexing_positions lexbuf
        in
        Error (`Error (Some { lnum = pos_lnum; offset = pos_bol }, s, msg))

  (* Which gated constructs a parsed query actually uses.

     A complete walk.  Every gated construct is a statement shape, or a [locking]
     clause on a query, and both can hide inside a subquery in expression
     position -- [exists (with a as (delete ...) select 1)] holds a
     data-modifying statement that no top-level form names.  The walk therefore
     reaches every statement and every expression of the tree, and the compiler
     enforces the exhaustive matches, so a new constructor cannot be added
     without deciding whether it is gated.  One hole stays, deliberately: a
     function body is held verbatim (see [Func_as_body]) and the walk cannot
     read inside one; [Create_function] is itself gated, which covers what its
     body holds. *)
  let rec features_used t =
    let open Mql_ast in
    match t with
    | Insert { source; on_conflict; returning; table = _; columns = _ } ->
        Feature.Data_modifying
        ::
        (match source with
        | Insert_values rows -> features_exprss rows
        | Insert_query q -> features_used q
        | Insert_default_values -> [])
        @ features_on_conflict on_conflict
        @ features_select_list_opt returning
    | Update { set_; from; where; returning; table = _ } ->
        Feature.Data_modifying
        :: (features_assignments set_
           @ features_from from
           @ features_expr_opt where
           @ features_select_list_opt returning)
    | Delete { using; where; returning; table = _ } ->
        Feature.Data_modifying
        :: (features_from using @ features_expr_opt where @ features_select_list_opt returning)
    | With { query; body; materialized = _; recursive = _; name = _; columns = _ } ->
        features_used query @ features_used body
    | Query { body; order_by; offset; limit; locking } ->
        (match locking with
          | Some _ -> [ Feature.Locking_clause ]
          | None -> [])
        @ features_query_body body
        @ features_order_by_opt order_by
        @ features_expr_opt offset
        @ features_expr_opt limit
    | Create_table { body; if_not_exists = _; temp = _; name = _; partition; on_commit_drop = _ } ->
        Feature.Ddl
        :: (features_create_table_body body
           @
           (* A [partition by] key expression is feature-checked like any other
               expression: the key itself carries no tag, but an embedded subquery
               does, and the walk must see it. *)
           match partition with
           | None -> []
           | Some { Mql_ast.strategy = _; key } -> CCList.concat_map features_expr key)
    | Create_index
        {
          columns;
          where;
          unique = _;
          concurrently = _;
          if_not_exists = _;
          name = _;
          table = _;
          method_ = _;
          include_ = _;
          nulls_not_distinct = _;
        } ->
        Feature.Ddl
        :: (CCList.concat_map (fun c -> features_expr c.idx_expr) columns @ features_expr_opt where)
    | Create_view { query; or_replace = _; name = _; columns = _ } ->
        Feature.Ddl :: features_used query
    (* The function body is verbatim text, not an AST (see [Func_as_body]). *)
    | Create_function _ -> [ Feature.Ddl ]
    | Alter_function_set { values; name = _; setting = _ } -> Feature.Ddl :: features_exprs values
    | Alter_table { actions; if_exists = _; only = _; name = _ } ->
        Feature.Ddl :: features_alter_actions actions
    | Set_stmt { value; local = _; name = _ } -> Feature.Ddl :: features_expr value
    | Create_trigger _
    | Create_extension _
    | Set_constraints _
    | Drop _
    | Comment_on _
    | Grant _
    | Create_role _
    | Create_database _
    | Truncate _
    | Analyze _
    | Lock_table _ -> [ Feature.Ddl ]

  and features_query_body qb =
    let open Mql_ast in
    match qb with
    | Select s -> features_select s
    | Set_op { left; right; op = _; all = _ } ->
        features_query_body left @ features_query_body right
    | Paren q -> features_used q

  and features_select s =
    let open Mql_ast in
    features_distinct_opt s.distinct
    @ features_select_list s.select_list
    @ features_from s.from
    @ features_expr_opt s.where
    @ features_group_by_opt s.group_by
    @ features_expr_opt s.having

  and features_expr_opt = function
    | None -> []
    | Some e -> features_expr e

  and features_exprs es = CCList.concat_map features_expr es
  and features_exprss ess = CCList.concat_map features_exprs ess

  and features_expr e =
    let open Mql_ast in
    match e with
    | Exists q | Array_query q -> features_used q
    | In_query (x, q) | Not_in_query (x, q) -> features_expr x @ features_used q
    | Scalar_subquery q -> features_used q
    (* Two-operand operators.  The second half holds the shapes whose other
       field is not an expression: a type, a name, a path literal. *)
    | Add (a, b)
    | And (a, b)
    | Concat (a, b)
    | Div (a, b)
    | Eq (a, b)
    | Gt (a, b)
    | Gte (a, b)
    | Ilike (a, b)
    | Index (a, b)
    | Is (a, b)
    | Is_distinct_from (a, b)
    | Is_not (a, b)
    | Is_not_distinct_from (a, b)
    | Json_subset (a, b)
    | Json_text (a, b)
    | Json_val (a, b)
    | Json_has_key (a, b)
    | Json_obj_val_path (a, b)
    | Json_obj_query_path (a, b)
    | Like (a, b)
    | Lt (a, b)
    | Lte (a, b)
    | Mod (a, b)
    | Mult (a, b)
    | Not_eq (a, b)
    | Not_ilike (a, b)
    | Not_like (a, b)
    | Or (a, b)
    | Regex_match (a, b)
    | Regex_not_match (a, b)
    | Regex_imatch (a, b)
    | Regex_not_imatch (a, b)
    | Bit_and (a, b)
    | Sub (a, b)
    | At_time_zone (a, b)
    | Substring_from (a, b)
    | Position_in (a, b) -> features_expr a @ features_expr b
    | Slice (a, b, c) | Like_escape (a, b, c) -> features_expr a @ features_expr b @ features_expr c
    | Cast (a, _)
    | Extract (_, a)
    | Collate (a, _)
    | Field_select (a, _)
    | Json_obj_query (a, _)
    | Json_obj_val (a, _)
    | Negate a
    | Not a
    | Qualified_star a -> features_expr a
    | In (a, xs) | Not_in (a, xs) -> features_expr a @ features_exprs xs
    | Tuple xs | Array_lit xs -> features_exprs xs
    | Case { operand; branches; else_ } ->
        features_expr_opt operand
        @ CCList.concat_map (fun (c, v) -> features_expr c @ features_expr v) branches
        @ features_expr_opt else_
    | Func f -> (
        (match f.args with
          | Func_star -> []
          | Func_exprs args ->
              CCList.concat_map
                (function
                  | Arg x -> features_expr x
                  | Arg_named (_, x) -> features_expr x)
                args)
        @ features_order_by_opt f.agg_order_by
        @ features_expr_opt f.filter
        @
        match f.over with
        | None -> []
        | Some w -> features_exprs w.partition_by @ features_order_by_opt w.window_order_by)
    | Float _ | False | Identifier _ | Int _ | Null | String _ | True | Interval _ | Variable _ ->
        []

  and features_select_list sl =
    let open Mql_ast in
    match sl with
    | Star -> []
    | Columns cols -> CCList.concat_map (fun c -> features_expr c.expr) cols

  and features_select_list_opt = function
    | None -> []
    | Some sl -> features_select_list sl

  and features_distinct_opt d =
    let open Mql_ast in
    match d with
    | None | Some Distinct -> []
    | Some (Distinct_on es) -> features_exprs es

  and features_order_by_opt ob =
    let open Mql_ast in
    match ob with
    | None -> []
    | Some items -> CCList.concat_map (fun i -> features_expr i.ob_expr) items

  and features_group_by_opt gb =
    let open Mql_ast in
    match gb with
    | None -> []
    | Some (Group_exprs es) -> features_exprs es
    | Some (Group_sets ess) -> features_exprss ess

  and features_from fts =
    let open Mql_ast in
    CCList.concat_map
      (fun fe ->
        features_table_ref fe.fe_table
        @ CCList.concat_map
            (fun j ->
              features_table_ref j.table
              @
              match j.on_ with
              | On e -> features_expr e
              | Using _ | No_cond -> [])
            fe.fe_joins)
      fts

  and features_table_ref tr =
    let open Mql_ast in
    match tr with
    | Table_ref _ -> []
    | Unnest { exprs; alias = _; columns = _ } -> features_exprs exprs
    | Derived_table { query; alias = _; columns = _; lateral_ = _ } -> features_used query
    | Func_table { expr; ordinality = _; alias = _; columns = _; lateral_ = _ } ->
        features_expr expr

  and features_assignments assignments =
    let open Mql_ast in
    CCList.concat_map
      (function
        | Assign (_, e) -> features_expr e
        | Assign_row (_, es) -> features_exprs es)
      assignments

  and features_on_conflict oc =
    let open Mql_ast in
    match oc with
    | None -> []
    | Some { target; action } -> (
        (match target with
          | On_conflict_none | On_conflict_constraint _ -> []
          | On_conflict_elems { elems; where } ->
              CCList.concat_map
                (function
                  | Conflict_col _ -> []
                  | Conflict_expr e -> features_expr e)
                elems
              @ features_expr_opt where)
        @
        match action with
        | Do_nothing -> []
        | Do_update { set_; where } -> features_assignments set_ @ features_expr_opt where)

  and features_create_table_body body =
    let open Mql_ast in
    match body with
    | Table_items items | Table_foreign { items; server = _; options = _ } ->
        CCList.concat_map features_table_item items
    | Table_partition_of { parent = _; bound } -> Feature.Ddl :: features_partition_bound bound
    | Table_as_query q -> features_used q

  and features_partition_bound bound =
    let open Mql_ast in
    match bound with
    | Pb_range (lo, hi) -> CCList.concat_map features_expr (lo @ hi)
    | Pb_in es -> CCList.concat_map features_expr es
    | Pb_default -> []

  and features_table_item item =
    let open Mql_ast in
    match item with
    | Column_def cd -> CCList.concat_map features_col_constraint cd.col_constraints
    | Table_constraint tc -> features_table_constraint tc

  and features_col_constraint cc =
    let open Mql_ast in
    match cc with
    | Not_null
    | Null_allowed
    | Col_primary_key
    | Col_unique
    | Col_references _
    | Col_generated_identity -> []
    | Default_value e | Col_check e | Col_generated_stored e -> features_expr e
    | Col_named_constraint (_, c) -> features_col_constraint c

  and features_table_constraint tc =
    let open Mql_ast in
    match tc with
    | Tbl_primary_key _
    | Tbl_primary_key_using_index _
    | Tbl_unique_using_index _
    | Tbl_unique _
    | Tbl_foreign_key _ -> []
    | Tbl_check e -> features_expr e
    | Tbl_named_constraint (_, tc) -> features_table_constraint tc

  and features_alter_actions actions =
    let open Mql_ast in
    CCList.concat_map
      (function
        | Add_column { column; if_not_exists = _ } ->
            CCList.concat_map features_col_constraint column.col_constraints
        | Drop_column _ | Drop_constraint _ | Rename_to _ | Rename_column _ -> []
        | Alter_column (_, a) -> (
            match a with
            | Set_not_null | Drop_not_null | Drop_default -> []
            | Set_default e -> features_expr e
            | Set_type { using; type_ = _ } -> features_expr_opt using)
        | Add_constraint tc | Add_constraint_not_valid tc -> features_table_constraint tc
        | Set_options opts -> CCList.concat_map (fun (_, e) -> features_expr e) opts
        | Attach_partition { name = _; bound } -> features_partition_bound bound)
      actions

  let check_features ~features t =
    match
      CCList.find_opt (fun f -> not (CCList.mem ~eq:Feature.equal f features)) (features_used t)
    with
    | Some f -> Error f
    | None -> Ok ()

  let gate ~features r =
    let open CCResult.Infix in
    r
    >>= fun t ->
    match check_features ~features t with
    | Ok () -> Ok t
    | Error f ->
        Error (`Error (None, Mql_ast.show t, Printf.sprintf "%s is not enabled" (Feature.show f)))

  let of_string ?(variables = false) ?(features = []) s =
    gate ~features @@ parse ~variables ~start:Mql_parser.Incremental.start s

  (* An expression holds no gated construct at its top level, thus this takes no [features]:
     [features_used] walks a statement and a query only, and a gate here would say more than it
     does.  The text that reaches this comes from this repository, never from outside. *)
  let expr_of_string ?(variables = false) s =
    parse ~variables ~start:Mql_parser.Incremental.standalone_expr s

  let of_string_multi ?(variables = false) ?(features = []) s =
    let open CCResult.Infix in
    parse ~variables ~start:Mql_parser.Incremental.queries s
    >>= fun ts -> CCResult.map_l (fun t -> gate ~features (Ok t)) ts

  (* Raised deep inside [AST2DCST] when an AST has no rendering, and caught at
     the three public rendering boundaries below, which turn it into an [Error].
     Mirrors [Mql_to_pgsql]'s [Rw_exn]: internal control flow, never escaping.
     Not exposed in the mli -- nothing outside this module may observe it. *)
  exception Render_exn of string

  let starts_with ls s = CCList.exists (fun prefix -> CCString.starts_with ~prefix s) ls
  let escape_str = CCString.replace ~which:`All ~sub:"'" ~by:"''"

  (* A plain literal cannot carry a backslash safely.  PostgreSQL reads a
     backslash in one as itself, but [Pgsql_io.Typed_sql], which executes the
     text this printer writes, reads a backslash inside a literal as an escape of
     the character after it -- thus a lone [\] before the closing quote eats that
     quote, the scan for [$name] believes it is still inside the literal, and the
     next [${] is an empty variable name.  A newline is a second such character:
     it puts the rest of the statement on a new line, and [Typed_sql] removes each
     line that starts with [--].

     Write a value that holds one of these as an escape string.  PostgreSQL and
     this lexer read the two forms as the same text, and the escape string holds
     the whole value on one line with no bare backslash. *)
  let needs_escape_string =
    CCString.exists (function
      | '\\' | '\n' | '\r' | '\t' | '\b' | '\012' -> true
      | _ -> false)

  (* Only the escapes [Mql_lexer.parse_escape_string_literal] reads.  Each other
     character stays as it is: PostgreSQL takes it as itself in both forms. *)
  let escape_string_str s =
    let b = Buffer.create (CCString.length s + 8) in
    CCString.iter
      (function
        | '\\' -> Buffer.add_string b "\\\\"
        | '\'' -> Buffer.add_string b "''"
        | '\n' -> Buffer.add_string b "\\n"
        | '\r' -> Buffer.add_string b "\\r"
        | '\t' -> Buffer.add_string b "\\t"
        | '\b' -> Buffer.add_string b "\\b"
        | '\012' -> Buffer.add_string b "\\f"
        | c -> Buffer.add_char b c)
      s;
    Buffer.contents b

  class print =
    object
      inherit [string] Mql_parser.CST.reduce
      method zero = ""

      method cat s1 s2 =
        (* Printf.printf "cat %S %S\n%!" s1 s2; *)
        match (s1, s2) with
        (* A star closes its call with no blank.  The text after the
           closing parenthesis is not always the end: an aggregate can have a
           filter or a window. *)
        | "*", s2 when starts_with [ ")" ] s2 -> "*" ^ s2
        | (("" | "::" | "(" | "[" | "->" | "->>" | ".") as s1), s2 -> s1 ^ s2
        | s1, "" -> s1
        | ( (( "="
             | "+"
             | "-"
             | "*"
             | "/"
             | "select"
             | "where"
             | "on"
             | "in"
             | "as"
             | "materialized"
             | "exists"
             | "union"
             | "using"
             | "values"
             (* Each of these can have a parenthesis, and each one needs a
                blank before it. *)
             | "filter"
             | "over"
             | "join"
             | "lateral"
             | "from"
             | "conflict"
             | "sets"
             | "set"
             | "include"
             | "options"
             (* A comma always has a blank after it, also when a
                parenthesis is next: [grouping sets ((a), ())]. *)
             | ","
             | "all"
             (* A regular expression operator, before a parenthesis. *)
             | "~"
             | "!~"
             | "~*"
             | "!~*" ) as s1),
            s2 ) -> s1 ^ " " ^ s2
        | s1, s2 when starts_with [ "::"; "("; "->"; "->>"; ")"; "["; "]"; ","; "."; ";" ] s2 ->
            s1 ^ s2
        | s1, s2 -> s1 ^ " " ^ s2

      method text s = s
      method visit_AND = "and"
      method visit_AFTER = "after"
      method visit_BEFORE = "before"
      method visit_COST = "cost"
      method visit_EACH = "each"
      method visit_EXECUTE = "execute"
      method visit_EXTENSION = "extension"
      method visit_FOR = "for"
      method visit_IMMUTABLE = "immutable"
      method visit_INSTEAD = "instead"
      method visit_LANGUAGE = "language"
      method visit_LOCAL = "local"
      method visit_OF = "of"
      method visit_ATTACH = "attach"
      method visit_RANGE = "range"
      method visit_LIST = "list"
      method visit_PARALLEL = "parallel"
      method visit_RETURNS = "returns"
      method visit_ROW = "row"
      method visit_ROWS = "rows"
      method visit_SECURITY = "security"
      method visit_SETOF = "setof"
      method visit_STABLE = "stable"
      method visit_STATEMENT = "statement"
      method visit_STRICT = "strict"
      method visit_TRIGGER = "trigger"
      method visit_VOLATILE = "volatile"
      method visit_NO_ACTION = "no action"
      method visit_PRECISION = "precision"
      method visit_VARYING = "varying"
      method visit_WITHOUT_TIME_ZONE = "without time zone"
      method visit_WITH_TIME_ZONE = "with time zone"
      method visit_ADD = "add"
      method visit_ALTER = "alter"
      method visit_ANALYZE = "analyze"
      method visit_CASCADE = "cascade"
      method visit_CHECK = "check"
      method visit_COLUMN = "column"
      method visit_COMMENT = "comment"
      method visit_CONCURRENTLY = "concurrently"
      method visit_CONSTRAINT = "constraint"
      method visit_CONSTRAINTS = "constraints"
      method visit_DEFERRED = "deferred"
      method visit_IMMEDIATE = "immediate"
      method visit_CREATE = "create"
      method visit_DROP = "drop"
      method visit_FOREIGN = "foreign"
      method visit_FUNCTION = "function"
      method visit_IF = "if"
      method visit_INDEX = "index"
      method visit_KEY_KW = "key"
      method visit_ONLY = "only"
      method visit_PRIMARY = "primary"
      method visit_REFERENCES = "references"
      method visit_RENAME = "rename"
      method visit_REPLACE = "replace"
      method visit_RESTRICT = "restrict"
      method visit_TABLE = "table"
      method visit_TEMP = "temp"
      method visit_TEMPORARY = "temporary"
      method visit_TO = "to"
      method visit_TRUNCATE = "truncate"
      method visit_TYPE = "type"
      method visit_UNIQUE = "unique"
      method visit_VIEW = "view"
      method visit_LOCK_TABLE = "lock table"

      (* The whole [in ... mode] phrase, as one token of the lexer. *)
      method visit_LOCK_MODE =
        function
        | M.Lock_mode_access_share -> "in access share mode"
        | M.Lock_mode_row_share -> "in row share mode"
        | M.Lock_mode_row_exclusive -> "in row exclusive mode"
        | M.Lock_mode_share -> "in share mode"
        | M.Lock_mode_share_row_exclusive -> "in share row exclusive mode"
        | M.Lock_mode_exclusive -> "in exclusive mode"
        | M.Lock_mode_access_exclusive -> "in access exclusive mode"

      (* A dollar-quoted string renders with its original delimiter. *)
      method visit_DOLLAR_STRING (delim, body) = delim ^ body ^ delim
      method visit_AS = "as"
      method visit_ASC = "asc"
      method visit_BY = "by"
      method visit_COMMA = ","
      method visit_ARRAY_SUFFIX = "[]"
      method visit_AT_TIME_ZONE = "at time zone"
      method visit_CASE = "case"
      method visit_CONFLICT = "conflict"
      method visit_FILTER = "filter"
      method visit_ALWAYS = "always"
      method visit_DATABASE = "database"
      method visit_GRANT = "grant"
      method visit_LOGIN = "login"
      method visit_PASSWORD = "password"
      method visit_REVOKE = "revoke"
      method visit_ROLE = "role"
      method visit_ARRAY = "array"
      method visit_COMMIT = "commit"
      method visit_GENERATED = "generated"
      method visit_IDENTITY = "identity"
      method visit_INCLUDE = "include"
      method visit_OPTIONS = "options"
      method visit_SERVER = "server"
      method visit_STORED = "stored"
      method visit_EXCEPT = "except"
      method visit_GROUPING = "grouping"
      method visit_NAMED_ARG = "=>"
      method visit_SETS = "sets"
      method visit_FIRST = "first"
      method visit_INTERSECT = "intersect"
      method visit_LAST = "last"
      method visit_NULLS = "nulls"
      method visit_OFFSET = "offset"
      method visit_RECURSIVE = "recursive"
      method visit_COLON = ":"
      method visit_MOD = "%"
      method visit_ESCAPE = "escape"
      method visit_EXTRACT = "extract"
      method visit_CAST = "cast"
      method visit_JSON_HAS_KEY = "?"
      method visit_LATERAL = "lateral"
      method visit_POSITION = "position"
      method visit_SUBSTRING = "substring"
      method visit_OVER = "over"
      method visit_PARTITION = "partition"
      method visit_DEFAULT = "default"
      method visit_DELETE = "delete"
      method visit_DO = "do"
      method visit_INSERT = "insert"
      method visit_INTO = "into"
      method visit_NOTHING = "nothing"
      method visit_RETURNING = "returning"
      method visit_SET = "set"
      method visit_UPDATE = "update"
      method visit_VALUES = "values"
      method visit_CROSS = "cross"
      method visit_FULL = "full"
      method visit_OUTER = "outer"
      method visit_USING = "using"
      method visit_ELSE = "else"
      method visit_END = "end"
      method visit_INTERVAL = "interval"
      method visit_JSON_OBJ_VAL = "#>"
      method visit_REGEX_MATCH = "~"
      method visit_REGEX_NOT_MATCH = "!~"
      method visit_REGEX_IMATCH = "~*"
      method visit_REGEX_NOT_IMATCH = "!~*"
      method visit_COLLATE = "collate"
      method visit_WITH_ORDINALITY = "with ordinality"
      method visit_BIT_AND = "&"
      method visit_THEN = "then"
      method visit_WHEN = "when"
      method visit_DESC = "desc"
      method visit_DISTINCT = "distinct"
      method visit_DIV = "/"
      method visit_DOT = "."
      method visit_DOUBLE_COLON = "::"
      method visit_DOUBLE_PIPE = "||"
      method visit_EOF = ""
      method visit_EQUAL = "="
      method visit_EXISTS = "exists"
      method visit_FALSE = "false"

      (* The shortest text that reads back as the same number.  [%f] wrote [0.0]
         as [0.000000], thus a table option that the SQL wrote as [0.0] reached
         PostgreSQL as [0.000000] and the catalog held that text.  The text needs
         a point or an exponent: with neither, the lexer reads an integer and the
         printer changes the shape of the tree.  A non-finite value would render
         to text that cannot be read back ([inf] is a name, not a literal), so
         refuse it -- the lexer already refuses such literals. *)
      method visit_FLOAT fl =
        if not (Float.is_finite fl) then raise (Render_exn "a non-finite float has no rendering");
        let rec shortest n =
          if n > 17 then Printf.sprintf "%.17g" fl
          else
            let s = Printf.sprintf "%.*g" n fl in
            if CCFloat.equal (float_of_string s) fl then s else shortest (n + 1)
        in
        let s = shortest 1 in
        if
          CCString.exists
            (function
              | '.' | 'e' | 'E' -> true
              | _ -> false)
            s
        then s
        else s ^ ".0"

      method visit_FOR_KEY_SHARE = "for key share"
      method visit_FOR_NO_KEY_UPDATE = "for no key update"
      method visit_FOR_SHARE = "for share"
      method visit_FOR_UPDATE = "for update"
      method visit_FROM = "from"
      method visit_NOWAIT = "nowait"
      method visit_SKIP_LOCKED = "skip locked"
      method visit_GROUP = "group"
      method visit_GT = ">"
      method visit_GTE = ">="
      method visit_HAVING = "having"

      (* Reproduce the spelling the identifier was written with. A quoted name
         must stay quoted: unquoted, PostgreSQL would fold its case, and a name
         that is a keyword would not parse back at all. Any quote inside is
         doubled, mirroring how a string literal escapes its delimiter. *)
      method visit_IDENTIFIER { M.name; quoted } =
        if quoted then "\"" ^ CCString.replace ~which:`All ~sub:"\"" ~by:"\"\"" name ^ "\""
        else name

      method visit_ILIKE = "ilike"
      method visit_IN = "in"
      method visit_LIKE = "like"
      method visit_INNER = "inner"
      method visit_INTEGER i = Printf.sprintf "%i" i
      method visit_IS = "is"
      method visit_IS_DISTINCT_FROM = "is distinct from"
      method visit_IS_NOT = "is not"
      method visit_IS_NOT_DISTINCT_FROM = "is not distinct from"
      method visit_JOIN = "join"
      method visit_JSON_OBJ_QUERY = "#>>"
      method visit_JSON_SUBSET = "@>"
      method visit_JSON_TEXT = "->>"
      method visit_JSON_VAL = "->"
      method visit_LBRACKET = "["
      method visit_LEFT = "left"
      method visit_LIMIT = "limit"
      method visit_LPAREN = "("
      method visit_LT = "<"
      method visit_LTE = "<="
      method visit_MATERIALIZED = "materialized"
      method visit_MINUS = "-"
      method visit_MULT = "*"
      method visit_NOT = "not"
      method visit_NOT_EQUAL = "<>"
      method visit_NULL = "null"
      method visit_ON = "on"
      method visit_OR = "or"
      method visit_ORDER = "order"
      method visit_PLUS = "+"
      method visit_RBRACKET = "]"
      method visit_RIGHT = "right"
      method visit_RPAREN = ")"
      method visit_SELECT = "select"
      method visit_SEMICOLON = ";"
      method visit_STAR = "*"

      method visit_STRING s =
        if needs_escape_string s then Printf.sprintf "E'%s'" (escape_string_str s)
        else Printf.sprintf "'%s'" (escape_str s)

      method visit_TRUE = "true"
      method visit_WHERE = "where"
      method visit_UNNEST = "unnest"
      method visit_UNION = "union"
      method visit_VARIABLE s = "$" ^ s
      method visit_ALL = "all"
      method visit_VALID = "valid"
      method visit_WITH = "with"
    end

  module AST2DCST = struct
    module A = Mql_ast
    module D = Mql_parser.DCST

    let maybe_paren e = D.expr_choice e (D.paren e)

    (* PostgreSQL takes a subscript only after a name, a [$name] parameter, another subscript, or a
       parenthesized expression: [(array_agg(x))[1]] is legal and [array_agg(x)[1]] is a syntax
       error.  The MQL grammar is wider, thus it reads the plain form as the same tree and [Settle]
       drops a pair of parentheses that PostgreSQL needs.  Hold them here instead. *)
    let rec subscript_needs_no_paren = function
      | A.Identifier _ | A.Variable _ -> true
      | A.Field_select (e, _) | A.Index (e, _) | A.Slice (e, _, _) -> subscript_needs_no_paren e
      | _ -> false

    (* PostgreSQL binds [::] tighter than [#>] and [#>>], thus it reads
       [a #>> '{}'::boolean] as [a #>> ('{}'::boolean)].  This grammar takes the right side of
       those two operators as a string and not as an expression, thus it reads the same text as
       the cast of the whole, and [Settle] drops the pair of parentheses that PostgreSQL needs.
       Hold them here instead.

       Every other operand of a cast is safe: this grammar and PostgreSQL agree on where [::]
       binds, thus [Settle] keeps each pair that the meaning needs. *)
    let cast_needs_paren = function
      | A.Json_obj_query (_, _) | A.Json_obj_val (_, _) -> true
      | _ -> false

    (* Always the plain form: a name that happens to be a non-reserved keyword
       renders as that word and re-parses through [non_reserved]. *)
    let mk_ident i = D.ident_plain i

    let rec mk_expr = function
      | A.Add (e1, e2) -> maybe_paren @@ D.add (mk_expr e1) (mk_expr e2)
      | A.And (e1, e2) -> maybe_paren @@ D.and_ (mk_expr e1) (mk_expr e2)
      | A.Cast (e1, type_) ->
          let operand = if cast_needs_paren e1 then D.paren (mk_expr e1) else mk_expr e1 in
          maybe_paren @@ D.cast operand (mk_cast_type type_)
      | A.Concat (e1, e2) -> maybe_paren @@ D.concat (mk_expr e1) (mk_expr e2)
      | A.Div (e1, e2) -> maybe_paren @@ D.div (mk_expr e1) (mk_expr e2)
      | A.Eq (e1, e2) -> maybe_paren @@ D.equal (mk_expr e1) (mk_expr e2)
      | A.Exists q -> maybe_paren @@ D.exists (insert_query_dcst q)
      | A.False -> D.false_ ()
      (* A name with a table or a schema before it.  Only a name can
         have one: the grammar parses no other form. *)
      | A.Field_select (A.Identifier q, field) ->
          maybe_paren @@ D.name_expr (D.name_ref_qualified (mk_ident q) (mk_ident field))
      | A.Field_select (_, _) ->
          raise (Render_exn "a field of anything but a name has no rendering")
      | A.Qualified_star (A.Identifier q) -> maybe_paren @@ D.qualified_star (mk_ident q)
      | A.Qualified_star _ -> raise (Render_exn "a star on anything but a name has no rendering")
      | A.Scalar_subquery q -> maybe_paren @@ D.scalar_subquery (insert_query_dcst q)
      | A.Array_lit [] -> maybe_paren @@ D.array_lit_empty ()
      | A.Array_lit es -> maybe_paren @@ D.array_lit (mk_expr_list es)
      | A.Array_query q -> maybe_paren @@ D.array_query (insert_query_dcst q)
      | A.Json_has_key (e1, e2) -> maybe_paren @@ D.json_has_key (mk_expr e1) (mk_expr e2)
      | A.Like_escape (e1, e2, e3) ->
          maybe_paren @@ D.like_escape (mk_expr e1) (mk_expr e2) (mk_expr e3)
      | A.Extract (f, e) -> maybe_paren @@ D.extract (mk_ident f) (mk_expr e)
      | A.Substring_from (e1, e2) -> maybe_paren @@ D.substring_from (mk_expr e1) (mk_expr e2)
      | A.Position_in (A.String s, e2) ->
          maybe_paren @@ D.position_in (D.position_needle_string s) (mk_expr e2)
      | A.Position_in (A.Identifier i, e2) ->
          maybe_paren @@ D.position_in (D.position_needle_name (mk_ident i)) (mk_expr e2)
      | A.Position_in (_, _) ->
          raise (Render_exn "position of anything but a text or a name has no rendering")
      | A.Mod (e1, e2) -> maybe_paren @@ D.mod_ (mk_expr e1) (mk_expr e2)
      | A.Slice (e1, e2, e3) -> maybe_paren @@ D.slice (mk_subscripted e1) (mk_expr e2) (mk_expr e3)
      | A.Float fl -> D.float fl
      (* A call over a star has its own rule, because a star is not an
         expression.  Every other call writes its name as a plain name, thus a
         call to [count] over expressions goes through [fun_call]. *)
      | A.Func { M.qualifier; name; distinct; args = M.Func_star; agg_order_by; filter; over } ->
          if distinct then raise (Render_exn "distinct over a star has no rendering");
          if CCOption.is_some agg_order_by then
            raise (Render_exn "an order over a star has no rendering");
          maybe_paren
          @@ D.count_star (mk_name_ref qualifier name) (mk_func_filter filter) (mk_func_over over)
      | A.Func { M.qualifier; name; distinct; args = M.Func_exprs []; agg_order_by; filter; over }
        ->
          if distinct then raise (Render_exn "distinct with no argument has no rendering");
          if CCOption.is_some agg_order_by then
            raise (Render_exn "an order with no argument has no rendering");
          maybe_paren
          @@ D.fun_no_args (mk_name_ref qualifier name) (mk_func_filter filter) (mk_func_over over)
      | A.Func { M.qualifier; name; distinct; args = M.Func_exprs args; agg_order_by; filter; over }
        ->
          maybe_paren
          @@ D.fun_call
               (mk_name_ref qualifier name)
               (mk_func_distinct distinct)
               (mk_fun_args args)
               (mk_func_agg_order agg_order_by)
               (mk_func_filter filter)
               (mk_func_over over)
      | A.Gt (e1, e2) -> maybe_paren @@ D.gt (mk_expr e1) (mk_expr e2)
      | A.Gte (e1, e2) -> maybe_paren @@ D.gte (mk_expr e1) (mk_expr e2)
      | A.Identifier s -> maybe_paren @@ D.name_expr (D.name_ref_bare (mk_ident s))
      | A.Ilike (e1, e2) -> maybe_paren @@ D.ilike (mk_expr e1) (mk_expr e2)
      | A.Index (e1, e2) -> maybe_paren @@ D.index (mk_subscripted e1) (mk_expr e2)
      | A.In (e1, tuple) -> maybe_paren @@ D.in_ (mk_expr e1) (mk_in_list tuple)
      | A.In_query (e1, q) -> maybe_paren @@ D.in_query (mk_expr e1) (insert_query_dcst q)
      | A.Int i -> D.integer i
      | A.Is (e1, e2) -> maybe_paren @@ D.is_ (mk_expr e1) (mk_expr e2)
      | A.Is_distinct_from (e1, e2) -> maybe_paren @@ D.is_distinct_from (mk_expr e1) (mk_expr e2)
      | A.Is_not (e1, e2) -> maybe_paren @@ D.is_not (mk_expr e1) (mk_expr e2)
      | A.Is_not_distinct_from (e1, e2) ->
          maybe_paren @@ D.is_not_distinct_from (mk_expr e1) (mk_expr e2)
      | A.Json_obj_query (e1, s) -> maybe_paren @@ D.json_obj_query (mk_expr e1) (D.string s)
      | A.Json_obj_query_path (e1, e2) -> maybe_paren @@ D.json_obj_query (mk_expr e1) (mk_expr e2)
      | A.Json_subset (e1, e2) -> maybe_paren @@ D.json_subset (mk_expr e1) (mk_expr e2)
      | A.Json_text (e1, e2) -> maybe_paren @@ D.json_text (mk_expr e1) (mk_expr e2)
      | A.Json_val (e1, e2) -> maybe_paren @@ D.json_val (mk_expr e1) (mk_expr e2)
      | A.Like (e1, e2) -> maybe_paren @@ D.like (mk_expr e1) (mk_expr e2)
      | A.Lt (e1, e2) -> maybe_paren @@ D.lt (mk_expr e1) (mk_expr e2)
      | A.Lte (e1, e2) -> maybe_paren @@ D.lte (mk_expr e1) (mk_expr e2)
      | A.Mult (e1, e2) -> maybe_paren @@ D.mult (mk_expr e1) (mk_expr e2)
      | A.Negate e1 -> maybe_paren @@ D.negate (mk_expr e1)
      | A.Not e1 -> maybe_paren @@ D.not_ (mk_expr e1)
      | A.Not_eq (e1, e2) -> maybe_paren @@ D.not_equal (mk_expr e1) (mk_expr e2)
      | A.Not_ilike (e1, e2) -> maybe_paren @@ D.not_ilike (mk_expr e1) (mk_expr e2)
      | A.Not_like (e1, e2) -> maybe_paren @@ D.not_like (mk_expr e1) (mk_expr e2)
      | A.Null -> D.null ()
      | A.Or (e1, e2) -> maybe_paren @@ D.or_ (mk_expr e1) (mk_expr e2)
      | A.String s -> D.string s
      | A.Sub (e1, e2) -> maybe_paren @@ D.sub (mk_expr e1) (mk_expr e2)
      | A.True -> D.true_ ()
      | A.Tuple tuple -> maybe_paren @@ D.tuple @@ mk_tuple tuple
      | A.At_time_zone (e1, e2) -> maybe_paren @@ D.at_time_zone (mk_expr e1) (mk_expr e2)
      | A.Not_in (e1, tuple) -> maybe_paren @@ D.not_in (mk_expr e1) (mk_in_list tuple)
      | A.Not_in_query (e1, q) -> maybe_paren @@ D.not_in_query (mk_expr e1) (insert_query_dcst q)
      | A.Interval s -> maybe_paren @@ D.interval s
      | A.Json_obj_val (e1, s) -> maybe_paren @@ D.json_obj_val (mk_expr e1) (D.string s)
      | A.Json_obj_val_path (e1, e2) -> maybe_paren @@ D.json_obj_val (mk_expr e1) (mk_expr e2)
      | A.Regex_match (e1, e2) -> maybe_paren @@ D.regex_match (mk_expr e1) (mk_expr e2)
      | A.Regex_not_match (e1, e2) -> maybe_paren @@ D.regex_not_match (mk_expr e1) (mk_expr e2)
      | A.Regex_imatch (e1, e2) -> maybe_paren @@ D.regex_imatch (mk_expr e1) (mk_expr e2)
      | A.Regex_not_imatch (e1, e2) -> maybe_paren @@ D.regex_not_imatch (mk_expr e1) (mk_expr e2)
      | A.Collate (e, c) -> maybe_paren @@ D.collate (mk_expr e) (mk_ident c)
      | A.Bit_and (e1, e2) -> maybe_paren @@ D.bit_and (mk_expr e1) (mk_expr e2)
      | A.Case { operand = None; branches; else_ } ->
          maybe_paren @@ D.case (mk_case_branches branches) (mk_case_else else_)
      | A.Case { operand = Some op; branches; else_ } ->
          maybe_paren
          @@ D.case_operand (mk_expr op) (mk_case_branches branches) (mk_case_else else_)
      | A.Variable v -> maybe_paren @@ D.variable v

    and mk_subscripted e = if subscript_needs_no_paren e then mk_expr e else D.paren (mk_expr e)

    and mk_constraints_mode deferred =
      if deferred then D.constraints_deferred () else D.constraints_immediate ()

    and mk_case_branches = function
      | [] -> raise (Render_exn "CASE with no WHEN branch")
      | (c, v) :: bs ->
          CCListLabels.fold_left
            ~init:(D.case_branch (mk_expr c) (mk_expr v))
            ~f:(fun acc (c, v) -> D.case_branches acc (mk_expr c) (mk_expr v))
            bs

    and mk_case_else = function
      | None -> D.case_no_else ()
      | Some e -> D.case_with_else (mk_expr e)

    and mk_name_ref qualifier name =
      match qualifier with
      | None -> D.name_ref_bare (mk_ident name)
      | Some q -> D.name_ref_qualified (mk_ident q) (mk_ident name)

    and mk_func_distinct b = if b then D.func_distinct () else D.no_func_distinct ()

    and mk_func_agg_order = function
      | None -> D.no_func_agg_order ()
      | Some o -> D.func_agg_order (mk_order_by o)

    and mk_func_filter = function
      | None -> D.no_func_filter ()
      | Some e -> D.func_filter (mk_expr e)

    and mk_func_over = function
      | None -> D.no_func_over ()
      | Some { M.partition_by; window_order_by } ->
          D.func_over
            (D.window_spec
               (match partition_by with
               | [] -> D.no_window_partition ()
               | es -> D.window_partition (mk_expr_list es))
               (match window_order_by with
               | None -> D.no_window_order ()
               | Some o -> D.window_order (mk_order_by o)))

    and mk_fun_arg = function
      | M.Arg e -> D.fun_arg_plain (mk_expr e)
      | M.Arg_named (n, e) -> D.fun_arg_named (mk_ident n) (mk_expr e)

    and mk_fun_args = function
      | [] -> raise (Render_exn "function call with no arguments")
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.fun_arg @@ mk_fun_arg x)
            ~f:(fun acc x -> D.fun_args acc @@ mk_fun_arg x)
            xs

    and mk_grouping_set = function
      | [] -> D.grouping_set_empty ()
      | es -> D.grouping_set (mk_expr_list es)

    and mk_grouping_sets = function
      | [] -> raise (Render_exn "GROUPING SETS with no set")
      | g :: gs ->
          CCListLabels.fold_left
            ~init:(D.grouping_sets_one (mk_grouping_set g))
            ~f:(fun acc g -> D.grouping_sets_more acc (mk_grouping_set g))
            gs

    and mk_on_commit_drop b = if b then D.on_commit_drop () else D.no_on_commit_drop ()

    and mk_partition_strategy = function
      | M.Ps_range -> D.partition_strategy_range ()
      | M.Ps_list -> D.partition_strategy_list ()

    and mk_table_partition { M.strategy; key } =
      D.table_partition (mk_partition_strategy strategy) (mk_expr_list key)

    and mk_table_partition_opt = function
      | None -> D.no_table_partition ()
      | Some p -> D.yes_table_partition (mk_table_partition p)

    and mk_partition_bound = function
      | M.Pb_range (lo, hi) -> D.bound_range (mk_expr_list lo) (mk_expr_list hi)
      | M.Pb_in es -> D.bound_in (mk_expr_list es)
      | M.Pb_default -> D.bound_default ()

    and mk_foreign_options = function
      | [] -> raise (Render_exn "a foreign table with no option")
      | (n, v) :: rest ->
          CCListLabels.fold_left
            ~init:(D.foreign_option_one (D.foreign_option (mk_ident n) v))
            ~f:(fun acc (n, v) -> D.foreign_option_more acc (D.foreign_option (mk_ident n) v))
            rest

    and mk_table_options = function
      | [] -> raise (Render_exn "a table with no setting")
      | (n, e) :: rest ->
          CCListLabels.fold_left
            ~init:(D.table_option_one (D.table_option (mk_ident n) (mk_expr e)))
            ~f:(fun acc (n, e) -> D.table_option_more acc (D.table_option (mk_ident n) (mk_expr e)))
            rest

    and mk_conflict_elem = function
      | M.Conflict_col c -> D.conflict_col (mk_ident c)
      | M.Conflict_expr e -> D.conflict_expr (mk_expr e)

    and mk_conflict_elems = function
      | [] -> raise (Render_exn "a conflict target with no entry")
      | e :: es ->
          CCListLabels.fold_left
            ~init:(D.conflict_elem_one (mk_conflict_elem e))
            ~f:(fun acc e -> D.conflict_elem_more acc (mk_conflict_elem e))
            es

    and mk_expr_list = function
      | [] -> raise (Render_exn "a list of expressions with no expression")
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.expr_list_one @@ mk_expr x)
            ~f:(fun acc x -> D.expr_list_more acc @@ mk_expr x)
            xs

    and mk_in_list = function
      | [] -> raise (Render_exn "IN with an empty list")
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.in_list_one @@ mk_expr x)
            ~f:(fun acc x -> D.in_list_more acc @@ mk_expr x)
            xs

    and mk_tuple = function
      | [] | [ _ ] -> raise (Render_exn "tuple with fewer than two elements")
      | x1 :: x2 :: xs ->
          CCListLabels.fold_left
            ~init:(D.t_tuple (mk_expr x1) (mk_expr x2))
            ~f:(fun acc x -> D.tt_tuple acc (mk_expr x))
            xs

    and mk_table_name_of { A.table_qualifier; name; alias = _ } =
      mk_table_name { M.qualifier = table_qualifier; base = name }

    and mk_table = function
      | { A.alias = None; table_qualifier = _; name = _ } as t ->
          D.table_no_alias (mk_table_name_of t)
      | { A.alias = Some alias; table_qualifier = _; name = _ } as t ->
          D.table_with_alias (mk_table_name_of t) (mk_ident alias)

    (* The column names that a FROM item gives to its result.  An empty list means
       the item named no column. *)
    and mk_column_alias { A.ca_name; ca_type } =
      match ca_type with
      | None -> D.column_alias (mk_ident ca_name)
      | Some t -> D.column_alias_typed (mk_ident ca_name) (mk_type_name t)

    and mk_column_alias_list = function
      | [] -> D.no_column_alias_list ()
      | c :: cs ->
          D.column_alias_list
            (CCListLabels.fold_left
               ~init:(D.column_alias_one (mk_column_alias c))
               ~f:(fun acc c -> D.column_alias_more acc (mk_column_alias c))
               cs)

    and mk_from_alias = function
      | None -> D.no_from_alias ()
      | Some a -> D.from_alias_as (mk_ident a)

    and mk_table_ref = function
      | A.Table_ref t -> D.from_table @@ mk_table t
      | A.Unnest { exprs = []; alias = _; columns = _ } ->
          raise (Render_exn "UNNEST with no expressions")
      | A.Unnest { exprs; alias; columns } ->
          D.from_unnest (mk_expr_list exprs) (mk_ident alias) (mk_column_alias_list columns)
      | A.Derived_table { query; alias; columns; lateral_ = false } ->
          D.from_derived (insert_query_dcst query) (mk_ident alias) (mk_column_alias_list columns)
      | A.Derived_table { query; alias; columns; lateral_ = true } ->
          D.from_lateral_derived
            (insert_query_dcst query)
            (mk_ident alias)
            (mk_column_alias_list columns)
      | A.Func_table { expr; ordinality; alias; columns; lateral_ } -> (
          let call =
            match expr with
            | A.Func
                {
                  M.qualifier = None;
                  name;
                  distinct = false;
                  args = M.Func_exprs [];
                  agg_order_by = None;
                  filter = None;
                  over = None;
                } -> D.from_func_no_args (mk_ident name)
            | A.Func
                {
                  M.qualifier = None;
                  name;
                  distinct = false;
                  args = M.Func_exprs args;
                  agg_order_by = None;
                  filter = None;
                  over = None;
                } -> D.from_func_call (mk_ident name) (mk_fun_args args)
            | _ -> raise (Render_exn "a FROM item that is not a plain call has no rendering")
          in
          let ordinality = if ordinality then D.ordinality () else D.no_ordinality () in
          match lateral_ with
          | false ->
              D.from_func_item call ordinality (mk_from_alias alias) (mk_column_alias_list columns)
          | true ->
              D.from_lateral_func_item
                call
                ordinality
                (mk_from_alias alias)
                (mk_column_alias_list columns))

    and mk_from_entry { A.fe_table; fe_joins } =
      match fe_joins with
      | [] -> D.from_entry (mk_table_ref fe_table)
      | js -> D.from_entry_joins (mk_table_ref fe_table) (mk_joins js)

    and mk_tables = function
      | [] -> raise (Render_exn "FROM with no tables")
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.table @@ mk_from_entry x)
            ~f:(fun acc x -> D.tables acc @@ mk_from_entry x)
            xs

    and column = function
      | { A.expr = e; alias = None } -> D.column_no_alias (mk_expr e)
      | { A.expr = e; alias = Some alias } -> D.column_with_alias (mk_expr e) (mk_ident alias)

    and columns acc = function
      | [] -> acc
      | c :: cs -> columns (D.select_list_columns acc (column c)) cs

    and select_list_columns = function
      | M.Star -> D.select_list_star ()
      | M.Columns cs -> (
          match cs with
          | [] -> raise (Render_exn "select list with no columns")
          | c :: cs -> D.select_list @@ columns (D.select_list_column (column c)) cs)

    (* [OUTER] is never emitted: it is noise in SQL, so the canonical rendering
       omits it. *)
    and mk_join_cond = function
      | M.On e -> D.join_on (mk_expr e)
      | M.Using cs -> D.join_using (mk_using_cols cs)
      | M.No_cond -> raise (Render_exn "this join requires a condition")

    and mk_using_cols = function
      | [] -> raise (Render_exn "USING with no columns")
      | c :: cs ->
          CCListLabels.fold_left
            ~init:(D.using_col (mk_ident c))
            ~f:(fun acc c -> D.using_cols acc (mk_ident c))
            cs

    and mk_join = function
      | { M.join_type = M.Cross; table; on_ = M.No_cond } -> D.cross_join (mk_table_ref table)
      | { M.join_type = M.Cross; table = _; on_ = _ } ->
          raise (Render_exn "a CROSS JOIN takes no condition")
      | { M.join_type = M.Inner; table; on_ } ->
          D.inner_join (mk_table_ref table) (mk_join_cond on_)
      | { M.join_type = M.Left; table; on_ } ->
          D.left_join (D.no_outer ()) (mk_table_ref table) (mk_join_cond on_)
      | { M.join_type = M.Right; table; on_ } ->
          D.right_join (D.no_outer ()) (mk_table_ref table) (mk_join_cond on_)
      | { M.join_type = M.Full; table; on_ } ->
          D.full_join (D.no_outer ()) (mk_table_ref table) (mk_join_cond on_)

    and mk_joins = function
      | [] -> raise (Render_exn "join list with no joins")
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.join @@ mk_join x)
            ~f:(fun acc x -> D.joins acc @@ mk_join x)
            xs

    and mk_nulls_opt = function
      | None -> D.no_nulls_order ()
      | Some M.Nulls_first -> D.nulls_first ()
      | Some M.Nulls_last -> D.nulls_last ()

    and mk_order_by_expr { M.ob_expr; ob_order; ob_nulls } =
      let n = mk_nulls_opt ob_nulls in
      match ob_order with
      | Some M.Asc -> D.order_by_asc (mk_expr ob_expr) n
      | Some M.Desc -> D.order_by_desc (mk_expr ob_expr) n
      | None -> D.order_by_bare (mk_expr ob_expr) n

    and mk_order_by = function
      | [] -> raise (Render_exn "ORDER BY with no expressions")
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.order_by_expr @@ mk_order_by_expr x)
            ~f:(fun acc x -> D.order_by_exprs acc @@ mk_order_by_expr x)
            xs

    and standalone_expr expr = D.standalone_expr @@ mk_expr expr

    (* [dcst] is short for "deconstruct": the [*_dcst] functions deconstruct an
       MQL AST node ([M.*]) and reconstruct it as the SQL DSL ([D.*]). *)
    (* The CTEs before a query, in the order that the SQL writes
       them, and the body that they belong to.  [recursive] belongs to the whole list, thus it is
       taken from the first one. *)
    and collect_ctes t =
      let rec collect acc = function
        | M.With { materialized; recursive; name; columns; query = q; body } ->
            collect ((materialized, recursive, name, columns, q) :: acc) body
        | body -> (List.rev acc, body)
      in
      collect [] t

    and mk_cte_def (materialized, _recursive, name, columns, q) =
      let columns =
        match columns with
        | [] -> D.no_cte_columns ()
        | cs -> D.cte_columns (mk_using_cols cs)
      in
      match materialized with
      | M.Cte_default -> D.cte_definition (mk_ident name) columns (statement_dcst q)
      | M.Cte_materialized ->
          D.cte_definition_materialized (mk_ident name) columns (statement_dcst q)
      | M.Cte_not_materialized ->
          D.cte_definition_not_materialized (mk_ident name) columns (statement_dcst q)

    and mk_ctes c cs =
      CCListLabels.fold_left
        ~init:(D.cte (mk_cte_def c))
        ~f:(fun acc d -> D.ctes acc (mk_cte_def d))
        cs

    and mk_recursive (_, recursive, _, _, _) =
      if recursive then D.recursive () else D.no_recursive ()

    and query_dcst t =
      match collect_ctes t with
      | [], body -> query_no_with_dcst body
      | c :: cs, body -> D.with_query (mk_recursive c) (mk_ctes c cs) (query_no_with_dcst body)

    and query_no_with_dcst = function
      | M.With _ -> raise (Render_exn "a WITH query is not valid in this position")
      | M.Query { body; order_by; limit; offset; locking } -> (
          (* The printer writes a limit before the locking clause.  Thus
             the last limit of the rule with a locking clause is always empty. *)
          match locking with
          | None -> D.query (query_body_dcst body) (order_by_opt_dcst order_by limit offset)
          | Some l ->
              D.query_locking
                (query_body_dcst body)
                (order_by_opt_dcst order_by limit offset)
                (mk_locking l)
                (D.eof ()))
      | M.Insert _ | M.Update _ | M.Delete _ ->
          raise (Render_exn "a data-modifying statement is not valid in this position")
      | M.Create_table _
      | M.Create_index _
      | M.Create_view _
      | M.Create_function _
      | M.Alter_function_set _
      | M.Alter_table _
      | M.Drop _
      | M.Comment_on _
      | M.Truncate _
      | M.Analyze _
      | M.Create_trigger _
      | M.Create_extension _
      | M.Set_stmt _
      | M.Set_constraints _
      | M.Grant _
      | M.Create_role _
      | M.Create_database _
      | M.Lock_table _ -> raise (Render_exn "a schema statement is not valid in this position")

    (* A data-modifying statement, with no CTE before it. *)
    and dml_stmt_dcst = function
      | M.Insert { table; columns; source; on_conflict; returning } ->
          D.insert_stmt
            (mk_table table)
            (mk_insert_columns columns)
            (mk_insert_source source)
            (mk_on_conflict on_conflict)
            (mk_returning returning)
      | M.Update { table; set_; from; where; returning } ->
          D.update_stmt
            (mk_table table)
            (mk_assignments set_)
            (match from with
            | [] -> D.update_no_from ()
            | from -> D.update_from (mk_tables from))
            (mk_dml_where where)
            (mk_returning returning)
      | M.Delete { table; using; where; returning } ->
          D.delete_stmt
            (mk_table table)
            (match using with
            | [] -> D.delete_no_using ()
            | using -> D.delete_using (mk_tables using))
            (mk_dml_where where)
            (mk_returning returning)
          (* The callers match the three data-modifying shapes before calling this,
       so the arms below are unreachable through them; naming each one keeps
       the match exhaustive, so a new statement shape cannot silently land
       here. *)
      | M.Create_table _
      | M.Create_index _
      | M.Create_view _
      | M.Create_function _
      | M.Create_trigger _
      | M.Create_extension _
      | M.Set_stmt _
      | M.Set_constraints _
      | M.Alter_function_set _
      | M.Alter_table _
      | M.Drop _
      | M.Comment_on _
      | M.Grant _
      | M.Create_role _
      | M.Create_database _
      | M.Truncate _
      | M.Analyze _
      | M.Lock_table _
      | M.With _
      | M.Query _ -> raise (Render_exn "not a data-modifying statement")

    (* A statement is a query or a data-modifying statement.  A statement can
       carry CTEs before it, and the body they belong to decides which
       production joins them. *)
    and statement_dcst t =
      match t with
      | M.Query _ -> D.stmt_query (query_dcst t)
      | M.Insert _ | M.Update _ | M.Delete _ -> D.stmt_dml (dml_stmt_dcst t)
      | M.With _ -> (
          match collect_ctes t with
          | [], body -> statement_dcst body
          | c :: cs, ((M.Insert _ | M.Update _ | M.Delete _) as body) ->
              D.with_dml (mk_recursive c) (mk_ctes c cs) (dml_stmt_dcst body)
          | _, _ -> D.stmt_query (query_dcst t))
      | _ -> statement_other_dcst t

    and statement_other_dcst = function
      | M.Create_table
          { if_not_exists; temp; name; body = M.Table_items items; partition; on_commit_drop } ->
          D.create_table_stmt
            (if temp then D.temp () else D.no_temp ())
            (mk_if_not_exists if_not_exists)
            (mk_table_name name)
            (mk_table_items items)
            (mk_table_partition_opt partition)
            (mk_on_commit_drop on_commit_drop)
      | M.Create_table
          { if_not_exists; temp; name; body = M.Table_as_query q; partition; on_commit_drop } -> (
          match partition with
          (* The grammar cannot produce a partition clause on a query table, so
             this is a guard for the renderer's own callers. *)
          | Some _ -> raise (Render_exn "a table as query takes no partition clause")
          | None ->
              D.create_table_as_stmt
                (if temp then D.temp () else D.no_temp ())
                (mk_if_not_exists if_not_exists)
                (mk_table_name name)
                (mk_on_commit_drop on_commit_drop)
                (insert_query_dcst q))
      | M.Create_table
          {
            if_not_exists;
            temp;
            name;
            body = M.Table_partition_of { parent; bound };
            partition;
            on_commit_drop = _;
          } -> (
          match partition with
          (* The grammar cannot produce a partition clause on a partition, so this is a guard for
             the renderer's own callers.  The write path ([Mql_sql.write]) skips the parity check
             the read path runs, so a dropped clause would execute as SQL that silently differs
             from the tree. *)
          | Some _ -> raise (Render_exn "a partition takes no partition clause")
          | None ->
              D.create_table_partition_of_stmt
                (if temp then D.temp () else D.no_temp ())
                (mk_if_not_exists if_not_exists)
                (mk_table_name name)
                (mk_table_name parent)
                (mk_partition_bound bound))
      | M.Create_table
          {
            if_not_exists;
            temp = _;
            name;
            body = M.Table_foreign { items; server; options };
            partition;
            on_commit_drop = _;
          } -> (
          match partition with
          (* The grammar cannot produce a partition clause on a foreign table, so
             this is a guard for the renderer's own callers. *)
          | Some _ -> raise (Render_exn "a foreign table takes no partition clause")
          | None ->
              D.create_foreign_table_stmt
                (mk_if_not_exists if_not_exists)
                (mk_table_name name)
                (mk_table_items items)
                (mk_ident server)
                (mk_foreign_options options))
      | M.Create_index
          {
            unique;
            concurrently;
            if_not_exists;
            name;
            table;
            method_;
            columns;
            include_;
            nulls_not_distinct;
            where;
          } ->
          D.create_index_stmt
            (if unique then D.unique () else D.no_unique ())
            (if concurrently then D.concurrently () else D.no_concurrently ())
            (mk_if_not_exists if_not_exists)
            (match name with
            | None -> D.no_index_name ()
            | Some n -> D.index_name n)
            (mk_table_name table)
            (match method_ with
            | None -> D.no_index_method ()
            | Some m -> D.index_method m)
            (mk_index_elements columns)
            (match include_ with
            | [] -> D.no_index_include ()
            | cs -> D.index_include (mk_using_cols cs))
            (if nulls_not_distinct then D.index_nulls_not_distinct () else D.no_index_nulls ())
            (match where with
            | None -> D.no_index_where ()
            | Some e -> D.index_where (mk_expr e))
      | M.Create_view { or_replace; name; columns; query } ->
          D.create_view_stmt
            (if or_replace then D.or_replace () else D.no_or_replace ())
            (mk_table_name name)
            (match columns with
            | [] -> D.no_view_columns ()
            | cs -> D.view_columns (mk_using_cols cs))
            (statement_dcst query)
      | M.Create_function { or_replace; name; args; clauses } ->
          D.create_function_stmt
            (if or_replace then D.or_replace () else D.no_or_replace ())
            (mk_table_name name)
            (mk_func_args args)
            (mk_func_clauses clauses)
      | M.Create_trigger { or_replace; name; timing; events; table; for_each_row; execute } ->
          D.create_trigger_stmt
            (if or_replace then D.or_replace () else D.no_or_replace ())
            name
            (match timing with
            | M.Trg_before -> D.trg_before ()
            | M.Trg_after -> D.trg_after ()
            | M.Trg_instead_of -> D.trg_instead_of ())
            (mk_trigger_events events)
            (mk_table_name table)
            (if for_each_row then D.for_each_row () else D.no_for_each ())
            (mk_table_name execute)
      | M.Create_extension { if_not_exists; name } ->
          D.create_extension_stmt (mk_if_not_exists if_not_exists) name
      | M.Set_stmt { local; name; value } ->
          D.set_stmt
            (if local then D.local () else D.no_local ())
            (mk_table_name name)
            (mk_expr value)
      | M.Alter_function_set { name; setting; values } ->
          D.alter_function_set_stmt (mk_table_name name) (mk_ident setting) (mk_expr_list values)
      | M.Alter_table { if_exists; only; name; actions } ->
          D.alter_table_stmt
            (mk_if_exists if_exists)
            (if only then D.yes_only () else D.no_only ())
            (mk_table_name name)
            (mk_alter_actions actions)
      (* [drop table] and [drop index] and [drop view] have their own
         productions, because each of them can be [concurrently]. *)
      | M.Drop
          {
            object_ = [ o ];
            concurrently;
            empty_args = false;
            if_exists;
            names;
            on_table = None;
            behavior;
          }
        when CCList.mem ~eq:CCString.equal o.M.name [ "table"; "index"; "view" ] -> (
          let c = if concurrently then D.concurrently () else D.no_concurrently () in
          let e = mk_if_exists if_exists in
          let ns = mk_table_names names in
          let b = mk_drop_behavior behavior in
          match o.M.name with
          | "table" -> D.drop_table_stmt c e ns b
          | "index" -> D.drop_index_stmt c e ns b
          | _ -> D.drop_view_stmt c e ns b)
      | M.Drop
          {
            concurrently = true;
            object_ = _;
            empty_args = _;
            if_exists = _;
            names = _;
            on_table = _;
            behavior = _;
          } -> raise (Render_exn "only a table, an index or a view drops concurrently")
      | M.Drop { object_; concurrently = false; empty_args; if_exists; names; on_table; behavior }
        ->
          D.drop_stmt
            (mk_drop_object object_)
            (mk_if_exists if_exists)
            (mk_table_names names)
            (if empty_args then D.empty_args () else D.no_empty_args ())
            (match on_table with
            | None -> D.no_drop_on ()
            | Some t -> D.drop_on (mk_table_name t))
            (mk_drop_behavior behavior)
      | M.Set_constraints { names = []; deferred } ->
          D.set_constraints_all_stmt (mk_constraints_mode deferred)
      | M.Set_constraints { names; deferred } ->
          D.set_constraints_stmt (mk_table_names names) (mk_constraints_mode deferred)
      | M.Truncate { names; behavior } ->
          D.truncate_stmt (mk_table_names names) (mk_drop_behavior behavior)
      | M.Analyze [] -> D.analyze_all_stmt ()
      | M.Analyze ns -> D.analyze_stmt (mk_table_names ns)
      | M.Lock_table { name; mode } ->
          D.lock_table_stmt
            (mk_table_name name)
            (match mode with
            | None -> D.no_lock_table_mode ()
            | Some m -> D.yes_lock_table_mode m)
      | M.Comment_on { object_; name; comment = Some c } ->
          D.comment_on_stmt (mk_comment_object object_) (mk_table_name name) c
      | M.Comment_on { object_; name; comment = None } ->
          D.comment_on_null_stmt (mk_comment_object object_) (mk_table_name name)
      | M.Grant { revoke = false; privilege; columns; table; role } ->
          D.grant_stmt
            (mk_privilege privilege)
            (mk_grant_columns columns)
            (mk_table_name table)
            (mk_ident role)
      | M.Grant { revoke = true; privilege; columns; table; role } ->
          D.revoke_stmt
            (mk_privilege privilege)
            (mk_grant_columns columns)
            (mk_table_name table)
            (mk_ident role)
      | M.Create_role { name; login; password } ->
          D.create_role_stmt
            (mk_ident name)
            (if login then D.login () else D.no_login ())
            (match password with
            | None -> D.no_password ()
            | Some p -> D.password p)
      | M.Create_database n -> D.create_database_stmt (mk_ident n)
      (* [statement_dcst] handles these before it calls this function. *)
      | M.Insert _ | M.Update _ | M.Delete _ | M.With _ | M.Query _ ->
          raise (Render_exn "not a schema statement")

    and mk_table_name { M.qualifier; base } =
      match qualifier with
      | None -> D.table_name_bare (mk_ident base)
      | Some q -> D.table_name_qualified (mk_ident q) (mk_ident base)

    and mk_table_names = function
      | [] -> raise (Render_exn "statement names no table")
      | n :: ns ->
          CCListLabels.fold_left
            ~init:(D.table_name_one (mk_table_name n))
            ~f:(fun acc n -> D.table_name_more acc (mk_table_name n))
            ns

    and mk_if_exists b = if b then D.yes_if_exists () else D.no_if_exists ()
    and mk_if_not_exists b = if b then D.yes_if_not_exists () else D.no_if_not_exists ()

    and mk_drop_behavior = function
      | None -> D.no_drop_behavior ()
      | Some M.Cascade -> D.drop_cascade ()
      | Some M.Restrict -> D.drop_restrict ()

    and mk_type_args = function
      | [] -> D.no_type_args ()
      | [ i ] -> D.type_arg_one i
      | [ i; j ] -> D.type_arg_two i j
      | _ -> raise (Render_exn "a type takes at most two arguments")

    and mk_array_dims n =
      if n <= 0 then D.no_array_dims () else D.more_array_dims (mk_array_dims (n - 1))

    and mk_type_extra = function
      | M.No_extra -> D.no_type_extra ()
      | M.With_time_zone -> D.type_with_time_zone ()
      | M.Without_time_zone -> D.type_without_time_zone ()
      | M.Precision -> D.type_precision ()
      | M.Varying -> D.type_varying ()

    (* The two rules of [type_word] make the same value.  Thus the printer
       always uses the rule that writes a name. *)
    and mk_type_word i = D.type_word_ident (mk_ident i)

    and mk_cast_type { M.type_ident; type_extra; args; array_dims } =
      (match type_ident.M.qualifier with
      | None -> ()
      | Some _ -> raise (Render_exn "a cast to a qualified type has no rendering"));
      D.cast_type
        (mk_type_word type_ident.M.base)
        (mk_type_args args)
        (mk_type_extra type_extra)
        (mk_array_dims array_dims)

    and mk_type_name { M.type_ident; type_extra; args; array_dims } =
      D.type_name
        (mk_table_name type_ident)
        (mk_type_args args)
        (mk_type_extra type_extra)
        (mk_array_dims array_dims)

    and mk_ref_act = function
      | M.Ract_cascade -> D.ract_cascade ()
      | M.Ract_restrict -> D.ract_restrict ()
      | M.Ract_set_null -> D.ract_set_null ()
      | M.Ract_set_default -> D.ract_set_default ()
      | M.Ract_no_action -> D.ract_no_action ()

    and mk_ref_actions acts =
      CCListLabels.fold_left
        ~init:(D.no_ref_actions ())
        ~f:(fun acc a ->
          D.more_ref_actions
            acc
            (match a with
            | M.On_delete r -> D.ref_on_delete (mk_ref_act r)
            | M.On_update r -> D.ref_on_update (mk_ref_act r)))
        acts

    and mk_references { M.ref_table; ref_columns; ref_actions } =
      match ref_columns with
      | [] -> D.references_bare (mk_table_name ref_table) (mk_ref_actions ref_actions)
      | cs ->
          D.references_cols
            (mk_table_name ref_table)
            (mk_using_cols cs)
            (mk_ref_actions ref_actions)

    and mk_column_constraint = function
      | M.Not_null -> D.col_not_null ()
      | M.Null_allowed -> D.col_null ()
      | M.Default_value e -> D.col_default (mk_expr e)
      | M.Col_primary_key -> D.col_primary_key ()
      | M.Col_unique -> D.col_unique ()
      | M.Col_check e -> D.col_check (mk_expr e)
      | M.Col_references r -> D.col_references (mk_references r)
      | M.Col_named_constraint (n, c) -> D.col_named_constraint n (mk_column_constraint c)
      | M.Col_generated_stored e -> D.col_generated_stored (mk_expr e)
      | M.Col_generated_identity -> D.col_generated_identity ()

    and mk_column_constraints = function
      | [] -> D.no_column_constraints ()
      | cs ->
          CCListLabels.fold_left
            ~init:(D.no_column_constraints ())
            ~f:(fun acc c -> D.more_column_constraints acc (mk_column_constraint c))
            cs

    and mk_column_def { M.col_name; col_type; col_constraints } =
      D.column_def
        (mk_ident col_name)
        (mk_type_name col_type)
        (mk_column_constraints col_constraints)

    and mk_table_constraint = function
      | M.Tbl_primary_key { columns; include_ } ->
          D.tbl_primary_key
            (mk_using_cols columns)
            (match include_ with
            | [] -> D.no_index_include ()
            | cs -> D.index_include (mk_using_cols cs))
      | M.Tbl_primary_key_using_index i -> D.tbl_primary_key_using_index (mk_ident i)
      | M.Tbl_unique_using_index i -> D.tbl_unique_using_index (mk_ident i)
      | M.Tbl_unique { columns; include_ } ->
          D.tbl_unique
            (mk_using_cols columns)
            (match include_ with
            | [] -> D.no_index_include ()
            | cs -> D.index_include (mk_using_cols cs))
      | M.Tbl_check e -> D.tbl_check (mk_expr e)
      | M.Tbl_foreign_key (cs, r) -> D.tbl_foreign_key (mk_using_cols cs) (mk_references r)
      | M.Tbl_named_constraint (n, c) -> D.tbl_named_constraint n (mk_table_constraint c)

    and mk_table_items = function
      | [] -> raise (Render_exn "CREATE TABLE with no columns")
      | i :: is ->
          let one = function
            | M.Column_def c -> D.item_column (mk_column_def c)
            | M.Table_constraint c -> D.item_constraint (mk_table_constraint c)
          in
          CCListLabels.fold_left
            ~init:(D.table_item_one (one i))
            ~f:(fun acc i -> D.table_item_more acc (one i))
            is

    and mk_alter_column_action = function
      | M.Set_not_null -> D.set_not_null ()
      | M.Drop_not_null -> D.drop_not_null ()
      | M.Set_default e -> D.set_default (mk_expr e)
      | M.Drop_default -> D.drop_default ()
      | M.Set_type { type_; using = None } -> D.set_type (mk_type_name type_)
      | M.Set_type { type_; using = Some e } -> D.set_type_using (mk_type_name type_) (mk_expr e)

    and mk_alter_action = function
      | M.Add_column { if_not_exists; column } ->
          D.add_column (mk_if_not_exists if_not_exists) (mk_column_def column)
      | M.Drop_column { if_exists; name; behavior } ->
          D.drop_column (mk_if_exists if_exists) name (mk_drop_behavior behavior)
      | M.Alter_column (n, a) -> D.alter_column n (mk_alter_column_action a)
      | M.Add_constraint c -> D.add_constraint (mk_table_constraint c)
      | M.Add_constraint_not_valid c -> D.add_constraint_not_valid (mk_table_constraint c)
      | M.Drop_constraint { if_exists; name; behavior } ->
          D.drop_constraint (mk_if_exists if_exists) name (mk_drop_behavior behavior)
      | M.Rename_to n -> D.rename_to n
      | M.Rename_column (a, b) -> D.rename_column a b
      | M.Set_options os -> D.set_options (mk_table_options os)
      | M.Attach_partition { name; bound } ->
          D.attach_partition (mk_table_name name) (mk_partition_bound bound)

    and mk_alter_actions = function
      | [] -> raise (Render_exn "ALTER TABLE with no actions")
      | a :: as_ ->
          CCListLabels.fold_left
            ~init:(D.alter_action_one (mk_alter_action a))
            ~f:(fun acc a -> D.alter_action_more acc (mk_alter_action a))
            as_

    (* PostgreSQL takes a name or a call as an entry of an index as it is, and
       wants parentheses around each other form, as in
       [create index i on t ((data ->> 'k'))].  [mk_expr] gives [Settle] the
       choice of the two forms and [Settle] picks the bare one, because this
       grammar reads an entry as a plain expression and reads the bare form
       again as the same tree.  PostgreSQL refuses it.  Choose the parenthesised
       form. *)
    and mk_index_expr = function
      | (M.Identifier _ | M.Func _) as e -> mk_expr e
      | e -> D.paren (mk_expr e)

    and mk_index_element { M.idx_expr; idx_opclass; idx_order } =
      let c =
        match idx_opclass with
        | None -> D.no_index_opclass ()
        | Some c -> D.index_opclass c
      in
      match idx_order with
      | None -> D.index_element (mk_index_expr idx_expr) c
      | Some M.Asc -> D.index_element_asc (mk_index_expr idx_expr) c
      | Some M.Desc -> D.index_element_desc (mk_index_expr idx_expr) c

    and mk_index_elements = function
      | [] -> raise (Render_exn "CREATE INDEX with no columns")
      | e :: es ->
          CCListLabels.fold_left
            ~init:(D.index_element_one (mk_index_element e))
            ~f:(fun acc e -> D.index_element_more acc (mk_index_element e))
            es

    (* An object of more than one word has its own rule.  An object of one word
       uses the general rule. *)
    (* The word is a keyword of this grammar for a table and for a column.  Thus
       each one has its own rule. *)
    and mk_comment_object o =
      match o.M.name with
      | "table" -> D.comment_object_table ()
      | "column" -> D.comment_object_column ()
      | _ -> D.comment_object_ident (mk_ident o)

    (* Each of these words is a keyword of this grammar.  Thus each one has its
       own rule. *)
    and mk_privilege p =
      match p.M.name with
      | "select" -> D.privilege_select ()
      | "insert" -> D.privilege_insert ()
      | "update" -> D.privilege_update ()
      | "delete" -> D.privilege_delete ()
      | n -> raise (Render_exn ("a grant of " ^ n ^ " has no rendering"))

    and mk_grant_columns = function
      | [] -> D.no_grant_columns ()
      | cs -> D.grant_columns (mk_using_cols cs)

    and mk_drop_object = function
      | [ f; t ] when CCString.equal f.M.name "foreign" && CCString.equal t.M.name "table" ->
          D.drop_object_foreign_table ()
      | [ o ] -> (
          match o.M.name with
          | "trigger" -> D.drop_object_trigger ()
          | "function" -> D.drop_object_function ()
          | "type" -> D.drop_object_type ()
          | "extension" -> D.drop_object_extension ()
          | _ -> D.drop_object_one o)
      | _ -> raise (Render_exn "a DROP of this object has no rendering")

    and mk_func_args = function
      | [] -> D.no_func_args ()
      | a :: as_ ->
          let one { M.arg_name; arg_type } =
            match arg_name with
            | None -> D.func_arg_unnamed (mk_type_name arg_type)
            | Some n -> D.func_arg_named (mk_ident n) (mk_type_name arg_type)
          in
          CCListLabels.fold_left
            ~init:(D.func_arg_one (one a))
            ~f:(fun acc a -> D.func_arg_more acc (one a))
            as_

    and mk_func_return = function
      | M.Ret_type t -> D.ret_type (mk_type_name t)
      | M.Ret_setof t -> D.ret_setof (mk_type_name t)
      | M.Ret_trigger -> D.ret_trigger ()
      | M.Ret_table [] -> raise (Render_exn "RETURNS TABLE with no columns")
      | M.Ret_table (c :: cs) ->
          D.ret_table
            (CCListLabels.fold_left
               ~init:(D.table_col_one (mk_column_def c))
               ~f:(fun acc c -> D.table_col_more acc (mk_column_def c))
               cs)

    and mk_func_clauses cs =
      CCListLabels.fold_left
        ~init:(D.no_func_clauses ())
        ~f:(fun acc c ->
          D.more_func_clauses
            acc
            (match c with
            | M.Func_returns r -> D.fc_returns (mk_func_return r)
            | M.Func_language l -> D.fc_language (mk_ident l)
            | M.Func_as_body b -> D.fc_as_body b
            | M.Func_as_string b -> D.fc_as_string b
            | M.Func_volatility v -> (
                match v.M.name with
                | "immutable" -> D.fc_immutable ()
                | "stable" -> D.fc_stable ()
                | "volatile" -> D.fc_volatile ()
                (* The grammar reads only the three words above, so this is an
                   AST no parser would produce. *)
                | other -> raise (Render_exn ("a function volatility of " ^ other)))
            | M.Func_strict -> D.fc_strict ()
            | M.Func_security k -> D.fc_security (mk_ident k)
            | M.Func_parallel k -> D.fc_parallel (mk_ident k)
            | M.Func_cost i -> D.fc_cost i
            | M.Func_rows i -> D.fc_rows i))
        cs

    and mk_trigger_events = function
      | [] -> raise (Render_exn "CREATE TRIGGER with no event")
      | e :: es ->
          let one = function
            | M.Trg_insert -> D.trg_insert ()
            | M.Trg_update [] -> D.trg_update ()
            | M.Trg_update cs -> D.trg_update_of (mk_using_cols cs)
            | M.Trg_delete -> D.trg_delete ()
            | M.Trg_truncate -> D.trg_truncate ()
          in
          CCListLabels.fold_left
            ~init:(D.trg_event_one (one e))
            ~f:(fun acc e -> D.trg_event_more acc (one e))
            es

    and mk_dml_where = function
      | None -> D.dml_no_where ()
      | Some e -> D.dml_where (mk_expr e)

    and mk_returning = function
      | None -> D.no_returning ()
      | Some sl -> D.returning (select_list_columns sl)

    and mk_insert_columns = function
      | [] -> D.insert_no_columns ()
      | cs -> D.insert_columns (mk_using_cols cs)

    and mk_assignment = function
      | M.Assign (c, e) -> D.assignment (mk_ident c) (mk_expr e)
      | M.Assign_row ([], _) | M.Assign_row (_, []) ->
          raise (Render_exn "a row assignment with no column or no value")
      | M.Assign_row (cs, es) -> D.assignment_row (mk_using_cols cs) (mk_expr_list es)

    and mk_assignments = function
      | [] -> raise (Render_exn "SET with no assignments")
      | a :: rest ->
          CCListLabels.fold_left
            ~init:(D.assignment_one (mk_assignment a))
            ~f:(fun acc a -> D.assignment_more acc (mk_assignment a))
            rest

    and mk_values_row es = D.values_row (mk_in_list es)

    and mk_insert_source = function
      | M.Insert_default_values -> D.insert_default_values ()
      | M.Insert_query q -> D.insert_source_query (insert_query_dcst q)
      | M.Insert_values [] -> raise (Render_exn "VALUES with no rows")
      | M.Insert_values (r :: rs) ->
          D.insert_values
            (CCListLabels.fold_left
               ~init:(D.values_row_one (mk_values_row r))
               ~f:(fun acc r -> D.values_row_more acc (mk_values_row r))
               rs)

    (* An INSERT's source query cannot start with a paren -- see the grammar. *)
    and insert_query_dcst = function
      | M.Query { body; order_by; limit; offset; locking } -> (
          match locking with
          | None ->
              D.insert_query_body
                (query_body_no_paren_dcst body)
                (order_by_opt_dcst order_by limit offset)
          | Some l ->
              D.insert_query_body_locking
                (query_body_no_paren_dcst body)
                (order_by_opt_dcst order_by limit offset)
                (mk_locking l)
                (D.eof ()))
      (* A query with CTEs before it.  The CTEs are collected the same way
         as for a plain query; only the production that joins them to the body
         is the one of this position. *)
      | M.With _ as q -> (
          match collect_ctes q with
          | [], _ -> raise (Render_exn "a WITH query with no CTE has no rendering")
          | c :: cs, body -> D.insert_query_with (mk_recursive c) (mk_ctes c cs) (query_dcst body))
      | M.Insert _ | M.Update _ | M.Delete _ ->
          raise (Render_exn "a data-modifying statement is not valid as an INSERT source")
      | M.Create_table _
      | M.Create_index _
      | M.Create_view _
      | M.Create_function _
      | M.Alter_function_set _
      | M.Alter_table _
      | M.Drop _
      | M.Comment_on _
      | M.Truncate _
      | M.Analyze _
      | M.Create_trigger _
      | M.Create_extension _
      | M.Set_stmt _
      | M.Set_constraints _
      | M.Grant _
      | M.Create_role _
      | M.Create_database _
      | M.Lock_table _ -> raise (Render_exn "a schema statement is not valid as an INSERT source")

    and query_body_no_paren_dcst = function
      | M.Select sc -> D.qbnp_term (D.utnp_select (select_core_dcst sc))
      | M.Set_op { op; all; left; right } ->
          if all then
            D.qbnp_set_op_all (query_body_no_paren_dcst left) (mk_set_op op) (union_term_dcst right)
          else D.qbnp_set_op (query_body_no_paren_dcst left) (mk_set_op op) (union_term_dcst right)
      | M.Paren _ -> raise (Render_exn "an INSERT source query may not be parenthesized")

    and mk_on_conflict = function
      | None -> D.no_on_conflict ()
      | Some { M.target; action } ->
          let target =
            match target with
            | M.On_conflict_none -> D.no_conflict_target ()
            | M.On_conflict_elems { elems = []; where = _ } ->
                raise (Render_exn "a conflict target with no entry")
            | M.On_conflict_elems { elems; where = None } ->
                D.conflict_target (mk_conflict_elems elems)
            | M.On_conflict_elems { elems; where = Some e } ->
                D.conflict_target_where (mk_conflict_elems elems) (mk_expr e)
            | M.On_conflict_constraint n -> D.conflict_target_constraint (mk_ident n)
          in
          let action =
            match action with
            | M.Do_nothing -> D.do_nothing ()
            | M.Do_update { set_; where = None } -> D.do_update (mk_assignments set_)
            | M.Do_update { set_; where = Some e } ->
                D.do_update_where (mk_assignments set_) (mk_expr e)
          in
          D.on_conflict target action

    and mk_locking { M.strength; wait; of_ } =
      let strength =
        match strength with
        | M.Lock_update -> D.lock_update ()
        | M.Lock_no_key_update -> D.lock_no_key_update ()
        | M.Lock_share -> D.lock_share ()
        | M.Lock_key_share -> D.lock_key_share ()
      in
      let wait =
        match wait with
        | M.Lock_wait -> D.lock_wait_default ()
        | M.Lock_nowait -> D.lock_nowait ()
        | M.Lock_skip_locked -> D.lock_skip_locked ()
      in
      let of_ =
        match of_ with
        | [] -> D.no_lock_of ()
        | ns -> D.lock_of (mk_using_cols ns)
      in
      D.locking strength of_ wait

    and mk_offset_opt = function
      | None -> D.no_offset ()
      | Some (A.Int i) -> D.offset i
      | Some (A.Variable v) -> D.offset_variable v
      | Some _ -> raise (Render_exn "OFFSET must be an integer or a variable")

    and order_by_opt_dcst order_by limit offset =
      let limit_opt =
        match (limit, offset) with
        | Some (A.Int limit), o -> D.limit limit (mk_offset_opt o)
        | Some (A.Variable v), o -> D.limit_variable v (mk_offset_opt o)
        | Some _, _ -> raise (Render_exn "LIMIT must be an integer or a variable")
        | None, None -> D.eof ()
        | None, Some (A.Int i) -> D.offset_no_limit (D.offset_only i)
        | None, Some (A.Variable v) -> D.offset_no_limit (D.offset_only_variable v)
        | None, Some _ -> raise (Render_exn "OFFSET must be an integer or a variable")
      in
      match order_by with
      | Some order_by -> D.order_by (mk_order_by order_by) limit_opt
      | None -> D.no_order_by limit_opt

    and mk_set_op = function
      | M.Union -> D.set_op_union ()
      | M.Except -> D.set_op_except ()
      | M.Intersect -> D.set_op_intersect ()

    and query_body_dcst = function
      | M.Select sc -> D.qb_term (D.ut_select (select_core_dcst sc))
      | M.Paren q -> D.qb_term (D.ut_paren (query_dcst q))
      | M.Set_op { op; all; left; right } ->
          if all then D.qb_set_op_all (query_body_dcst left) (mk_set_op op) (union_term_dcst right)
          else D.qb_set_op (query_body_dcst left) (mk_set_op op) (union_term_dcst right)

    and union_term_dcst = function
      | M.Select sc -> D.ut_select (select_core_dcst sc)
      | M.Paren q -> D.ut_paren (query_dcst q)
      | M.Set_op _ -> raise (Render_exn "a set operation is not valid in this position")

    and mk_distinct = function
      | None -> D.no_distinct ()
      | Some M.Distinct -> D.distinct ()
      | Some (M.Distinct_on es) -> D.distinct_on (mk_expr_list es)

    and select_core_dcst { M.distinct; select_list; from; where; group_by; having } =
      let group_by_opt =
        match (group_by, having) with
        | Some (M.Group_exprs exprs), None -> D.group_by_no_having (mk_expr_list exprs)
        | Some (M.Group_exprs exprs), Some expr ->
            D.group_by_having (mk_expr_list exprs) (mk_expr expr)
        | Some (M.Group_sets gs), None -> D.group_sets_no_having (mk_grouping_sets gs)
        | Some (M.Group_sets gs), Some expr ->
            D.group_sets_having (mk_grouping_sets gs) (mk_expr expr)
        | None, None -> D.no_group_by ()
        | None, Some expr -> D.having_no_group_by (mk_expr expr)
      in
      let where_opt =
        match where with
        | Some expr -> D.where (mk_expr expr) group_by_opt
        | None -> D.no_where group_by_opt
      in
      (* An empty [from] is how the AST spells a [FROM]-less select. *)
      let distinct = mk_distinct distinct in
      match from with
      | [] -> D.select_core_no_from distinct (select_list_columns select_list) where_opt
      | from -> D.select_core distinct (select_list_columns select_list) (mk_tables from) where_opt

    let start t = D.start (statement_dcst t)

    let mk_query_list x xs =
      CCListLabels.fold_left
        ~init:(D.query_list_one @@ statement_dcst x)
        ~f:(fun acc x -> D.query_list_more acc @@ statement_dcst x)
        xs

    let queries x xs = D.queries (mk_query_list x xs)
  end

  (* The rendering boundary.  [src] is the shown AST rather than query text --
     there is no source string on this path -- so a failure still says which
     value could not be rendered.  [Render_exn] is caught here and nowhere
     else. *)
  let render ~src f =
    try
      match f () with
      | None -> Error (`Error (None, src (), "no rendering for this query"))
      | Some m -> Ok m
    with Render_exn msg -> Error (`Error (None, src (), msg))

  let to_string t =
    render ~src:(fun () -> show t) (fun () -> Mql_parser.Settle.start @@ AST2DCST.start t)
    |> CCResult.map (fun m -> (new print)#visit_start m)

  let to_string_multi = function
    (* No queries renders as no text; the grammar cannot produce an empty list,
       so this is total rather than an error case. *)
    | [] -> Ok ""
    | x :: xs ->
        render
          ~src:(fun () -> CCString.concat "; " (CCList.map show (x :: xs)))
          (fun () -> Mql_parser.Settle.queries @@ AST2DCST.queries x xs)
        |> CCResult.map (fun m -> (new print)#visit_queries m)

  let expr_to_string expr =
    render
      ~src:(fun () -> Mql_ast.show_expr expr)
      (fun () -> Mql_parser.Settle.standalone_expr @@ AST2DCST.standalone_expr expr)
    |> CCResult.map (fun m -> (new print)#visit_standalone_expr m)
end

module Build = struct
  module M = Mql_ast

  (* Expression builders *)
  (* The builder API takes plain names: code constructing a query in OCaml wants
     an ordinary identifier, and a name needing quotes would not survive
     [Mql_to_pgsql]'s charset guard anyway. *)
  let ident name = { M.name; quoted = false }
  let id s = M.Identifier (ident s)
  let string s = M.String s
  let int i = M.Int i
  let float f = M.Float f
  let true_ = M.True
  let false_ = M.False
  let null = M.Null
  let eq e1 e2 = M.Eq (e1, e2)
  let not_eq e1 e2 = M.Not_eq (e1, e2)
  let gt e1 e2 = M.Gt (e1, e2)
  let gte e1 e2 = M.Gte (e1, e2)
  let lt e1 e2 = M.Lt (e1, e2)
  let lte e1 e2 = M.Lte (e1, e2)
  let and_ e1 e2 = M.And (e1, e2)
  let or_ e1 e2 = M.Or (e1, e2)
  let not_ e = M.Not e
  let is e1 e2 = M.Is (e1, e2)
  let is_not e1 e2 = M.Is_not (e1, e2)
  let in_ e es = M.In (e, es)
  let in_query e q = M.In_query (e, q)
  let field table column = M.Field_select (id table, ident column)

  let func name args =
    M.Func
      {
        M.qualifier = None;
        name = ident name;
        distinct = false;
        args = M.Func_exprs (CCList.map (fun e -> M.Arg e) args);
        agg_order_by = None;
        filter = None;
        over = None;
      }

  let count_star =
    M.Func
      {
        M.qualifier = None;
        name = M.ident "count";
        distinct = false;
        args = M.Func_star;
        agg_order_by = None;
        filter = None;
        over = None;
      }

  (* Table builders *)
  let table ?alias name =
    {
      M.fe_table =
        M.Table_ref
          { M.table_qualifier = None; name = ident name; alias = CCOption.map ident alias };
      fe_joins = [];
    }

  (* Group builders *)
  let group_by exprs = M.Group_exprs exprs

  (* Order builders *)
  let order_by ?order ?nulls expr = { M.ob_expr = expr; ob_order = order; ob_nulls = nulls }

  (* Column builders *)
  let col ?alias expr = { M.expr; alias = CCOption.map ident alias }
  let columns cs = M.Columns cs
  let star = M.Star

  (* Query builder.  [joins] attaches to the first entry of [from]. Each caller of
     this builder writes that form. *)
  let select ?where ?joins ?group_by ?having ?order_by ?limit ~from ~cols () =
    let from =
      match (from, joins) with
      | _, (None | Some []) -> from
      | [], Some _ -> invalid_arg "Mql.Build.select: a join with no table before it"
      | entry :: rest, Some js -> { entry with M.fe_joins = entry.M.fe_joins @ js } :: rest
    in
    M.Query
      {
        body = M.Select { M.distinct = None; select_list = cols; from; where; group_by; having };
        order_by;
        limit = CCOption.map (fun l -> M.Int l) limit;
        offset = None;
        locking = None;
      }

  let query_body = function
    | M.Query { body; order_by = _; offset = _; limit = _; locking = _ } -> body
    | M.With _ -> invalid_arg "Mql.Build.query_body: operand cannot be a WITH query"
    | M.Insert _
    | M.Update _
    | M.Delete _
    | M.Create_table _
    | M.Create_index _
    | M.Create_view _
    | M.Create_function _
    | M.Create_trigger _
    | M.Create_extension _
    | M.Set_stmt _
    | M.Set_constraints _
    | M.Grant _
    | M.Create_role _
    | M.Create_database _
    | M.Alter_function_set _
    | M.Alter_table _
    | M.Drop _
    | M.Comment_on _
    | M.Truncate _
    | M.Analyze _
    | M.Lock_table _ -> invalid_arg "Mql.Build.query_body: operand must be a query"

  let union_all a b =
    M.Query
      {
        body = M.Set_op { op = M.Union; all = true; left = query_body a; right = query_body b };
        order_by = None;
        limit = None;
        offset = None;
        locking = None;
      }

  (* Schema statement builders. The statement comes from the tree and not from pasted text, thus
     a name that data gives goes in as an identifier and the writer renders it. *)
  (* [drop_table ?if_exists n] builds [DROP TABLE [IF EXISTS] n]; [if_exists] defaults to false,
     the plain statement. *)
  let drop_table ?(if_exists = false) name =
    M.Drop
      {
        object_ = [ ident "table" ];
        concurrently = false;
        empty_args = false;
        if_exists;
        names = [ { M.qualifier = None; base = ident name } ];
        on_table = None;
        behavior = None;
      }

  let analyze_table name = M.Analyze [ { M.qualifier = None; base = ident name } ]

  let create_temp_table_as ?(on_commit_drop = false) name query =
    M.Create_table
      {
        if_not_exists = false;
        temp = true;
        name = { M.qualifier = None; base = ident name };
        body = M.Table_as_query query;
        partition = None;
        on_commit_drop;
      }

  (* [LOCK TABLE t IN <mode> MODE], ACCESS EXCLUSIVE unless the caller names another mode. The
     default is the strongest mode, so a caller that does not think about lock strength cannot
     quietly take a weaker lock. *)
  let lock_table ?(mode = M.Lock_mode_access_exclusive) name =
    M.Lock_table { name = { M.qualifier = None; base = ident name }; mode = Some mode }

  (* [FOR VALUES FROM ('<from>') TO ('<to>')] -- the bound of one range partition. *)
  let range_bound ~from ~to_ = M.Pb_range ([ string from ], [ string to_ ])

  let create_table_partition_of ?(if_not_exists = false) ~parent ~bound name =
    M.Create_table
      {
        if_not_exists;
        temp = false;
        name = { M.qualifier = None; base = ident name };
        body = M.Table_partition_of { parent = { M.qualifier = None; base = ident parent }; bound };
        partition = None;
        on_commit_drop = false;
      }

  let delete_where ~where name =
    M.Delete
      {
        table = { M.table_qualifier = None; name = ident name; alias = None };
        using = [];
        where = Some where;
        returning = None;
      }

  let insert_select ~query name =
    M.Insert
      {
        table = { M.table_qualifier = None; name = ident name; alias = None };
        columns = [];
        source = M.Insert_query query;
        on_conflict = None;
        returning = None;
      }
end

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
    | With { body; _ } -> limit body
    | Query { limit; _ } -> limit

  let rec set_limit limit t =
    let open Mql_ast in
    match t with
    | With { materialized; name; query; body } ->
        With { materialized; name; query; body = set_limit limit body }
    | Query { body; order_by; limit = _ } -> Query { body; order_by; limit = Some limit }

  let state checkpoint =
    let module I = Mql_parser.MenhirInterpreter in
    match I.top checkpoint with
    | None -> 0
    | Some (I.Element (s, _, _, _)) -> I.number s

  let position checkpoint =
    let module I = Mql_parser.MenhirInterpreter in
    match I.top checkpoint with
    | None -> None
    | Some (I.Element (_, _, { Lexing.pos_lnum; pos_bol; _ }, _)) ->
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
           with Not_found -> (position env, CCInt.to_string (state env)))
    | I.Accepted ast -> Ok ast
    | I.Rejected -> assert false

  let of_string s =
    (* Guarantee there is a new line at the end of the file.  The HCL spec
       requires a new line after a block but looks like it will accept files that do
       not have a new line. *)
    let lexbuf = Sedlexing.Utf8.from_string (s ^ "\n") in
    let lexer = Sedlexing.with_tokenizer Mql_lexer.token lexbuf in
    match
      loop lexer lexbuf (Mql_parser.Incremental.start (fst @@ Sedlexing.lexing_positions lexbuf))
    with
    | Ok r -> Ok r
    | Error (pos, err) -> Error (`Error (pos, s, CCString.trim err))

  let starts_with ls s = CCList.exists (fun prefix -> CCString.starts_with ~prefix s) ls
  let escape_str = CCString.replace ~which:`All ~sub:"'" ~by:"''"

  class print =
    object
      inherit [string] Mql_parser.CST.reduce
      method zero = ""

      method cat s1 s2 =
        (* Printf.printf "cat %S %S\n%!" s1 s2; *)
        match (s1, s2) with
        | "*", ")" -> "*)"
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
             | "all" ) as s1),
            s2 ) -> s1 ^ " " ^ s2
        | s1, s2 when starts_with [ "::"; "("; "->"; "->>"; ")"; "["; "]"; ","; "." ] s2 -> s1 ^ s2
        | s1, s2 -> s1 ^ " " ^ s2

      method text s = s
      method visit_AND = "and"
      method visit_AS = "as"
      method visit_ASC = "asc"
      method visit_BY = "by"
      method visit_COMMA = ","
      method visit_COUNT = "count"
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
      method visit_FLOAT fl = Printf.sprintf "%f" fl
      method visit_FROM = "from"
      method visit_GROUP = "group"
      method visit_GT = ">"
      method visit_GTE = ">="
      method visit_HAVING = "having"
      method visit_IDENTIFIER s = s
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
      method visit_STAR = "*"
      method visit_STRING s = Printf.sprintf "'%s'" (escape_str s)
      method visit_TRUE = "true"
      method visit_WHERE = "where"
      method visit_UNNEST = "unnest"
      method visit_UNION = "union"
      method visit_ALL = "all"
      method visit_WITH = "with"
    end

  module AST2DCST = struct
    module A = Mql_ast
    module D = Mql_parser.DCST

    let maybe_paren e = D.expr_choice e (D.paren e)

    let rec mk_expr = function
      | A.Add (e1, e2) -> maybe_paren @@ D.add (mk_expr e1) (mk_expr e2)
      | A.And (e1, e2) -> maybe_paren @@ D.and_ (mk_expr e1) (mk_expr e2)
      | A.Cast (e1, type_) -> maybe_paren @@ D.cast (mk_expr e1) type_
      | A.Concat (e1, e2) -> maybe_paren @@ D.concat (mk_expr e1) (mk_expr e2)
      | A.Count A.Star -> maybe_paren @@ D.count_star ()
      | A.Count _ -> raise (Failure "nyi")
      | A.Div (e1, e2) -> maybe_paren @@ D.div (mk_expr e1) (mk_expr e2)
      | A.Eq (e1, e2) -> maybe_paren @@ D.equal (mk_expr e1) (mk_expr e2)
      | A.Exists q -> maybe_paren @@ D.exists (query_dcst q)
      | A.False -> D.false_ ()
      | A.Field_select (e1, field) -> maybe_paren @@ D.field_select (mk_expr e1) field
      | A.Float fl -> D.float fl
      | A.Func { M.name; args = [] } -> maybe_paren @@ D.fun_no_args name
      | A.Func { M.name; args } -> maybe_paren @@ D.fun_call name @@ mk_fun_args args
      | A.Gt (e1, e2) -> maybe_paren @@ D.gt (mk_expr e1) (mk_expr e2)
      | A.Gte (e1, e2) -> maybe_paren @@ D.gte (mk_expr e1) (mk_expr e2)
      | A.Identifier s -> maybe_paren @@ D.identifier s
      | A.Ilike (e1, e2) -> maybe_paren @@ D.ilike (mk_expr e1) (mk_expr e2)
      | A.Index (e1, e2) -> maybe_paren @@ D.index (mk_expr e1) (mk_expr e2)
      | A.In (e1, tuple) -> maybe_paren @@ D.in_ (mk_expr e1) (mk_in_list tuple)
      | A.In_query (e1, q) -> maybe_paren @@ D.in_query (mk_expr e1) (query_dcst q)
      | A.Int i -> D.integer i
      | A.Is (e1, e2) -> maybe_paren @@ D.is_ (mk_expr e1) (mk_expr e2)
      | A.Is_distinct_from (e1, e2) -> maybe_paren @@ D.is_distinct_from (mk_expr e1) (mk_expr e2)
      | A.Is_not (e1, e2) -> maybe_paren @@ D.is_not (mk_expr e1) (mk_expr e2)
      | A.Is_not_distinct_from (e1, e2) ->
          maybe_paren @@ D.is_not_distinct_from (mk_expr e1) (mk_expr e2)
      | A.Json_obj_query (e1, s) -> maybe_paren @@ D.json_obj_query (mk_expr e1) s
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

    and mk_fun_args = function
      | [] -> assert false
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.fun_arg @@ mk_expr x)
            ~f:(fun acc x -> D.fun_args acc @@ mk_expr x)
            xs

    and mk_in_list = function
      | [] -> assert false
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.in_list_one @@ mk_expr x)
            ~f:(fun acc x -> D.in_list_more acc @@ mk_expr x)
            xs

    and mk_tuple = function
      | [] -> assert false
      | [ _ ] -> assert false
      | x1 :: x2 :: xs ->
          CCListLabels.fold_right
            ~init:(D.t_tuple (mk_expr x1) (mk_expr x2))
            ~f:(fun x acc -> D.tt_tuple acc (mk_expr x))
            xs

    and mk_table = function
      | { A.name; alias = None } -> D.table_no_alias name
      | { A.name; alias = Some alias } -> D.table_with_alias name alias

    and mk_table_ref = function
      | A.Table_ref t -> D.from_table @@ mk_table t
      | A.Unnest { expr; alias } -> D.from_unnest (mk_expr expr) alias

    and mk_tables = function
      | [] -> assert false
      | x :: xs ->
          CCListLabels.fold_right
            ~init:(D.table @@ mk_table_ref x)
            ~f:(fun x acc -> D.tables acc @@ mk_table_ref x)
            xs

    and column = function
      | { A.expr = e; alias = None } -> D.column_no_alias (mk_expr e)
      | { A.expr = e; alias = Some alias } -> D.column_with_alias (mk_expr e) alias

    and columns acc = function
      | [] -> acc
      | c :: cs -> columns (D.select_list_columns acc (column c)) cs

    and select_list_columns = function
      | M.Star -> D.select_list_star ()
      | M.Columns cs -> (
          match cs with
          | [] -> assert false
          | c :: cs -> D.select_list @@ columns (D.select_list_column (column c)) cs)

    and mk_join = function
      | { M.join_type = M.Inner; table; on_ } -> D.inner_join (mk_table table) (mk_expr on_)
      | { M.join_type = M.Left; table; on_ } -> D.left_join (mk_table table) (mk_expr on_)
      | { M.join_type = M.Right; table; on_ } -> D.right_join (mk_table table) (mk_expr on_)

    and mk_joins = function
      | [] -> assert false
      | x :: xs ->
          CCListLabels.fold_left
            ~init:(D.join @@ mk_join x)
            ~f:(fun acc x -> D.joins acc @@ mk_join x)
            xs

    and mk_order_by_expr = function
      | expr, Some M.Asc -> D.order_by_asc @@ mk_expr expr
      | expr, Some M.Desc -> D.order_by_desc @@ mk_expr expr
      | expr, None -> D.order_by_bare @@ mk_expr expr

    and mk_order_by = function
      | [] -> assert false
      | x :: xs ->
          CCListLabels.fold_right
            ~init:(D.order_by_expr @@ mk_order_by_expr x)
            ~f:(fun x acc -> D.order_by_exprs acc @@ mk_order_by_expr x)
            xs

    and mk_group_by_exprs = function
      | [] -> assert false
      | x :: xs ->
          CCListLabels.fold_right
            ~init:(D.group_by_expr @@ mk_expr x)
            ~f:(fun x acc -> D.group_by_exprs acc @@ mk_expr x)
            xs

    and standalone_expr expr = D.standalone_expr @@ mk_expr expr

    (* [dcst] is short for "deconstruct": the [*_dcst] functions deconstruct an
       MQL AST node ([M.*]) and reconstruct it as the SQL DSL ([D.*]). *)
    and query_dcst t =
      let rec collect acc = function
        | M.With { materialized; name; query = q; body } ->
            collect ((materialized, name, q) :: acc) body
        | M.Query _ as body -> (List.rev acc, body)
      in
      match collect [] t with
      | [], body -> query_no_with_dcst body
      | c :: cs, body ->
          let mk_def (materialized, name, q) =
            if materialized then D.cte_definition_materialized name (query_dcst q)
            else D.cte_definition name (query_dcst q)
          in
          let ctes =
            CCListLabels.fold_left
              ~init:(D.cte (mk_def c))
              ~f:(fun acc d -> D.ctes acc (mk_def d))
              cs
          in
          D.with_query ctes (query_no_with_dcst body)

    and query_no_with_dcst = function
      | M.With _ -> raise (Failure "query_with_no_dcst:nyi")
      | M.Query { body; order_by; limit } ->
          D.query (query_body_dcst body) (order_by_opt_dcst order_by limit)

    and order_by_opt_dcst order_by limit =
      let limit_opt =
        match limit with
        | Some limit -> D.limit limit
        | None -> D.eof ()
      in
      match order_by with
      | Some order_by -> D.order_by (mk_order_by order_by) limit_opt
      | None -> D.no_order_by limit_opt

    and query_body_dcst = function
      | M.Select sc -> D.qb_term (D.ut_select (select_core_dcst sc))
      | M.Paren q -> D.qb_term (D.ut_paren (query_dcst q))
      | M.Union { all; left; right } ->
          if all then D.qb_union_all (query_body_dcst left) (union_term_dcst right)
          else D.qb_union (query_body_dcst left) (union_term_dcst right)

    and union_term_dcst = function
      | M.Select sc -> D.ut_select (select_core_dcst sc)
      | M.Paren q -> D.ut_paren (query_dcst q)
      | M.Union _ -> raise (Failure "union_term_dcst:nyi")

    and select_core_dcst { M.select_list; from; joins; where; group_by; having } =
      let group_by_opt =
        match (group_by, having) with
        | Some exprs, None -> D.group_by_no_having (mk_group_by_exprs exprs)
        | Some exprs, Some expr -> D.group_by_having (mk_group_by_exprs exprs) (mk_expr expr)
        | None, None -> D.no_group_by ()
        | None, Some _ -> assert false
      in
      let where_opt =
        match where with
        | Some expr -> D.where (mk_expr expr) group_by_opt
        | None -> D.no_where group_by_opt
      in
      let select_opt =
        match joins with
        | [] -> D.no_joins where_opt
        | joins -> D.with_joins (mk_joins joins) where_opt
      in
      D.select_core (select_list_columns select_list) (mk_tables from) select_opt

    let start t = D.start (query_dcst t)
  end

  let to_string t =
    match Mql_parser.Settle.start @@ AST2DCST.start t with
    | None -> raise (Failure "nyi")
    | Some m -> (new print)#visit_start m

  let expr_to_string expr =
    match Mql_parser.Settle.standalone_expr @@ AST2DCST.standalone_expr expr with
    | None -> raise (Failure "nyi")
    | Some m -> (new print)#visit_standalone_expr m
end

module Build = struct
  module M = Mql_ast

  (* Expression builders *)
  let id s = M.Identifier s
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
  let count_star = M.Count M.Star

  (* Table builders *)
  let table ?alias name = M.Table_ref { M.name; alias }

  (* Column builders *)
  let col ?alias expr = { M.expr; alias }
  let columns cs = M.Columns cs
  let star = M.Star

  (* Query builder *)
  let select ?where ?joins ?group_by ?having ?order_by ?limit ~from ~cols () =
    M.Query
      {
        body =
          M.Select
            {
              M.select_list = cols;
              from;
              joins = CCOption.get_or ~default:[] joins;
              where;
              group_by;
              having;
            };
        order_by;
        limit;
      }

  let query_body = function
    | M.Query { body; _ } -> body
    | M.With _ -> invalid_arg "Mql.Build.query_body: operand cannot be a WITH query"

  let union_all a b =
    M.Query
      {
        body = M.Union { all = true; left = query_body a; right = query_body b };
        order_by = None;
        limit = None;
      }
end

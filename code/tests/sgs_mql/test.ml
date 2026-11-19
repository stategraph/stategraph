(* Cross-tenant data leak via coupling between the two MQL allow-lists.

   The MQL core enforces table access against [Sgs_mql_paged.schema], while
   tenant scoping is enforced by the per-table CTEs in
   [src/sgs_mql/sql/select_mql_page.sql]. These are two hand-maintained lists. If a
   table is added to the schema without a matching scoped CTE, that table name
   resolves -- inside the user-query CTE [q] -- to the REAL, unscoped table,
   leaking data across tenants.

   This test fails closed: every table in the schema must have a top-level CTE
   in [select_mql_page.sql]. (The reverse is allowed: helper CTEs such as
   [tenant_users] and [q] need not appear in the schema.) *)

let terrateam_ctes_sql = [%blob "select_mql_page_terrateam_ctes.sql"]

let is_ident c =
  Char.equal c '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')

(* Top-level CTE names: lines of the form "<name> as (" or, when the planner
   hint is present, "<name> as not materialized (". *)
let cte_names sql =
  sql
  |> CCString.split_on_char '\n'
  |> CCList.filter_map (fun line ->
      let line = CCString.trim line in
      CCOption.flat_map
        (fun name ->
          (* A real CTE name is a bare identifier (no embedded whitespace). *)
          if CCString.exists Sln_string.is_whitespace name then None else Some name)
        (CCOption.or_lazy
           ~else_:(fun () -> CCString.chop_suffix ~suf:" as (" line)
           (CCString.chop_suffix ~suf:" as not materialized (" line)))

(* (name, body) pairs for the top-level CTEs of the terrateam fragment: a CTE
   header sits at column 0 ("<name> as (" or "<name> as not materialized (");
   its body is everything until the next header. *)
let cte_bodies sql =
  let header line =
    if CCString.prefix ~pre:" " line || CCString.prefix ~pre:"--" line then None
    else
      CCOption.or_lazy
        ~else_:(fun () -> CCString.chop_suffix ~suf:" as (" line)
        (CCString.chop_suffix ~suf:" as not materialized (" line)
  in
  let flush name buf acc =
    CCOption.map_or ~default:acc (fun n -> (n, CCString.concat "\n" (CCList.rev buf)) :: acc) name
  in
  let name, buf, acc =
    CCList.fold_left
      (fun (name, buf, acc) line ->
        match header line with
        | Some n -> (Some n, [], flush name buf acc)
        | None -> (name, line :: buf, acc))
      (None, [], [])
      (CCString.split_on_char '\n' sql)
  in
  CCList.rev (flush name buf acc)

(* Column names of one table in an MQL schema, via its JSON projection. *)
let columns_of_schema_table schema table =
  match Mql_to_pgsql.Schema.to_yojson schema with
  | `Assoc fields -> (
      match List.assoc_opt "tables" fields with
      | Some (`Assoc tables) -> (
          match List.assoc_opt table tables with
          | Some (`Assoc t) -> (
              match List.assoc_opt "columns" t with
              | Some (`Assoc columns) -> CCList.map fst columns
              | _ -> Oth.Assert.false_ ("no columns for table " ^ table))
          | _ -> Oth.Assert.false_ ("table missing from schema: " ^ table))
      | _ -> Oth.Assert.false_ "unexpected MQL schema json shape")
  | _ -> Oth.Assert.false_ "unexpected MQL schema json shape"

(* Table names from an MQL schema, read via its JSON projection. *)
let schema_tables schema =
  match Mql_to_pgsql.Schema.to_yojson schema with
  | `Assoc fields -> (
      match List.assoc_opt "tables" fields with
      | Some (`Assoc tables) -> CCList.map fst tables
      | _ -> Oth.Assert.false_ "unexpected MQL schema json shape")
  | _ -> Oth.Assert.false_ "unexpected MQL schema json shape"

(* The catalog-generated tables: what the orchestration variant adds. *)
let terrateam_tables =
  let base = schema_tables Sgs_mql_paged.schema in
  CCList.filter
    (fun t -> not (CCList.mem ~eq:CCString.equal t base))
    (schema_tables Sgs_mql_paged.schema_orchestration)

(* Table names of the [tables] object of a schema-endpoint body. *)
let advertised_tables body =
  let { Sgs_api_components.Mql_schema_response.tables; default_limit = _; max_limit = _ } =
    Sgs_api_components.Mql_schema_response.of_yojson body |> Oth.Assert.ok
  in
  Sgs_api_components.Mql_schema_response.Tables.additional tables

(* RFD 1724, CTE and schema parity.  The helpers below read the page SQL with
   MQL, thus the tests see the CTEs as PostgreSQL does and not as lines of
   text. *)

(* [Mql_ast] is opened only for the AST walks below. *)
include struct
  open Mql_ast

  let ident_name { Mql_ast.name; quoted = _ } = name

  let page_ast ~orchestration =
    Mql_sql.read_ast (Sgs_mql_paged.Tests.select_page_sql ~orchestration)

  (* The top-level CTEs in order, as (name, CTE node).  The parser folds
     [WITH a, b, c body] into [With a (With b (With c body))]. *)
  let rec top_level_ctes = function
    | With { name; body; _ } as cte -> (ident_name name, cte) :: top_level_ctes body
    | _ -> []

  (* The first [Select] of a query body.  PostgreSQL takes the names of the
     columns of a set operation from its left branch. *)
  let rec first_select = function
    | Query { body; _ } -> first_select_of_body body
    | With { body; _ } -> first_select body
    | _ -> None

  and first_select_of_body = function
    | Select select -> Some select
    | Set_op { left; _ } -> first_select_of_body left
    | Paren t -> first_select t

  (* The name that PostgreSQL gives to a column of a select list. *)
  let column_name { expr; alias } =
    match (alias, expr) with
    | Some alias, _ -> ident_name alias
    | None, (Identifier name | Field_select (_, name)) -> ident_name name
    | None, Func { name; _ } -> ident_name name
    | None, _ -> "?column?"

  (* The output columns of a CTE: its column list, or the names of the select
     list of its body.  A select list of [*] gives ["*"], so that the parity test
     reports it. *)
  let cte_columns = function
    | With { columns = _ :: _ as columns; _ } -> CCList.map ident_name columns
    | With { query; _ } -> (
        match first_select query with
        | Some { select_list = Star; _ } -> [ "*" ]
        | Some { select_list = Columns cols; _ } -> CCList.map column_name cols
        | None -> Oth.Assert.false_ "a CTE body with no select")
    | _ -> Oth.Assert.false_ "not a CTE"

  (* The names that a FROM clause binds: the alias of each item, or the name of
     the table when it has no alias. *)
  let from_names from =
    let of_ref = function
      | Table_ref { alias = Some alias; _ } -> [ ident_name alias ]
      | Table_ref { name; _ } -> [ ident_name name ]
      | Unnest { alias; _ } | Derived_table { alias; _ } -> [ ident_name alias ]
      | Func_table { alias; _ } -> CCList.map ident_name (CCOption.to_list alias)
    in
    CCList.flat_map
      (fun { fe_table; fe_joins } ->
        of_ref fe_table @ CCList.flat_map (fun { table; _ } -> of_ref table) fe_joins)
      from

  (* The whole-row references of an expression: a star on a name, or a bare
     name of a FROM item, also as an argument of a call.  A bare name before a
     field ([t.col]) is a qualifier, thus [Field_select] stops the walk.  The
     walk reads the expressions that can hold a row value in a select list of
     this repository; it is not a full walk of each constructor. *)
  let rec whole_row_refs names = function
    | Qualified_star _ -> [ "*" ]
    | Identifier ident when CCList.mem ~eq:CCString.equal (ident_name ident) names ->
        [ ident_name ident ]
    | Func { args = Func_exprs args; _ } ->
        CCList.flat_map
          (function
            | Arg e | Arg_named (_, e) -> whole_row_refs names e)
          args
    | Cast (e, _) -> whole_row_refs names e
    | Case { operand; branches; else_ } ->
        CCList.flat_map
          (whole_row_refs names)
          (CCOption.to_list operand
          @ CCList.flat_map (fun (c, v) -> [ c; v ]) branches
          @ CCOption.to_list else_)
    | Tuple es | Array_lit es -> CCList.flat_map (whole_row_refs names) es
    | _ -> []

  (* Each [*] and each whole-row reference in the select lists of the body of
     a CTE, in each branch of a set operation. *)
  let cte_star_and_whole_rows = function
    | With { query; _ } ->
        let rec of_body = function
          | Select { select_list = Star; _ } -> [ "*" ]
          | Select { select_list = Columns cols; from; _ } ->
              let names = from_names from in
              CCList.flat_map (fun { expr; _ } -> whole_row_refs names expr) cols
          | Set_op { left; right; _ } -> of_body left @ of_body right
          | Paren t -> of_query t
        and of_query = function
          | Query { body; _ } -> of_body body
          | With { body; _ } -> of_query body
          | _ -> []
        in
        of_query query
    | _ -> []
end

let sorted = CCList.sort_uniq ~cmp:CCString.compare

let variants =
  [
    ("base", false, Sgs_mql_paged.schema);
    ("orchestration", true, Sgs_mql_paged.schema_orchestration);
  ]

(* The schema columns that the CTE of a table does not make, and the CTE
   columns that the schema does not have, as [table.column]. *)
let parity_diff ~orchestration schema =
  let ctes = top_level_ctes (page_ast ~orchestration) in
  CCList.flat_map
    (fun table ->
      match Sln_list.String.assoc_opt table ctes with
      | None -> [ "no CTE for " ^ table ]
      | Some cte ->
          let cte_cols = sorted (cte_columns cte) in
          let schema_cols = sorted (columns_of_schema_table schema table) in
          let not_in l c = not (CCList.mem ~eq:CCString.equal c l) in
          CCList.map
            (fun c -> "CTE column outside the schema: " ^ table ^ "." ^ c)
            (CCList.filter (not_in schema_cols) cte_cols)
          @ CCList.map
              (fun c -> "schema column outside the CTE: " ^ table ^ "." ^ c)
              (CCList.filter (not_in cte_cols) schema_cols))
    (schema_tables schema)

let parity_tests =
  Oth.parallel
    (CCList.flat_map
       (fun (variant, orchestration, schema) ->
         [
           Oth.test
             ~name:("Parity: each schema table has a top-level CTE (" ^ variant ^ ")")
             (fun _ ->
               let ctes = CCList.map fst (top_level_ctes (page_ast ~orchestration)) in
               Oth.Assert.List.empty
                 (CCList.filter
                    (fun t -> not (CCList.mem ~eq:CCString.equal t ctes))
                    (schema_tables schema));
               ());
           Oth.test
             ~name:("Parity: CTE columns equal schema columns (" ^ variant ^ ")")
             (fun _ ->
               Oth.Assert.Eq.string_list ~expected:[] ~actual:(parity_diff ~orchestration schema);
               ());
           Oth.test
             ~name:("Parity: no star or whole-row in a CTE select list (" ^ variant ^ ")")
             (fun _ ->
               Oth.Assert.Eq.string_list
                 ~expected:[]
                 ~actual:
                   (CCList.flat_map
                      (fun (name, cte) ->
                        CCList.map (fun r -> name ^ ": " ^ r) (cte_star_and_whole_rows cte))
                      (top_level_ctes (page_ast ~orchestration)));
               ());
           Oth.test
             ~name:("Parity: a CTE outside the schema gives Table_access_err (" ^ variant ^ ")")
             (fun _ ->
               let tables = schema_tables schema in
               let outside =
                 CCList.filter
                   (fun name -> not (CCList.mem ~eq:CCString.equal name tables))
                   (CCList.map fst (top_level_ctes (page_ast ~orchestration)))
               in
               Oth.Assert.List.str_mem
                 ~fail_msg:"no top-level CTE outside the schema"
                 ~searched:"tenant_users"
                 outside;
               CCList.iter
                 (fun name ->
                   let ast =
                     Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                     @@ Mql.Ast.of_string ("select * from " ^ name)
                   in
                   match
                     Mql_to_pgsql.of_mql
                       ~func_allow_list:Mql_to_pgsql.default_func_allow_list
                       ~cast_allow_list:Mql_to_pgsql.default_cast_allow_list
                       ~schema
                       ast
                   with
                   | Error (`Table_access_err t) when CCString.equal t name -> ()
                   | Error err ->
                       Oth.Assert.false_
                         (Format.asprintf "%s: unexpected error %a" name Mql_to_pgsql.pp_err err)
                   | Ok _ -> Oth.Assert.false_ (name ^ ": accepted"))
                 outside;
               ());
           Oth.test
             ~name:("Parity: q is the last CTE (" ^ variant ^ ")")
             (fun _ ->
               let names = CCList.map fst (top_level_ctes (page_ast ~orchestration)) in
               Oth.Assert.Eq.string
                 ~expected:"q"
                 ~actual:(CCList.last_opt names |> CCOption.get_or ~default:"");
               Oth.Assert.Eq.int ~expected:1 ~actual:(CCList.count (CCString.equal "q") names);
               ());
           Oth.test
             ~name:("Parity: the rendered page query holds the user query in q (" ^ variant ^ ")")
             (fun _ ->
               let compiled =
                 Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
                 @@ Mql_to_pgsql.of_mql
                      ~func_allow_list:Mql_to_pgsql.default_func_allow_list
                      ~cast_allow_list:Mql_to_pgsql.default_cast_allow_list
                      ~schema
                 @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                 @@ Mql.Ast.of_string "select id, name from states where name = 'x'"
               in
               let user_query = Mql_to_pgsql.query compiled in
               let rendered =
                 Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                 @@ Sgs_mql_paged.Tests.select_page_query ~orchestration user_query
               in
               let ctes = top_level_ctes (Mql_sql.read_ast rendered) in
               let names = CCList.map fst ctes in
               Oth.Assert.Eq.string
                 ~expected:"q"
                 ~actual:(CCList.last_opt names |> CCOption.get_or ~default:"");
               Oth.Assert.Eq.int ~expected:1 ~actual:(CCList.count (CCString.equal "q") names);
               (* The other CTEs are the tenant-scoped CTEs of the template. *)
               Oth.Assert.Eq.string_list
                 ~expected:
                   (CCList.map fst (top_level_ctes (page_ast ~orchestration))
                   |> CCList.filter (fun n -> not (CCString.equal n "q")))
                 ~actual:(CCList.filter (fun n -> not (CCString.equal n "q")) names);
               match CCList.assoc_opt ~eq:CCString.equal "q" ctes with
               | Some (Mql_ast.With { query; _ }) ->
                   Oth.Assert.eq
                     ~eq:CCString.equal
                     ~pp:CCString.pp
                     (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string user_query)
                     (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string query)
               | Some _ | None -> Oth.Assert.false_ "no q CTE");
           Oth.test
             ~name:("Parity: the schema endpoint returns the schema (" ^ variant ^ ")")
             (fun _ ->
               let body =
                 if orchestration then Sgs_mql_ep.Tests.response_json_orchestration
                 else Sgs_mql_ep.Tests.response_json
               in
               let advertised =
                 Sln_map.String.fold
                   (fun table { Sgs_api_components.Mql_schema_table.columns } acc ->
                     Sln_map.String.fold
                       (fun column _ acc -> (table ^ "." ^ column) :: acc)
                       (Sgs_api_components.Mql_schema_table.Columns.additional columns)
                       acc)
                   (advertised_tables body)
                   []
               in
               let expected =
                 CCList.flat_map
                   (fun table ->
                     CCList.map (fun c -> table ^ "." ^ c) (columns_of_schema_table schema table))
                   (schema_tables schema)
               in
               Oth.Assert.Eq.string_list ~expected:(sorted expected) ~actual:(sorted advertised);
               ());
         ])
       variants
    @ [
        (* The detector of the test above must see a whole-row reference, or a
           green run says nothing. *)
        Oth.test ~name:"Parity: the whole-row detector sees a whole-row reference" (fun _ ->
            let cte =
              Mql_sql.read_ast
                "with c as (select t.id, to_jsonb(t) as j, t.* from states as t) select 1 as x"
            in
            Oth.Assert.Eq.string_list
              ~expected:[ "t"; "*" ]
              ~actual:
                (CCList.flat_map (fun (_, c) -> cte_star_and_whole_rows c) (top_level_ctes cte));
            ());
      ])

let test =
  Oth.parallel
    [
      Oth.test ~name:"MQL schema tables all have a tenant-scoped CTE (base variant)" (fun _ ->
          let ctes = cte_names (Sgs_mql_paged.Tests.select_page_sql ~orchestration:false) in
          let missing =
            CCList.filter
              (fun t -> not (CCList.mem ~eq:CCString.equal t ctes))
              (schema_tables Sgs_mql_paged.schema)
          in
          Oth.Assert.List.empty missing);
      Oth.test
        ~name:"MQL schema tables all have a tenant-scoped CTE (orchestration variant)"
        (fun _ ->
          let ctes = cte_names (Sgs_mql_paged.Tests.select_page_sql ~orchestration:true) in
          let missing =
            CCList.filter
              (fun t -> not (CCList.mem ~eq:CCString.equal t ctes))
              (schema_tables Sgs_mql_paged.schema_orchestration)
          in
          Oth.Assert.List.empty missing);
      (* Every terrateam (table, column) the orchestration schema advertises
         must be projected by its CTE: the foreign tables carry exactly the
         catalog columns, but a fragment that fell behind the catalog would
         500 at query time with no earlier signal. *)
      Oth.test ~name:"terrateam CTE projections cover the orchestration schema" (fun _ ->
          let bodies = cte_bodies terrateam_ctes_sql in
          let missing =
            CCList.flat_map
              (fun table ->
                match Sln_list.String.assoc_opt table bodies with
                | None -> [ table ^ ".<no CTE>" ]
                | Some body ->
                    columns_of_schema_table Sgs_mql_paged.schema_orchestration table
                    |> CCList.filter_map (fun col ->
                        let projected = " as " ^ col in
                        if CCString.mem ~sub:projected body then None else Some (table ^ "." ^ col)))
              terrateam_tables
          in
          Oth.Assert.List.empty missing);
      (* The reverse direction. The fragment is spliced into EVERY
         orchestration query and Postgres resolves each CTE's relations at
         parse time whether or not the user query touches them, so a single
         [terrateam.<x>] reference to a table the catalog no longer carries
         (its foreign table is dropped by the boot reconcile) fails all MQL at
         once. Pin the foreign-table references to exactly the catalog: one CTE
         per table, reading its own foreign table. The only other reference is
         work_manifests, the tenant scope of the work-manifest tables, from
         fdw_scope_tables.sql. #2469: This reference is necessary only
         because the foreign data wrapper abstraction is leaky. *)
      Oth.test ~name:"terrateam fragment reads exactly the catalog's foreign tables" (fun _ ->
          let referenced =
            CCString.split ~by:"terrateam." terrateam_ctes_sql
            |> CCList.drop 1
            |> CCList.map (CCString.take_while is_ident)
            |> Sln_list.String.sort_uniq
          in
          Oth.Assert.Eq.string_list
            ~expected:(CCList.sort CCString.compare ("work_manifests" :: terrateam_tables))
            ~actual:referenced);
      (* #1061: the schema endpoint body must conform to [mql-schema-response] and
         publish the endpoint's row-limit policy, so clients can discover the
         defaulting behaviour (and the [mql-default-limit-applied] header) rather
         than hard-coding the magic 20/1000. A successful [of_yojson] also proves
         the endpoint's [Tables.of_yojson] round-trip took the Ok path, not the
         legacy tables-only fallback that would silently drop the limits. *)
      Oth.test ~name:"MQL schema endpoint body advertises default_limit and max_limit" (fun _ ->
          let { Sgs_api_components.Mql_schema_response.default_limit; max_limit; tables } =
            Sgs_api_components.Mql_schema_response.of_yojson Sgs_mql_ep.Tests.response_json
            |> Oth.Assert.ok
          in
          Oth.Assert.Eq.int ~expected:20 ~actual:default_limit;
          Oth.Assert.Eq.int ~expected:1000 ~actual:max_limit;
          (* the table set survived the round-trip intact *)
          Oth.Assert.Eq.bool
            ~expected:true
            ~actual:
              (Sln_map.String.mem
                 "instances"
                 (Sgs_api_components.Mql_schema_response.Tables.additional tables)));
      (* [mql-schema-response] is additionalProperties:false, so pin the exact top
         level keys -- an accidental extra field would put the wire body out of
         contract with its own schema. *)
      Oth.test ~name:"MQL schema endpoint body has exactly the contract keys" (fun _ ->
          let keys =
            match Sgs_mql_ep.Tests.response_json with
            | `Assoc fields -> CCList.sort CCString.compare (CCList.map fst fields)
            | _ -> Oth.Assert.false_ "schema body is not a JSON object"
          in
          Oth.Assert.Eq.string_list
            ~expected:[ "default_limit"; "max_limit"; "tables" ]
            ~actual:keys);
      (* [Schema.run] picks the body per config flag: the orchestration body
         must advertise every terrateam table (the ON contract, so clients can
         discover them), the base body none of them (the OFF contract, since a
         query naming one is refused there). *)
      Oth.test
        ~name:"MQL schema endpoint bodies advertise terrateam tables iff orchestration"
        (fun _ ->
          let on = advertised_tables Sgs_mql_ep.Tests.response_json_orchestration in
          let off = advertised_tables Sgs_mql_ep.Tests.response_json in
          Oth.Assert.List.empty
            (CCList.filter (fun t -> not (Sln_map.String.mem t on)) terrateam_tables);
          Oth.Assert.List.empty (CCList.filter (fun t -> Sln_map.String.mem t off) terrateam_tables));
      (* #1442 PR 21: the narrow provisioning write channel lives in a separate
         FDW schema, [terrateam_admin], holding the full gitlab_installations
         (webhook_secret, access_token). That schema must NEVER be reachable
         through MQL. The read surface is schema-qualified to [terrateam.*], so
         [terrateam_admin] can only leak if a CTE or the assembled query names
         it -- assert it appears nowhere in either. *)
      Oth.test ~name:"MQL surface never references the terrateam_admin schema" (fun _ ->
          Oth.Assert.String.doesnt_contain ~haystack:terrateam_ctes_sql ~needle:"terrateam_admin";
          Oth.Assert.String.doesnt_contain
            ~haystack:(Sgs_mql_paged.Tests.select_page_sql ~orchestration:true)
            ~needle:"terrateam_admin";
          Oth.Assert.String.doesnt_contain
            ~haystack:(Sgs_mql_paged.Tests.select_page_sql ~orchestration:false)
            ~needle:"terrateam_admin");
    ]

(* RFD 1724, adversarial tests.  The queries come from [Mql_adversarial_corpus],
   because the integration tests of the endpoint run the same queries.  Each
   query runs on each schema of the endpoint with the default allow lists.  The
   outcome and the refusal rules are the corpus's own, so this suite and the
   unit suite of [mql_to_pgsql] cannot drift apart. *)
module Adversarial = struct
  let show_outcome = Mql_adversarial_corpus.show_outcome
  let outcome ~schema query = Mql_adversarial_corpus.outcome ~schema query
  let refused = Mql_adversarial_corpus.refused
  let func_access_err = Mql_adversarial_corpus.func_access_err
  let cast_err = Mql_adversarial_corpus.cast_err

  (* In [LIMIT], MQL reads only an integer, and it refuses an array constructor
     as a construct before it reads the elements.  RFD 1724 accepts these
     refusals in these two positions. *)
  let expected_in_position ~default = function
    | "limit" -> (
        function
        | Mql_adversarial_corpus.Parse_err _ | Mql_adversarial_corpus.Of_mql_err (`Variable_err _)
          -> true
        | _ -> false)
    | "array constructor" -> (
        function
        | Mql_adversarial_corpus.Of_mql_err (`Construct_not_allowed_err _) -> true
        | _ -> false)
    | _ -> default

  (* Each query in each position, with the result that the position expects. *)
  let in_positions ~default exprs =
    CCList.flat_map
      (fun (name, expr) ->
        CCList.map
          (fun (position, template) ->
            (name ^ " in " ^ position, expected_in_position ~default position, template expr))
          Mql_adversarial_corpus.positions)
      exprs

  (* Fails the test with each case whose outcome [expected] refuses, thus one
     run shows each bad case. *)
  let assert_cases ~schema cases =
    Oth.Assert.Eq.string_list
      ~expected:[]
      ~actual:
        (CCList.filter_map
           (fun (desc, expected, query) ->
             let outcome = outcome ~schema query in
             if expected outcome then None
             else Some (Printf.sprintf "[%s] %s -> %s" desc query (show_outcome outcome)))
           cases)

  let test =
    Oth.parallel
    @@ CCList.flat_map
         (fun (variant, _, schema) ->
           [
             Oth.test
               ~name:
                 ("Adversarial: a function that reads by name, in each position (" ^ variant ^ ")")
               (fun _ ->
                 assert_cases
                   ~schema
                   (in_positions
                      ~default:func_access_err
                      Mql_adversarial_corpus.forbidden_functions));
             Oth.test
               ~name:
                 ("Adversarial: a cast to a type that names an object, in each position ("
                 ^ variant
                 ^ ")")
               (fun _ ->
                 assert_cases
                   ~schema
                   (in_positions ~default:cast_err Mql_adversarial_corpus.forbidden_casts));
             Oth.test
               ~name:("Adversarial: names that try to get around the checks (" ^ variant ^ ")")
               (fun _ ->
                 assert_cases
                   ~schema
                   (CCList.map
                      (fun (desc, query) -> (desc, refused, query))
                      Mql_adversarial_corpus.name_tricks));
           ])
         variants
end

let () =
  Random.self_init ();
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ -> Oth.parallel [ test; parity_tests; Adversarial.test ])

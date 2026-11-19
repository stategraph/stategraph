module Of_mql_result = struct
  type t = (Mql_to_pgsql.t, Mql_to_pgsql.err) result [@@deriving show, eq]
end

module Audit_result = struct
  type t = (unit, Mql_to_pgsql.audit_err) result [@@deriving show, eq]
end

let schema =
  Mql_to_pgsql.Schema.(
    make
      [
        Table.make
          ~name:"test"
          Column.
            [
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
            ];
        Table.make
          ~name:"test2"
          Column.
            [
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
            ];
        Table.make
          ~name:"test3"
          Column.[ make ~name:"a" ~type_:Type_.Integer (); make ~name:"b" ~type_:Type_.Integer () ];
        (* From the mql endpoint *)
        Table.make
          ~name:"tenants"
          Column.
            [
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
            ];
        Table.make
          ~name:"users"
          Column.
            [
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"type" ~type_:Type_.Text ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
            ];
        Table.make
          ~name:"states"
          Column.
            [
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"group_id" ~type_:Type_.Uuid ();
              make ~name:"workspace" ~type_:Type_.Text ();
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"tenant_id" ~type_:Type_.Uuid ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
              make ~name:"updated_at" ~type_:Type_.Timestamptz ();
              make ~name:"deleted_at" ~type_:Type_.Timestamptz ();
              make ~name:"deleted_by" ~type_:Type_.Uuid ();
            ];
        Table.make
          ~name:"providers"
          Column.
            [ make ~name:"name" ~type_:Type_.Text (); make ~name:"state_id" ~type_:Type_.Uuid () ];
        Table.make
          ~name:"resources"
          Column.
            [
              make ~name:"address" ~type_:Type_.Text ();
              make ~name:"mode" ~type_:Type_.Text ();
              make ~name:"module" ~type_:Type_.Text ();
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"provider" ~type_:Type_.Text ();
              make ~name:"state_id" ~type_:Type_.Uuid ();
              make ~name:"type" ~type_:Type_.Text ();
            ];
        Table.make
          ~name:"instances"
          Column.
            [
              make ~name:"address" ~type_:Type_.Text ();
              make ~name:"attributes" ~type_:Type_.Jsonb ();
              make ~name:"create_before_destroy" ~type_:Type_.Bool ();
              make ~name:"dependencies" ~type_:(Type_.Complex "text[]") ();
              make ~name:"deposed" ~type_:Type_.Text ();
              make ~name:"identity" ~type_:Type_.Jsonb ();
              make ~name:"identity_schema_version" ~type_:Type_.Integer ();
              make ~name:"index_key" ~type_:Type_.Text ();
              make ~name:"private" ~type_:Type_.Text ();
              make ~name:"resource_address" ~type_:Type_.Text ();
              make ~name:"schema_version" ~type_:Type_.Integer ();
              make ~name:"sensitive_attributes" ~type_:Type_.Jsonb ();
              make ~name:"state_id" ~type_:Type_.Uuid ();
              make ~name:"status" ~type_:Type_.Text ();
            ];
        Table.make
          ~name:"outputs"
          Column.
            [
              make ~name:"name" ~type_:Type_.Text ();
              make ~name:"sensitive" ~type_:Type_.Bool ();
              make ~name:"state_id" ~type_:Type_.Uuid ();
              make ~name:"type" ~type_:Type_.Jsonb ();
              make ~name:"value" ~type_:Type_.Jsonb ();
            ];
        Table.make
          ~name:"check_results"
          Column.
            [
              make ~name:"config_addr" ~type_:Type_.Text ();
              make ~name:"object_kind" ~type_:Type_.Text ();
              make ~name:"state_id" ~type_:Type_.Uuid ();
              make ~name:"status" ~type_:Type_.Text ();
            ];
        Table.make
          ~name:"check_entries"
          Column.
            [
              make ~name:"config_addr" ~type_:Type_.Text ();
              make ~name:"failure_messages" ~type_:(Type_.Complex "text[]") ();
              make ~name:"object_addr" ~type_:Type_.Text ();
              make ~name:"state_id" ~type_:Type_.Uuid ();
              make ~name:"status" ~type_:Type_.Text ();
            ];
        Table.make
          ~name:"transactions"
          Column.
            [
              make ~name:"completed_at" ~type_:Type_.Timestamptz ();
              make ~name:"completed_by" ~type_:Type_.Uuid ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
              make ~name:"created_by" ~type_:Type_.Uuid ();
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"state" ~type_:Type_.Text ();
              make ~name:"tags" ~type_:Type_.Jsonb ();
              make ~name:"tenant_id" ~type_:Type_.Uuid ();
            ];
        Table.make
          ~name:"transaction_logs"
          Column.
            [
              make ~name:"action" ~type_:Type_.Text ();
              make ~name:"created_at" ~type_:Type_.Timestamptz ();
              make ~name:"data" ~type_:Type_.Jsonb ();
              make ~name:"id" ~type_:Type_.Uuid ();
              make ~name:"object_type" ~type_:Type_.Text ();
              make ~name:"state_id" ~type_:Type_.Uuid ();
              make ~name:"tx_id" ~type_:Type_.Uuid ();
              make ~name:"user_id" ~type_:Type_.Uuid ();
            ];
      ])

let build_str = CCFun.(CCList.map CCString.trim %> CCString.concat " ")
let func_allow_list = Mql_to_pgsql.default_func_allow_list
let cast_allow_list = Mql_to_pgsql.default_cast_allow_list

(* RFD 1724, audit gate: every query that [of_mql] accepts in this file must
   also pass [audit_query] with the same schema and the default allow lists.
   Each test calls [of_mql] through this function, thus each accepted query
   of the suite is also a test of the audit. *)
let of_mql ?max_limit ~schema ast =
  let res = Mql_to_pgsql.of_mql ?max_limit ~func_allow_list ~cast_allow_list ~schema ast in
  (match res with
  | Ok t ->
      Oth.Assert.eq
        ~pp:Audit_result.pp
        ~eq:Audit_result.equal
        (Ok ())
        (Mql_to_pgsql.Tests.audit_query
           ~func_allow_list
           ~cast_allow_list
           ~schema
           (Mql_to_pgsql.query t))
  | Error _ -> ());
  res

(* A call with no decoration. *)
let func name args =
  Mql_ast.
    {
      qualifier = None;
      name = ident name;
      distinct = false;
      args = Func_exprs (CCList.map (fun a -> Arg a) args);
      agg_order_by = None;
      filter = None;
      over = None;
    }

(* A plain, unqualified cast target. *)
let cast_type name =
  Mql_ast.
    {
      type_ident = { qualifier = None; base = ident name };
      type_extra = No_extra;
      args = [];
      array_dims = 0;
    }

(* [select <expr> from test] as an AST, so the audit can be driven with
   expressions no parser would accept. *)
let select_expr expr =
  Mql_ast.(
    Query
      {
        body =
          Select
            {
              distinct = None;
              select_list = Columns [ { expr; alias = None } ];
              from =
                [
                  {
                    fe_table =
                      Table_ref { table_qualifier = None; name = ident "test"; alias = None };
                    fe_joins = [];
                  };
                ];
              where = None;
              group_by = None;
              having = None;
            };
        order_by = None;
        limit = None;
        offset = None;
        locking = None;
      })

(* [select * from <name>] as an AST, so a table name no lexer would produce can
   still be put in front of the audit. *)
let table_query name =
  Mql_ast.(
    Query
      {
        body =
          Select
            {
              distinct = None;
              select_list = Star;
              from =
                [
                  {
                    fe_table = Table_ref { table_qualifier = None; name = ident name; alias = None };
                    fe_joins = [];
                  };
                ];
              where = None;
              group_by = None;
              having = None;
            };
        order_by = None;
        limit = None;
        offset = None;
        locking = None;
      })

let assert_audit_err expected ast =
  Oth.Assert.eq
    ~pp:Audit_result.pp
    ~eq:Audit_result.equal
    (Error expected)
    (Mql_to_pgsql.Tests.audit_query ~func_allow_list ~cast_allow_list ~schema ast)

let assert_eq sql query =
  let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
  let query = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
  Oth.Assert.eq
    ~eq:CCString.equal
    ~pp:CCString.pp
    sql
    (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string @@ Mql_to_pgsql.query query)

let empty_schema = Mql_to_pgsql.Schema.make []

(* What happens to a query, and which outcomes are refusals: the rules live in
   [Mql_adversarial_corpus], so this suite and the tests of the endpoint cannot
   drift apart.  The queries of this file carry [$name] variables, thus they
   read with [variables:true]. *)
let outcome ?(schema = schema) query = Mql_adversarial_corpus.outcome ~variables:true ~schema query
let accepted = Mql_adversarial_corpus.accepted
let refused = Mql_adversarial_corpus.refused
let of_mql_err = Mql_adversarial_corpus.of_mql_err
let func_access_err = Mql_adversarial_corpus.func_access_err
let unknown_column_err = Mql_adversarial_corpus.unknown_column_err
let construct_not_allowed_err = Mql_adversarial_corpus.construct_not_allowed_err

module Case = struct
  type t = {
    desc : string;
    query : string;
    outcome : Mql_adversarial_corpus.outcome;
  }

  (* One line for each case, because a failure can name many cases. *)
  let pp fmt { desc; query; outcome } =
    Format.fprintf fmt "@\n  [%s] %s -> %s" desc query (Mql_adversarial_corpus.show_outcome outcome)
end

(* Runs each [(desc, query)] and fails the test with the list of each case
   whose outcome [expected] refuses, thus one run shows each bad case. *)
let assert_cases ?schema ~expected cases =
  Oth.Assert.List.all
    ~pp:Case.pp
    (fun { Case.outcome; _ } -> expected outcome)
    (CCList.map (fun (desc, query) -> { Case.desc; query; outcome = outcome ?schema query }) cases)

(* The audit refuses [ast] with an error that [expected] accepts. *)
let assert_audit_refuses ~expected ast =
  match Mql_to_pgsql.Tests.audit_query ~func_allow_list ~cast_allow_list ~schema ast with
  | Error err when expected err -> ()
  | res -> Oth.Assert.false_ (Format.asprintf "unexpected audit result: %a" Audit_result.pp res)

let audit_construct_err = function
  | `Audit_construct_err _ -> true
  | _ -> false

let test =
  Oth.parallel
    [
      Oth.test ~name:"Success 1" (fun _ ->
          let query = build_str [ "select * from test" ] in
          let sql = build_str [ "select * from test limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 2" (fun _ ->
          let query = build_str [ "select * from test where id = 'foobar'" ] in
          let sql = build_str [ "select * from test where id = $texts[1]::uuid limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 3" (fun _ ->
          let query = build_str [ "select 'bar' from test where id = 'foobar'" ] in
          let sql =
            build_str [ "select $texts[2] from test where id = $texts[1]::uuid limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 4" (fun _ ->
          let query = build_str [ "select * from test where id = 'foobar' and name = 'baz'" ] in
          let sql =
            build_str
              [ "select * from test where id = $texts[2]::uuid and name = $texts[1] limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 5" (fun _ ->
          let query =
            build_str
              [
                "select * from test";
                "where (id = 'foobar' or name = 'baz') and created_at < 'foobar'";
              ]
          in
          let sql =
            build_str
              [
                "select * from test";
                "where (id = $texts[2]::uuid or name = $texts[1]) and created_at < \
                 $timestamptzs[1] limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"tables lists the schema tables, not the CTEs" (fun _ ->
          let query =
            build_str
              [
                "with x as (select id from test)";
                "select x.id from x inner join test2 as t2 on t2.id = x.id";
                "where exists (select 1 from test3 as t3 where t3.a = 1)";
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let q = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
          Oth.Assert.Eq.string_list
            ~expected:[ "test"; "test2"; "test3" ]
            ~actual:(Mql_to_pgsql.tables q));
      Oth.test ~name:"Success 6" (fun _ ->
          let query = build_str [ "select * from test where id is not null" ] in
          let sql = build_str [ "select * from test where id is not null limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 7" (fun _ ->
          let query = build_str [ "select * from test where (id + name) = 3" ] in
          let sql = build_str [ "select * from test where id + name = $bigints[1] limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 8" (fun _ ->
          let query = build_str [ "select * from test order by test.id" ] in
          let sql = build_str [ "select * from test order by test.id limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 9" (fun _ ->
          let query = build_str [ "select id as other_id from test order by other_id" ] in
          let sql = build_str [ "select id as other_id from test order by other_id limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 10" (fun _ ->
          let query =
            build_str
              [ "with foo as (select * from test)"; "select * from foo where foo.id is not null" ]
          in
          let sql =
            build_str
              [
                "with foo as (select * from test)";
                "select * from foo where foo.id is not null";
                "limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 11" (fun _ ->
          let query =
            build_str [ "with foo as (select * from test) select * from foo where id is not null" ]
          in
          let sql =
            build_str
              [
                "with foo as (select * from test)";
                "select * from foo where id is not null";
                "limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 12" (fun _ ->
          let query =
            build_str
              [
                "with foo as (select * from test where id = 'foobar')";
                "select * from foo where id is not null";
              ]
          in
          let sql =
            build_str
              [
                "with foo as (select * from test where id = $texts[1]::uuid)";
                "select * from foo where id is not null";
                "limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 13" (fun _ ->
          let query = build_str [ "select 'bar' from test where id::text = 'foobar'::text" ] in
          let sql =
            build_str [ "select $texts[2] from test where id::text = $texts[1]::text limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 14" (fun _ ->
          let query =
            build_str
              [
                {|with
active_tx as (
  select count(*) from transactions where state = 'open'
),
last_tx as (
  select state from transactions
  where completed_at is not null
  order by completed_at desc
  limit 1
),
num_instances as (
  select count(*) from instances
),
ms as (
  select module from resources where module is not null group by module
),
num_modules as (
  select count(*) as num_modules from ms
)
select json_build_object('modules', num_modules.num_modules) from num_modules|};
              ]
          in
          let sql =
            build_str
              [
                "with";
                "active_tx as (select count(*) from transactions where state = $texts[1]),";
                "last_tx as (select state from transactions where completed_at is not null order \
                 by completed_at desc limit 1),";
                "num_instances as (select count(*) from instances),";
                "ms as (select module from resources where module is not null group by module),";
                "num_modules as (select count(*) as num_modules from ms)";
                "select json_build_object($texts[2], num_modules.num_modules) from num_modules \
                 limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 15 (like)" (fun _ ->
          let query = build_str [ "select * from test where name like 'Bob%'" ] in
          let sql = build_str [ "select * from test where name like $texts[1] limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 16 (not like)" (fun _ ->
          let query = build_str [ "select * from test where name not like 'Bob%'" ] in
          let sql = build_str [ "select * from test where name not like $texts[1] limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 17 (ilike)" (fun _ ->
          let query = build_str [ "select * from test where name ilike 'bob%'" ] in
          let sql = build_str [ "select * from test where name ilike $texts[1] limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success 18 (not ilike)" (fun _ ->
          let query = build_str [ "select * from test where name not ilike 'bob%'" ] in
          let sql = build_str [ "select * from test where name not ilike $texts[1] limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Bad table access 1" (fun _ ->
          let query = build_str [ "select * from other_table" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 2" (fun _ ->
          let query = build_str [ "select * from test inner join other_table on foo = bar" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 3" (fun _ ->
          let query = build_str [ "with foo as (select * from other_table) select * from foo" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Unknown column 1" (fun _ ->
          let query = build_str [ "select * from test where foo is not bar" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "foo"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Ambiguous column 1" (fun _ ->
          let query = build_str [ "select * from test, test2 where id = 'bar'" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Ambiguous_column_err "id"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Func access err 1" (fun _ ->
          let query = build_str [ "select * from test, test2 where foobar(test.id)" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Func_access_err "foobar"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Cast err 1" (fun _ ->
          let query = build_str [ "select 'foo'::regclass from test" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Cast_err "regclass"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      (* --- Security regression tests ---------------------------------------
         MQL identifiers (table/column/alias names) are rendered verbatim and
         text-substituted into the generated SQL. Two vulnerabilities followed
         from that; each case below returned [Ok] (or raised) before its fix
         and returns the expected [Error] after:

         - Unvalidated column references: a query could name a column that is
           not in the schema and have it passed straight through into the
           generated SQL, letting a caller probe the real database schema.
           Columns are now validated against the MQL schema in select lists,
           GROUP BY and ORDER BY, and the check is not suppressed by an
           unrelated WITH.

         - SQL injection via identifiers: an identifier containing a quote or
           semicolon was substituted into the SQL verbatim; [of_mql] now
           rejects any identifier outside the [A-Za-z_][A-Za-z0-9_]*] charset.

         An aliased unknown table additionally raised an uncaught [Not_found],
         surfacing as a 500 instead of a clean error. *)
      Oth.test ~name:"unknown column in select list is rejected" (fun _ ->
          let query = build_str [ "select bogus from test" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"unknown qualified column in select list is rejected" (fun _ ->
          let query = build_str [ "select test.bogus from test" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"unknown column in group by is rejected" (fun _ ->
          let query = build_str [ "select * from test group by bogus" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"unknown column in order by is rejected" (fun _ ->
          let query = build_str [ "select id from test order by bogus" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"known columns are still allowed" (fun _ ->
          (* The enforcement must not reject legitimate references: a qualified
             column on a real table, an aliased column referenced in order by,
             and a column that the body of a CTE makes. *)
          CCList.iter
            (fun query ->
              ignore
                (Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
                @@ of_mql ~schema
                @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string query))
            [
              build_str [ "select test.id from test" ];
              build_str [ "select id as other_id from test order by other_id" ];
              build_str [ "with foo as (select id from test) select id from foo" ];
            ];
          ());
      (* MQL reads these forms for the SQL of this repository.  They read nothing that the
         schema cannot check, thus a query from outside can use them. *)
      Oth.test
        ~name:"HAVING with no GROUP BY and a column named rows are legal"
        ~tags:[ "mql" ]
        (fun _ ->
          CCList.iter
            (fun query ->
              ignore
                (Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
                @@ of_mql ~schema
                @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string query))
            [
              build_str [ "select count(*) from test having count(*) > 0" ];
              build_str [ "select count(*) as rows from test" ];
            ];
          ());
      Oth.test ~name:"WITH does not disable column checks" (fun _ ->
          (* A CTE that is not in scope of the outer select must not suppress
             [`Unknown_column_err] for a concrete table in that select. *)
          let query =
            build_str [ "with x as (select id from test) select id from test where bogus is null" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"aliased unknown table is a clean error" (fun _ ->
          (* Must return [`Table_access_err], not raise an uncaught
             [Not_found] (which surfaced as a 500). *)
          let query = build_str [ "select * from other_table as x" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"invalid identifier in column is rejected" (fun _ ->
          (* The MQL lexer cannot produce such an identifier today; build the
             AST directly to exercise the [of_mql] charset guard. *)
          let ast =
            Mql.Build.(select ~from:[ table "test" ] ~cols:(columns [ col (id "evil\"; drop") ]) ())
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Invalid_identifier_err "evil\"; drop"))
            (of_mql ~schema ast);
          ());
      Oth.test ~name:"invalid identifier in table is rejected" (fun _ ->
          let ast = Mql.Build.(select ~from:[ table "test; drop table test" ] ~cols:star ()) in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Invalid_identifier_err "test; drop table test"))
            (of_mql ~schema ast);
          ());
      (* Tenant scoping relies on a query only ever reaching a table through
         its same-named scoping CTE (see sgs_mql_paged); a schema-qualified name
         would resolve past the CTE to the real relation.  MQL reads the
         [schema.table] form, because the SQL of this repository writes it, thus
         [of_mql] is the one layer that refuses it: it refuses the qualifier that
         the parser builds, and it refuses the dotted identifier that a caller
         builds directly. *)
      Oth.test ~name:"schema-qualified table name is rejected" (fun _ ->
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Construct_not_allowed_err "schema-qualified table terrateam"))
            (of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string "select * from terrateam.test");
          let ast = Mql.Build.(select ~from:[ table "terrateam.test" ] ~cols:star ()) in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Invalid_identifier_err "terrateam.test"))
            (of_mql ~schema ast);
          ());
      Oth.test ~name:"sensitive Terraform-state columns are queryable" (fun _ ->
          (* Documents (does not flag) the deliberate exposure: instance
             attributes/sensitive_attributes/private and output values are
             queryable by any tenant member. See sgs_mql_paged.ml / the CTE
             wrapper in select_mql_page.sql. *)
          CCList.iter
            (fun query ->
              ignore
                (Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
                @@ of_mql ~schema
                @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string query))
            [
              build_str [ "select attributes, sensitive_attributes, private from instances" ];
              build_str [ "select value from outputs" ];
            ];
          ());
      Oth.test ~name:"Pages 1" (fun _ ->
          let module Ps = Mql_to_pgsql.Pages in
          let module P = Mql_to_pgsql.Page in
          let results =
            [ `Assoc [ ("name", `String "Bob") ]; `Assoc [ ("name", `String "Eve") ] ]
          in
          let query = build_str [ "select * from test order by name" ] in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let t = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
          let pages =
            {
              Ps.prev = { P.dir = P.Negate; cursor = `Assoc [ ("name", `String "Bob") ] };
              next = { P.dir = P.Affirm; cursor = `Assoc [ ("name", `String "Eve") ] };
            }
          in
          Oth.Assert.eq
            ~eq:(CCResult.equal ~err:Mql_to_pgsql.equal_pages_err (CCOption.equal Ps.equal))
            ~pp:(CCResult.pp' (CCOption.pp Ps.pp) Mql_to_pgsql.pp_pages_err)
            (Ok (Some pages))
            (Mql_to_pgsql.pages results t);
          ());
      Oth.test ~name:"Pages 2" (fun _ ->
          let module Ps = Mql_to_pgsql.Pages in
          let results =
            [ `Assoc [ ("name", `String "Bob") ]; `Assoc [ ("name", `String "Eve") ] ]
          in
          let query = build_str [ "select * from test" ] in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let t = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
          Oth.Assert.eq
            ~eq:(CCResult.equal ~err:Mql_to_pgsql.equal_pages_err (CCOption.equal Ps.equal))
            ~pp:(CCResult.pp' (CCOption.pp Ps.pp) Mql_to_pgsql.pp_pages_err)
            (Ok None)
            (Mql_to_pgsql.pages results t);
          ());
      Oth.test ~name:"Pages 3" (fun _ ->
          let module Ps = Mql_to_pgsql.Pages in
          let results =
            [ `Assoc [ ("name", `String "Bob") ]; `Assoc [ ("name", `String "Eve") ] ]
          in
          let query = build_str [ "select * from test order by 1 + 1" ] in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let t = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
          Oth.Assert.eq
            ~eq:(CCResult.equal ~err:Mql_to_pgsql.equal_pages_err (CCOption.equal Ps.equal))
            ~pp:(CCResult.pp' (CCOption.pp Ps.pp) Mql_to_pgsql.pp_pages_err)
            (Error
               (`Order_by_col_not_identifier_err
                  Mql_ast.(
                    Add
                      ( Index (Identifier (ident "$bigints"), Int 2),
                        Index (Identifier (ident "$bigints"), Int 1) ))))
            (Mql_to_pgsql.pages results t);
          ());
      Oth.test ~name:"Apply page 1" (fun _ ->
          let query = build_str [ "select * from test order by name" ] in
          let sql = build_str [ "select * from test"; "where name >= 'Bob'"; "order by name" ] in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("name", `String "Bob") ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 2" (fun _ ->
          let query = build_str [ "select * from test order by name" ] in
          let sql = build_str [ "select * from test where name <= 'Bob' order by name desc" ] in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Negate; cursor = `Assoc [ ("name", `String "Bob") ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 3" (fun _ ->
          let query = build_str [ "select * from test where age > 18 order by name" ] in
          let sql =
            build_str [ "select * from test"; "where name >= 'Bob' and age > 18"; "order by name" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("name", `String "Bob") ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 4" (fun _ ->
          let query = build_str [ "select * from test where age > 18 order by name" ] in
          let sql =
            build_str
              [ "select * from test"; "where name <= 'Bob' and age > 18"; "order by name desc" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Negate; cursor = `Assoc [ ("name", `String "Bob") ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      (* Multi-column keyset is the lexicographic OR-expansion (#1059), NOT a flat
         [name >= 'Bob' and age >= 34] conjunction (which under-returns once the
         trailing column is not monotonic across the leading one). Leading column
         strict, final column inclusive. *)
      Oth.test ~name:"Apply page 5" (fun _ ->
          let query = build_str [ "select * from test where age > 18 order by name, age" ] in
          let sql =
            build_str
              [
                "select * from test";
                "where (name > 'Bob' or name = 'Bob' and age >= 34) and age > 18";
                "order by name, age";
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.
              { dir = Affirm; cursor = `Assoc [ ("name", `String "Bob"); ("age", `Int 34) ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 6" (fun _ ->
          let query = build_str [ "select * from test where age > 18 order by name, age" ] in
          let sql =
            build_str
              [
                "select * from test";
                "where (name < 'Bob' or name = 'Bob' and age <= 34) and age > 18";
                "order by name desc, age desc";
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.
              { dir = Negate; cursor = `Assoc [ ("name", `String "Bob"); ("age", `Int 34) ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 7" (fun _ ->
          let query = build_str [ "select a + b as bar from test order by bar" ] in
          let sql =
            build_str [ "select a + b as bar from test"; "where a + b <= 3"; "order by bar desc" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page = Mql_to_pgsql.Page.{ dir = Negate; cursor = `Assoc [ ("bar", `Int 3) ] } in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 8" (fun _ ->
          let query = build_str [ "select a, count(*) from test group by a order by count(*)" ] in
          let sql =
            build_str
              [ "select a, count(*) from test group by a having count(*) >= 3 order by count(*)" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page = Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("count", `Int 3) ] } in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 9" (fun _ ->
          let query = build_str [ "select a, count(*) as c from test group by a order by c" ] in
          let sql =
            build_str
              [ "select a, count(*) as c from test group by a having count(*) >= 3 order by c" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page = Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("c", `Int 3) ] } in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Apply page 10" (fun _ ->
          let query =
            build_str [ "select a, count(*) as c from test where a > 10"; "group by a order by c" ]
          in
          let sql =
            build_str
              [
                "select a, count(*) as c from test where a > 10";
                "group by a having count(*) >= 3 order by c";
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page = Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("c", `Int 3) ] } in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      (* #1059: mixed ASC/DESC -- each column's strict/inclusive comparator
         honours its own direction (name asc -> >, age desc -> <=). *)
      Oth.test ~name:"Apply page mixed asc/desc" (fun _ ->
          let query = build_str [ "select * from test order by name asc, age desc" ] in
          let sql =
            build_str
              [
                "select * from test";
                "where name > 'Bob' or name = 'Bob' and age <= 34";
                "order by name asc, age desc";
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.
              { dir = Affirm; cursor = `Assoc [ ("name", `String "Bob"); ("age", `Int 34) ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      (* #1059: a multi-column aggregate order paginates via a single
         lexicographic keyset in HAVING (not a flat AND split across
         WHERE/HAVING). *)
      Oth.test ~name:"Apply page group-by multi-column" (fun _ ->
          let query =
            build_str [ "select a, count(*) as c from test group by a order by c desc, a" ]
          in
          let sql =
            build_str
              [
                "select a, count(*) as c from test group by a";
                "having count(*) < 3 or count(*) = 3 and a >= 5";
                "order by c desc, a";
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("c", `Int 3); ("a", `Int 5) ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      (* #1059: a NULL in a leading order column must chain as [a is null] (a
         NULL-safe equality) rather than [a = null], which is never true and
         would annihilate the whole conjunction. *)
      Oth.test ~name:"Apply page null leading cursor" (fun _ ->
          let query = build_str [ "select * from test order by a, b" ] in
          let sql =
            build_str
              [ "select * from test"; "where a > null or a is null and b >= 'x'"; "order by a, b" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("a", `Null); ("b", `String "x") ] }
          in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err @@ Mql_to_pgsql.apply_page page ast
          in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            sql
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Tenant summary counts" (fun _ ->
          let query =
            build_str
              [
                {|with
ts as (
  select id from states
  where tenant_id = '00000000-0000-0000-0000-000000000000'
  and deleted_at is null
),
cnt_s as (
  select count(*) as c from ts
),
cnt_r as (
  select count(*) as c from resources inner join ts on resources.state_id = ts.id
),
cnt_i as (
  select count(*) as c from instances inner join ts on instances.state_id = ts.id
),
edges as (
  select coalesce(sum(array_length(dependencies, 1)), 0) as c
  from instances inner join ts on instances.state_id = ts.id
),
dp as (
  select providers.name
  from providers inner join ts on providers.state_id = ts.id
  group by providers.name
),
cnt_p as (
  select count(*) as c from dp
),
dm as (
  select resources.module
  from resources inner join ts on resources.state_id = ts.id
  where resources.module is not null
  group by resources.module
),
cnt_m as (
  select count(*) as c from dm
),
top_rt as (
  select resources.type, count(*) as c
  from resources inner join ts on resources.state_id = ts.id
  group by resources.type
  order by c desc
  limit 1
),
largest_mod as (
  select resources.module, count(*) as c
  from resources inner join ts on resources.state_id = ts.id
  where resources.module is not null
  group by resources.module
  order by c desc
  limit 1
),
most_deployed_mod as (
  select resources.module, count(*) as c
  from resources
  inner join ts on resources.state_id = ts.id
  inner join instances on instances.state_id = resources.state_id
    and instances.resource_address = resources.address
  where resources.module is not null
  group by resources.module
  order by c desc
  limit 1
),
graph_roots as (
  select count(*) as c
  from instances inner join ts on instances.state_id = ts.id
  where dependencies is null
  or array_length(dependencies, 1) is null
)
select
  cnt_s.c,
  cnt_r.c,
  cnt_i.c,
  edges.c,
  cnt_p.c,
  cnt_m.c,
  coalesce(top_rt.type, ''),
  coalesce(top_rt.c, 0),
  coalesce(largest_mod.module, ''),
  coalesce(largest_mod.c, 0),
  coalesce(most_deployed_mod.module, ''),
  coalesce(most_deployed_mod.c, 0),
  graph_roots.c
from cnt_s
inner join cnt_r on true
inner join cnt_i on true
inner join edges on true
inner join cnt_p on true
inner join cnt_m on true
left join top_rt on true
left join largest_mod on true
left join most_deployed_mod on true
inner join graph_roots on true|};
              ]
          in
          let sql =
            build_str
              [
                "with";
                "ts as (select id from states where tenant_id = $texts[1]::uuid and deleted_at is \
                 null),";
                "cnt_s as (select count(*) as c from ts),";
                "cnt_r as (select count(*) as c from resources inner join ts on resources.state_id \
                 = ts.id),";
                "cnt_i as (select count(*) as c from instances inner join ts on instances.state_id \
                 = ts.id),";
                "edges as (select coalesce(sum(array_length(dependencies, $bigints[1])), \
                 $bigints[2]) as c from instances inner join ts on instances.state_id = ts.id),";
                "dp as (select providers.name from providers inner join ts on providers.state_id = \
                 ts.id group by providers.name),";
                "cnt_p as (select count(*) as c from dp),";
                "dm as (select resources.module from resources inner join ts on resources.state_id \
                 = ts.id where resources.module is not null group by resources.module),";
                "cnt_m as (select count(*) as c from dm),";
                "top_rt as (select resources.type, count(*) as c from resources inner join ts on \
                 resources.state_id = ts.id group by resources.type order by c desc limit 1),";
                "largest_mod as (select resources.module, count(*) as c from resources inner join \
                 ts on resources.state_id = ts.id where resources.module is not null group by \
                 resources.module order by c desc limit 1),";
                "most_deployed_mod as (select resources.module, count(*) as c from resources inner \
                 join ts on resources.state_id = ts.id inner join instances on instances.state_id \
                 = resources.state_id and instances.resource_address = resources.address where \
                 resources.module is not null group by resources.module order by c desc limit 1),";
                "graph_roots as (select count(*) as c from instances inner join ts on \
                 instances.state_id = ts.id where dependencies is null or \
                 array_length(dependencies, $bigints[3]) is null)";
                "select cnt_s.c, cnt_r.c, cnt_i.c, edges.c, cnt_p.c, cnt_m.c, \
                 coalesce(top_rt.type, $texts[2]), coalesce(top_rt.c, $bigints[4]), \
                 coalesce(largest_mod.module, $texts[3]), coalesce(largest_mod.c, $bigints[5]), \
                 coalesce(most_deployed_mod.module, $texts[4]), coalesce(most_deployed_mod.c, \
                 $bigints[6]), graph_roots.c from cnt_s inner join cnt_r on true inner join cnt_i \
                 on true inner join edges on true inner join cnt_p on true inner join cnt_m on \
                 true left join top_rt on true left join largest_mod on true left join \
                 most_deployed_mod on true inner join graph_roots on true limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Provider distribution" (fun _ ->
          let query =
            build_str
              [
                {|select providers.name as provider, count(*) as instances
from providers
inner join states on providers.state_id = states.id
inner join resources on resources.state_id = providers.state_id
  and resources.provider = providers.name
inner join instances on instances.state_id = resources.state_id
  and instances.resource_address = resources.address
where states.tenant_id = '00000000-0000-0000-0000-000000000000'
  and states.deleted_at is null
group by providers.name
order by instances desc|};
              ]
          in
          let sql =
            build_str
              [
                "select providers.name as provider, count(*) as instances from providers inner \
                 join states on providers.state_id = states.id inner join resources on \
                 resources.state_id = providers.state_id and resources.provider = providers.name \
                 inner join instances on instances.state_id = resources.state_id and \
                 instances.resource_address = resources.address where states.tenant_id = \
                 $texts[1]::uuid and states.deleted_at is null group by providers.name order by \
                 instances desc limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Resource type distribution" (fun _ ->
          let query =
            build_str
              [
                {|select resources.type as type, count(*) as instances
from resources
inner join states on resources.state_id = states.id
inner join instances on instances.state_id = resources.state_id
  and instances.resource_address = resources.address
where states.tenant_id = '00000000-0000-0000-0000-000000000000'
  and states.deleted_at is null
group by resources.type
order by instances desc|};
              ]
          in
          let sql =
            build_str
              [
                "select resources.type as type, count(*) as instances from resources inner join \
                 states on resources.state_id = states.id inner join instances on \
                 instances.state_id = resources.state_id and instances.resource_address = \
                 resources.address where states.tenant_id = $texts[1]::uuid and states.deleted_at \
                 is null group by resources.type order by instances desc limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Dep hotspot UNNEST" (fun _ ->
          let query =
            build_str
              [
                {|with
ts as (
  select id from states
  where tenant_id = '00000000-0000-0000-0000-000000000000'
  and deleted_at is null
),
dep_hotspot as (
  select dep as address, count(*) as c
  from instances, unnest(dependencies) as dep
  inner join ts on instances.state_id = ts.id
  group by dep order by c desc limit 1
)
select coalesce(dep_hotspot.address, ''), coalesce(dep_hotspot.c, 0)
from dep_hotspot|};
              ]
          in
          let sql =
            build_str
              [
                "with";
                "ts as (select id from states where tenant_id = $texts[1]::uuid and deleted_at is \
                 null),";
                "dep_hotspot as (select dep as address, count(*) as c from instances, \
                 unnest(dependencies) as dep inner join ts on instances.state_id = ts.id group by \
                 dep order by c desc limit 1)";
                "select coalesce(dep_hotspot.address, $texts[2]), coalesce(dep_hotspot.c, \
                 $bigints[1]) from dep_hotspot limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"All deps + graph leaves UNNEST" (fun _ ->
          let query =
            build_str
              [
                {|with
ts as (
  select id from states
  where tenant_id = '00000000-0000-0000-0000-000000000000'
  and deleted_at is null
),
all_deps as (
  select dep as address
  from instances, unnest(dependencies) as dep
  inner join ts on instances.state_id = ts.id
  group by dep
),
graph_leaves as (
  select count(*) as c
  from instances
  inner join ts on instances.state_id = ts.id
  left join all_deps on all_deps.address = instances.address
  where all_deps.address is null
)
select graph_leaves.c from graph_leaves|};
              ]
          in
          let sql =
            build_str
              [
                "with";
                "ts as (select id from states where tenant_id = $texts[1]::uuid and deleted_at is \
                 null),";
                "all_deps as (select dep as address from instances, unnest(dependencies) as dep \
                 inner join ts on instances.state_id = ts.id group by dep),";
                "graph_leaves as (select count(*) as c from instances inner join ts on \
                 instances.state_id = ts.id left join all_deps on all_deps.address = \
                 instances.address where all_deps.address is null)";
                "select graph_leaves.c from graph_leaves limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Orphaned count UNNEST" (fun _ ->
          let query =
            build_str
              [
                {|with
ts as (
  select id from states
  where tenant_id = '00000000-0000-0000-0000-000000000000'
  and deleted_at is null
),
all_deps as (
  select dep as address
  from instances, unnest(dependencies) as dep
  inner join ts on instances.state_id = ts.id
  group by dep
),
orphaned as (
  select count(*) as c
  from instances
  inner join ts on instances.state_id = ts.id
  left join resources on resources.state_id = instances.state_id
    and resources.address = instances.resource_address
  left join all_deps on all_deps.address = instances.address
  where resources.address is null
  and all_deps.address is null
)
select orphaned.c from orphaned|};
              ]
          in
          let sql =
            build_str
              [
                "with";
                "ts as (select id from states where tenant_id = $texts[1]::uuid and deleted_at is \
                 null),";
                "all_deps as (select dep as address from instances, unnest(dependencies) as dep \
                 inner join ts on instances.state_id = ts.id group by dep),";
                "orphaned as (select count(*) as c from instances inner join ts on \
                 instances.state_id = ts.id left join resources on resources.state_id = \
                 instances.state_id and resources.address = instances.resource_address left join \
                 all_deps on all_deps.address = instances.address where resources.address is null \
                 and all_deps.address is null)";
                "select orphaned.c from orphaned limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Success MATERIALIZED 1" (fun _ ->
          let query =
            build_str
              [
                "with foo as materialized (select * from test)";
                "select * from foo where foo.id is not null";
              ]
          in
          let sql =
            build_str
              [
                "with foo as materialized (select * from test)";
                "select * from foo where foo.id is not null";
                "limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Bad table access 4" (fun _ ->
          (* Table not in the schema, referenced in the body of a WITH. *)
          let query = build_str [ "with foo as (select * from test) select * from other_table" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 5" (fun _ ->
          (* Table not in the schema, referenced in a second (nested) CTE. *)
          let query =
            build_str
              [ "with a as (select * from test), b as (select * from other_table) select * from a" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 6" (fun _ ->
          (* Table not in the schema, referenced inside a materialized CTE. *)
          let query =
            build_str [ "with foo as materialized (select * from other_table) select * from foo" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 7" (fun _ ->
          (* A declared CTE must not grant the body access to an undeclared table. *)
          let query =
            build_str [ "with foo as (select * from test) select * from foo, other_table" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Unknown column 2" (fun _ ->
          (* Column not in the schema, referenced inside a CTE body. *)
          let query =
            build_str
              [ "with foo as (select * from test where bad_col is not null) select * from foo" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bad_col"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Unknown column 3" (fun _ ->
          (* Table-qualified column not in the schema, referenced in the body of a WITH.
             A bare (unqualified) column is resolved leniently once a CTE is in scope --
             since CTE tables have an unknown column set -- but a column qualified by a
             real schema table is always checked. *)
          let query =
            build_str
              [
                "with foo as (select * from test) select * from test where test.bad_col is not null";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bad_col"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      (* --- Subqueries: IN-subquery and EXISTS --- *)
      Oth.test ~name:"Subquery IN 1" (fun _ ->
          let query =
            build_str [ "select * from states where id in (select state_id from resources)" ]
          in
          let sql =
            build_str
              [ "select * from states where id in (select state_id from resources) limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Literal IN single element" (fun _ ->
          let query = build_str [ "select * from test where name in ('a')" ] in
          let sql = build_str [ "select * from test where name in ($texts[1]) limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Literal IN multiple elements" (fun _ ->
          let query = build_str [ "select * from test where name in ('a', 'b')" ] in
          let sql =
            build_str [ "select * from test where name in ($texts[1], $texts[2]) limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Literal IN coerces elements to column type" (fun _ ->
          (* The column is uuid: each list element must be cast, exactly as the
             [=] operator does. *)
          let query = build_str [ "select * from test where id in ('a')" ] in
          let sql = build_str [ "select * from test where id in ($texts[1]::uuid) limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"Literal IN coerces multiple elements to column type" (fun _ ->
          let query = build_str [ "select * from test where id in ('a', 'b')" ] in
          let sql =
            build_str
              [ "select * from test where id in ($texts[1]::uuid, $texts[2]::uuid) limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Subquery EXISTS correlated 1" (fun _ ->
          (* The inner subquery references states.id from the enclosing query. *)
          let query =
            build_str
              [
                "select * from states";
                "where exists (select * from resources where resources.state_id = states.id)";
              ]
          in
          let sql =
            build_str
              [
                "select * from states";
                "where exists (select * from resources where resources.state_id = states.id)";
                "limit 20";
              ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Subquery with WITH 1" (fun _ ->
          let query =
            build_str
              [
                "select * from states";
                "where id in (with r as (select state_id from resources) select state_id from r)";
              ]
          in
          let sql =
            build_str
              [
                "select * from states";
                "where id in (with r as (select state_id from resources) select state_id from r)";
                "limit 20";
              ]
          in
          assert_eq sql query;
          ());
      (* --- Security: every subquery denial path. Each must be Error with the
         exact variant; an Ok or wrong variant is a failure. --- *)
      Oth.test ~name:"Subquery denial: bad table in IN" (fun _ ->
          let query = build_str [ "select * from test where id in (select id from other_table)" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad table in EXISTS" (fun _ ->
          let query = build_str [ "select * from test where exists (select * from other_table)" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad table in join inside subquery" (fun _ ->
          let query =
            build_str
              [
                "select * from test where exists";
                "(select * from resources inner join other_table on resources.state_id = \
                 other_table.id)";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad table in WITH inside subquery" (fun _ ->
          let query =
            build_str
              [
                "select * from test";
                "where id in (with r as (select * from other_table) select * from r)";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad table in nested subquery" (fun _ ->
          let query =
            build_str
              [
                "select * from test where exists";
                "(select * from resources where state_id in (select id from other_table))";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad column in subquery" (fun _ ->
          let query =
            build_str
              [
                "select * from test where exists";
                "(select * from resources where resources.bad_col is not null)";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bad_col"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad function in subquery" (fun _ ->
          let query =
            build_str [ "select * from test where exists (select foobar(state_id) from resources)" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Func_access_err "foobar"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad cast in subquery" (fun _ ->
          let query =
            build_str
              [ "select * from test where exists (select state_id::regclass from resources)" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Cast_err "regclass"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: correlation is not a hole" (fun _ ->
          (* [users] is a real schema table but is in neither the subquery's own FROM
             nor the enclosing query's FROM, so it must still be rejected. *)
          let query =
            build_str
              [
                "select * from test where exists";
                "(select * from resources where users.id = test.id)";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "users"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      (* --- UNION / UNION ALL --- *)
      Oth.test ~name:"Union 1" (fun _ ->
          let query = build_str [ "select name from states union select name from resources" ] in
          let sql =
            build_str [ "select name from states union select name from resources limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Union all 1" (fun _ ->
          let query =
            build_str [ "select name from states union all select name from resources" ]
          in
          let sql =
            build_str [ "select name from states union all select name from resources limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"Union order/limit" (fun _ ->
          let query =
            build_str
              [ "select name from states union select name from resources order by name limit 5" ]
          in
          let sql =
            build_str
              [ "select name from states union select name from resources order by name limit 5" ]
          in
          assert_eq sql query;
          ());
      (* --- Security: every union branch is schema-validated. Each must be Error
         with the exact variant. --- *)
      Oth.test ~name:"Union denial: bad table in left branch" (fun _ ->
          let query = build_str [ "select name from other_table union select name from states" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad table in right branch" (fun _ ->
          let query = build_str [ "select name from states union select name from other_table" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad table in third chained branch" (fun _ ->
          let query =
            build_str
              [
                "select name from states union select name from resources";
                "union select name from other_table";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad table in parenthesized branch" (fun _ ->
          let query =
            build_str [ "(select name from other_table) union select name from states" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Set operation denial: each branch of each set operation" (fun _ ->
          assert_cases
            ~expected:(of_mql_err (`Table_access_err "other_table"))
            (CCList.flat_map
               (fun op ->
                 [
                   ( op ^ ", left branch",
                     "select name from other_table " ^ op ^ " select name from states" );
                   ( op ^ ", right branch",
                     "select name from states " ^ op ^ " select name from other_table" );
                   ( op ^ ", parenthesized left branch",
                     "(select name from other_table) " ^ op ^ " select name from states" );
                   ( op ^ ", parenthesized right branch",
                     "select name from states " ^ op ^ " (select name from other_table)" );
                 ])
               [ "union"; "intersect"; "except" ]);
          ());
      Oth.test ~name:"Union denial: bad table in union nested in subquery" (fun _ ->
          let query =
            build_str
              [
                "select * from test where id in";
                "(select id from states union select id from other_table)";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad column in a branch" (fun _ ->
          let query =
            build_str
              [
                "select name from states union select name from resources";
                "where resources.bad_col is not null";
              ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bad_col"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad function in a branch" (fun _ ->
          let query =
            build_str [ "select foobar(name) from states union select name from resources" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Func_access_err "foobar"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad cast in a branch" (fun _ ->
          let query =
            build_str [ "select name::regclass from states union select name from resources" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Cast_err "regclass"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union apply_page is rejected" (fun _ ->
          let query =
            build_str [ "select name from states union select name from resources order by name" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let page =
            Mql_to_pgsql.Page.{ dir = Affirm; cursor = `Assoc [ ("name", `String "Bob") ] }
          in
          Oth.Assert.eq
            ~eq:(CCResult.equal ~err:Mql_to_pgsql.equal_apply_page_err Mql.Ast.equal)
            ~pp:(CCResult.pp' Mql.Ast.pp Mql_to_pgsql.pp_apply_page_err)
            (Error `Missing_order_by_err)
            (Mql_to_pgsql.apply_page page ast);
          ());
      Oth.test ~name:"Union pages returns None" (fun _ ->
          let module Ps = Mql_to_pgsql.Pages in
          let results =
            [ `Assoc [ ("name", `String "Bob") ]; `Assoc [ ("name", `String "Eve") ] ]
          in
          let query =
            build_str [ "select name from states union select name from resources order by name" ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let t = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
          Oth.Assert.eq
            ~eq:(CCResult.equal ~err:Mql_to_pgsql.equal_pages_err (CCOption.equal Ps.equal))
            ~pp:(CCResult.pp' (CCOption.pp Ps.pp) Mql_to_pgsql.pp_pages_err)
            (Ok None)
            (Mql_to_pgsql.pages results t);
          ());
      (* --- Array-aggregating functions --- *)
      Oth.test ~name:"json_agg allowed" (fun _ ->
          let query = build_str [ "select json_agg(name) from states" ] in
          let sql = build_str [ "select json_agg(name) from states limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"array_agg allowed" (fun _ ->
          let query = build_str [ "select array_agg(name) from states" ] in
          let sql = build_str [ "select array_agg(name) from states limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"newly allowed scalar functions" (fun _ ->
          let query =
            build_str [ "select lower(name), date_trunc('day', created_at) from states" ]
          in
          let sql =
            build_str
              [ "select lower(name), date_trunc($texts[1], created_at) from states limit 20" ]
          in
          assert_eq sql query;
          ());
      Oth.test ~name:"newly allowed aggregate functions" (fun _ ->
          let query = build_str [ "select string_agg(name, ',') from states" ] in
          let sql = build_str [ "select string_agg(name, $texts[1]) from states limit 20" ] in
          assert_eq sql query;
          ());
      Oth.test ~name:"json_agg over a CTE" (fun _ ->
          let query =
            build_str
              [
                "with rt as (select type, count(*) as c from resources group by type)";
                "select json_agg(json_build_object('type', rt.type, 'c', rt.c)) as dist from rt";
              ]
          in
          let sql =
            build_str
              [
                "with rt as (select type, count(*) as c from resources group by type)";
                "select json_agg(json_build_object($texts[1], rt.type, $texts[2], rt.c)) as dist";
                "from rt limit 20";
              ]
          in
          assert_eq sql query;
          ());
      (* The whole Hermes home page collapsed into one MQL query: scalar widgets
         cross-joined as single-row CTEs, list widgets folded in as json_agg arrays.
         Asserting it parses, schema-validates and translates. *)
      Oth.test ~name:"Home page combined query" (fun _ ->
          let query =
            build_str
              [
                {|with
ts as (
  select id from states
  where tenant_id = '00000000-0000-0000-0000-000000000000'
  and deleted_at is null
),
cnt_s as (select count(*) as c from ts),
cnt_r as (select count(*) as c from resources, ts where resources.state_id = ts.id),
cnt_i as (select count(*) as c from instances, ts where instances.state_id = ts.id),
edges as (
  select coalesce(sum(array_length(dependencies, 1::integer)), 0) as c
  from instances, ts where instances.state_id = ts.id
),
dp as (
  select providers.name from providers, ts
  where providers.state_id = ts.id group by providers.name
),
cnt_p as (select count(*) as c from dp),
dm as (
  select resources.module from resources, ts
  where resources.state_id = ts.id and resources.module is not null
  group by resources.module
),
cnt_m as (select count(*) as c from dm),
graph_roots as (
  select count(*) as c from instances, ts
  where instances.state_id = ts.id
  and array_length(dependencies, 1::integer) is null
),
all_deps as (
  select dep as address from instances, ts, unnest(dependencies) as dep
  where instances.state_id = ts.id group by dep
),
inst_ts as (select instances.address from instances, ts where instances.state_id = ts.id),
graph_leaves as (
  select count(*) as c from inst_ts
  left join all_deps on all_deps.address = inst_ts.address
  where all_deps.address is null
),
inst_base as (
  select instances.address, states.name as state_name
  from instances, ts, states, resources
  where instances.state_id = ts.id
  and states.id = instances.state_id
  and resources.state_id = instances.state_id
  and resources.address = instances.resource_address
  and resources.module is null
  and (array_length(instances.dependencies, 1::integer) is null
    or array_length(instances.dependencies, 1::integer) <= 1)
),
orphaned as (
  select count(*) as c from inst_base
  left join all_deps on all_deps.address = inst_base.address
  where all_deps.address is null
),
top_rt as (
  select resources.type, count(*) as c from resources, ts
  where resources.state_id = ts.id
  group by resources.type order by c desc limit 1
),
largest_mod as (
  select resources.module, count(*) as c from resources, ts
  where resources.state_id = ts.id and resources.module is not null
  group by resources.module order by c desc limit 1
),
inst_mod as (
  select resources.module, instances.address
  from resources, ts, instances
  where resources.state_id = ts.id
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
  and resources.module is not null
  group by resources.module, instances.address
),
most_deployed_mod as (
  select inst_mod.module, count(*) as c from inst_mod
  group by inst_mod.module order by c desc limit 1
),
dep_hotspot as (
  select dep as address, count(*) as c
  from instances, ts, unnest(dependencies) as dep
  where instances.state_id = ts.id
  group by dep order by c desc limit 1
),
orphaned_by_state_rows as (
  select inst_base.state_name, count(*) as c from inst_base
  left join all_deps on all_deps.address = inst_base.address
  where all_deps.address is null
  group by inst_base.state_name
  order by c desc, inst_base.state_name limit 100
),
orphaned_by_state_j as (
  select json_agg(json_build_object(
    'state_name', orphaned_by_state_rows.state_name,
    'c', orphaned_by_state_rows.c)) as j
  from orphaned_by_state_rows
),
orphaned_top_rows as (
  select inst_base.address, inst_base.state_name from inst_base
  left join all_deps on all_deps.address = inst_base.address
  where all_deps.address is null
  order by inst_base.state_name, inst_base.address limit 10
),
orphaned_top_j as (
  select json_agg(json_build_object(
    'address', orphaned_top_rows.address,
    'state_name', orphaned_top_rows.state_name)) as j
  from orphaned_top_rows
),
provider_dist_rows as (
  select providers.name as provider, count(*) as c
  from providers, ts, resources, instances
  where providers.state_id = ts.id
  and resources.state_id = providers.state_id
  and resources.provider = providers.name
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
  group by providers.name order by c desc limit 100
),
provider_dist_j as (
  select json_agg(json_build_object(
    'provider', provider_dist_rows.provider,
    'c', provider_dist_rows.c)) as j
  from provider_dist_rows
),
rt_dist_rows as (
  select resources.type, count(*) as c
  from resources, ts, instances
  where resources.state_id = ts.id
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
  group by resources.type order by c desc limit 100
),
rt_dist_j as (
  select json_agg(json_build_object(
    'type', rt_dist_rows.type,
    'c', rt_dist_rows.c)) as j
  from rt_dist_rows
)
select
  cnt_s.c as total_states,
  cnt_r.c as total_resources,
  cnt_i.c as total_instances,
  edges.c as total_edges,
  cnt_p.c as total_providers,
  cnt_m.c as total_modules,
  graph_roots.c as graph_roots,
  graph_leaves.c as graph_leaves,
  orphaned.c as orphaned_count,
  coalesce(top_rt.type, '') as top_resource_type,
  coalesce(top_rt.c, 0) as top_resource_type_count,
  coalesce(largest_mod.module, '') as largest_module,
  coalesce(largest_mod.c, 0) as largest_module_count,
  coalesce(most_deployed_mod.module, '') as most_deployed_module,
  coalesce(most_deployed_mod.c, 0) as most_deployed_module_count,
  coalesce(dep_hotspot.address, '') as dependency_hotspot,
  coalesce(dep_hotspot.c, 0) as dependency_hotspot_count,
  orphaned_by_state_j.j as orphaned_by_state,
  orphaned_top_j.j as orphaned_top,
  provider_dist_j.j as provider_distribution,
  rt_dist_j.j as resource_type_distribution
from cnt_s, cnt_r, cnt_i, edges, cnt_p, cnt_m, graph_roots, graph_leaves, orphaned,
  orphaned_by_state_j, orphaned_top_j, provider_dist_j, rt_dist_j
left join top_rt on true
left join largest_mod on true
left join most_deployed_mod on true
left join dep_hotspot on true|};
              ]
          in
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
          let _ = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema ast in
          ());
      (* [of_mql] compiles the user-facing query, so it refuses a [$name] even
         when the AST was parsed with variables enabled.  The endpoint never gets
         this far -- it parses with the default [variables:false] -- so this is
         the second, independent gate. *)
      Oth.test ~name:"Variable rejected" (fun _ ->
          let query = build_str [ "select * from test where id = $sid" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Variable_err "sid"))
            (of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string ~variables:true query);
          ());
      Oth.test ~name:"Variable in limit rejected" (fun _ ->
          let query = build_str [ "select * from test order by id limit $n" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Variable_err "n"))
            (of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string ~variables:true query);
          ());
      (* Regression on the [max_limit] cap after widening [limit] to an expr. *)
      Oth.test ~name:"Limit clamped to max_limit" (fun _ ->
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select * from test limit 500" ]
          in
          let query = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~max_limit:5 ~schema ast in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            (build_str [ "select * from test limit 5" ])
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string @@ Mql_to_pgsql.query query);
          ());
      (* The post-condition audit (layer 3).
         [of_mql]'s own guards refuse all of these first, so the audit is
         unreachable through the parser -- which is exactly why it is driven
         directly here.  An audit that is never exercised is not a safety net,
         and these are the tests that prove it fires. *)
      (* Quoting is how SQL spells a name containing punctuation, so it is the
         obvious way to try to smuggle one past the charset guard.  It does not
         work: the guard runs on the name with its quotes stripped, so a quoted
         name gets no more latitude than a bare one. *)
      Oth.test ~name:"Quoted identifier gets no extra latitude" (fun _ ->
          CCList.iter
            (fun (expected, query) ->
              Oth.Assert.eq
                ~pp:Of_mql_result.pp
                ~eq:Of_mql_result.equal
                (Error expected)
                (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query))
            [
              (* Punctuation in a quoted name is refused by the charset guard. *)
              (`Invalid_identifier_err "a b", {|select "a b" from test|});
              ( `Invalid_identifier_err "x); drop table test --",
                {|select "x); drop table test --" from test|} );
              (* A quoted table name still has to be in the schema. *)
              (`Table_access_err "Test", {|select id from "Test"|});
              (* Case matters once quoted: [Id] is not the schema's [id]. *)
              (`Unknown_column_err "Id", {|select "Id" from test|});
            ];
          ());
      Oth.test ~name:"Quoted identifier that is a plain name still works" (fun _ ->
          (* The flip side: quoting a perfectly ordinary name is legal and
             compiles, so the guard is not simply refusing everything quoted. *)
          assert_eq
            (build_str [ "select \"id\" from \"test\" limit 20" ])
            (build_str [ {|select "id" from "test"|} ]);
          ());
      (* Ordering by a non-scalar column used to reach an [assert false] in
         [lookup_col_in_row] and crash. [assert_order_by_cols_can_paginate]
         checks the ORDER BY entry is an identifier, not what TYPE it has, so
         this is reachable from any caller -- it must be an error, not a crash. *)
      Oth.test ~name:"Cursor value that is not a scalar is an error" (fun _ ->
          let module Pages_result = struct
            type t = (Mql_to_pgsql.Pages.t option, Mql_to_pgsql.pages_err) result
            [@@deriving show, eq]
          end in
          let query =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
            @@ of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select address, attributes from instances order by attributes" ]
          in
          (* [attributes] is jsonb, so the row's value is an object -- no cursor. *)
          let row =
            `Assoc [ ("address", `String "x"); ("attributes", `Assoc [ ("k", `String "v") ]) ]
          in
          Oth.Assert.eq
            ~pp:Pages_result.pp
            ~eq:Pages_result.equal
            (Error (`Cursor_value_not_scalar_err ("attributes", `Assoc [ ("k", `String "v") ])))
            (Mql_to_pgsql.pages [ row ] query);
          ());
      (* A page cursor is caller-supplied, so it is hostile input. [apply_page]
         runs BEFORE [of_mql] (see [Sgs_mql_paged.build_query_ast]), so whatever it
         injects is compiled like any other literal: parameterised into the typed
         vectors, never rendered into the SQL text. *)
      Oth.test ~name:"Hostile page cursor is parameterised, not inlined" (fun _ ->
          let evil = "x' or 1=1 --" in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select id from test order by id" ]
          in
          let paged =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err
            @@ Mql_to_pgsql.apply_page
                 {
                   Mql_to_pgsql.Page.dir = Mql_to_pgsql.Page.Affirm;
                   cursor = `Assoc [ ("id", `String evil) ];
                 }
                 ast
          in
          let query = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~schema paged in
          let sql =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string @@ Mql_to_pgsql.query query
          in
          (* The payload is a bound value, so it must NOT appear in the SQL... *)
          Oth.Assert.String.doesnt_contain ~haystack:sql ~needle:evil;
          (* ...it appears as a parameter reference instead... *)
          Oth.Assert.String.contains ~haystack:sql ~needle:"$texts";
          (* ...and the value itself is in the texts vector, to be bound. *)
          Oth.Assert.true_
            ~fail_msg:"cursor value must be bound in the texts vector"
            (CCList.mem ~eq:CCString.equal evil (CCVector.to_list (Mql_to_pgsql.texts query)));
          ());
      Oth.test ~name:"Page cursor cannot smuggle a non-scalar" (fun _ ->
          (* [mk_page_value] only ever yields Null/String/Float/Int, so a cursor
             cannot carry an identifier or a nested structure into the AST. *)
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select id from test order by id" ]
          in
          let module Apply_result = struct
            type t = (Mql_ast.t, Mql_to_pgsql.apply_page_err) result [@@deriving show, eq]
          end in
          Oth.Assert.eq
            ~pp:Apply_result.pp
            ~eq:Apply_result.equal
            (Error (`Page_invalid_type_err (`Assoc [ ("a", `String "b") ])))
            (Mql_to_pgsql.apply_page
               {
                 Mql_to_pgsql.Page.dir = Mql_to_pgsql.Page.Affirm;
                 cursor = `Assoc [ ("id", `Assoc [ ("a", `String "b") ]) ];
               }
               ast);
          ());
      Oth.test ~name:"DISTINCT compiles" (fun _ ->
          assert_eq
            (build_str [ "select distinct id from test limit 20" ])
            (build_str [ "select distinct id from test" ]);
          assert_eq
            (build_str [ "select distinct on (id) id, name from test limit 20" ])
            (build_str [ "select distinct on (id) id, name from test" ]);
          ());
      (* Keyset pagination over DISTINCT is unsound -- the keyset predicate is
         evaluated before the dedup, so a cursor taken from a returned row does
         not name a boundary of the result the caller saw.  Both halves of the
         guard are asserted: no cursor is ever offered, and a forged one is
         refused. *)
      Oth.test ~name:"DISTINCT offers no pagination cursor" (fun _ ->
          let module Pages_result = struct
            type t = (Mql_to_pgsql.Pages.t option, Mql_to_pgsql.pages_err) result
            [@@deriving show, eq]
          end in
          let query =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
            @@ of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select distinct id from test order by id" ]
          in
          Oth.Assert.eq
            ~pp:Pages_result.pp
            ~eq:Pages_result.equal
            (Ok None)
            (Mql_to_pgsql.pages [ `Assoc [ ("id", `String "a") ] ] query);
          ());
      Oth.test ~name:"DISTINCT refuses an applied page" (fun _ ->
          let module Apply_result = struct
            type t = (Mql_ast.t, Mql_to_pgsql.apply_page_err) result [@@deriving show, eq]
          end in
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select distinct id from test order by id" ]
          in
          Oth.Assert.eq
            ~pp:Apply_result.pp
            ~eq:Apply_result.equal
            (Error `Distinct_cannot_paginate_err)
            (Mql_to_pgsql.apply_page
               {
                 Mql_to_pgsql.Page.dir = Mql_to_pgsql.Page.Affirm;
                 cursor = `Assoc [ ("id", `String "a") ];
               }
               ast);
          ());
      Oth.test ~name:"Non-DISTINCT still paginates" (fun _ ->
          (* The guard must not have disabled pagination generally. *)
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select id from test order by id" ]
          in
          ignore
            (Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_apply_page_err
            @@ Mql_to_pgsql.apply_page
                 {
                   Mql_to_pgsql.Page.dir = Mql_to_pgsql.Page.Affirm;
                   cursor = `Assoc [ ("id", `String "a") ];
                 }
                 ast);
          ());
      (* The two gates are independent. The parse-level [Mql.Feature] gate is
         tested in code/tests/mql; this asserts that opting in there still does
         not get a locking clause past [of_mql] -- so a single mistake (enabling
         the feature on the endpoint) would not be enough to reach the database
         with a row lock. *)
      Oth.test ~name:"Locking is refused by of_mql even when parsed" (fun _ ->
          CCList.iter
            (fun sql ->
              let ast =
                Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string ~features:[ Mql.Feature.Locking_clause ]
                @@ build_str [ sql ]
              in
              Oth.Assert.eq
                ~pp:Of_mql_result.pp
                ~eq:Of_mql_result.equal
                (Error `Locking_not_allowed_err)
                (of_mql ~schema ast))
            [
              "select id from test for update";
              "select id from test for update skip locked";
              "select id from test for share";
            ];
          ());
      Oth.test ~name:"DML is refused by of_mql even when parsed" (fun _ ->
          CCList.iter
            (fun sql ->
              let ast =
                Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string ~features:[ Mql.Feature.Data_modifying ]
                @@ build_str [ sql ]
              in
              Oth.Assert.eq
                ~pp:Of_mql_result.pp
                ~eq:Of_mql_result.equal
                (Error `Data_modifying_not_allowed_err)
                (of_mql ~schema ast))
            [
              "insert into test (id) values ('a')";
              "insert into test (id) select id from test";
              "update test set id = 'a'";
              "delete from test";
              "delete from test returning id";
              (* Hidden inside a CTE, where the outer statement is a plain
                 SELECT -- the write must still be refused. *)
              "with d as (delete from test returning id) select id from d";
              "with d as (insert into test (id) values ('a') returning id) select id from d";
              "with d as (update test set id = 'a' returning id) select id from d";
            ];
          ());
      Oth.test ~name:"DDL is refused by of_mql even when parsed" (fun _ ->
          CCList.iter
            (fun sql ->
              let ast =
                Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string ~features:[ Mql.Feature.Ddl ]
                @@ build_str [ sql ]
              in
              Oth.Assert.eq
                ~pp:Of_mql_result.pp
                ~eq:Of_mql_result.equal
                (Error `Ddl_not_allowed_err)
                (of_mql ~schema ast))
            [
              "create table evil (a integer)";
              "alter table test add column evil text";
              "drop table test";
              "create index on test (id)";
              "create view v as select id from test";
              "truncate test";
            ];
          ());
      Oth.test ~name:"Audit: qualified table name" (fun _ ->
          (* The shape a schema-qualified name takes if it reaches here whole.
             The charset guard refuses it before the schema-membership check even
             runs, because [.] is not a legal identifier character -- so a dotted
             name is denied twice over.  Asserting the exact error documents WHICH
             guard fires; the point of the test is that one does. *)
          assert_audit_err (`Audit_identifier_err "public.test") (table_query "public.test");
          ());
      Oth.test ~name:"Audit: table outside the schema" (fun _ ->
          (* Charset-legal, but no such table -- this is the membership check
             itself, isolated from the charset guard above. *)
          assert_audit_err (`Audit_table_err "pg_authid") (table_query "pg_authid");
          ());
      Oth.test ~name:"Audit: locking clause" (fun _ ->
          (* The rewrite emits no row lock, and [FOR UPDATE OF t] carries table
             names -- [pg_authid] here -- that the audit would otherwise never
             see.  [of_mql] refuses a lock before the audit runs, so the AST is
             put in front of the audit directly, the way a bug in this module
             would deliver it. *)
          let parse_locking sql =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string ~features:[ Mql.Feature.Locking_clause ]
            @@ build_str [ sql ]
          in
          (* Names every table in scope. *)
          assert_audit_err `Audit_locking_err (parse_locking "select id from test for update");
          (* Names a table outside the schema. *)
          assert_audit_err
            `Audit_locking_err
            (parse_locking "select id from test for update of pg_authid");
          ());
      Oth.test ~name:"Audit: function outside the allow-list" (fun _ ->
          assert_audit_err
            (`Audit_func_err "pg_read_file")
            (select_expr Mql_ast.(Func (func "pg_read_file" [ String "/etc/passwd" ])));
          ());
      Oth.test ~name:"Audit: cast outside the allow-list" (fun _ ->
          assert_audit_err
            (`Audit_cast_err "regclass")
            (select_expr Mql_ast.(Cast (String "test", cast_type "regclass")));
          ());
      Oth.test ~name:"Audit: a FROM item the schema cannot check" ~tags:[ "mql" ] (fun _ ->
          (* MQL reads these so that it can read the SQL of this repository. A
             query from outside must not get them. A call in a FROM clause
             makes columns the schema does not know; a lateral item reads the
             rows of the items before it. *)
          let from_query table_ref =
            Mql_ast.(
              Query
                {
                  body =
                    Select
                      {
                        distinct = None;
                        select_list = Star;
                        from = [ { fe_table = table_ref; fe_joins = [] } ];
                        where = None;
                        group_by = None;
                        having = None;
                      };
                  order_by = None;
                  limit = None;
                  offset = None;
                  locking = None;
                })
          in
          assert_audit_err
            (`Audit_construct_err "a call in a from clause")
            (from_query
               Mql_ast.(
                 Func_table
                   {
                     expr = Func (func "jsonb_each" [ Identifier (ident "id") ]);
                     ordinality = false;
                     alias = Some (ident "e");
                     columns = [];
                     lateral_ = false;
                   }));
          assert_audit_err
            (`Audit_construct_err "column alias list")
            (from_query
               Mql_ast.(
                 Unnest
                   {
                     exprs = [ Identifier (ident "id") ];
                     alias = ident "t";
                     columns = [ { ca_name = ident "a"; ca_type = None } ];
                   }));
          assert_audit_err
            (`Audit_construct_err "unnest of more than one array")
            (from_query
               Mql_ast.(
                 Unnest
                   {
                     exprs = [ Identifier (ident "id"); Identifier (ident "id") ];
                     alias = ident "t";
                     columns = [];
                   }));
          ());
      Oth.test ~name:"Audit: an expression the schema cannot check" ~tags:[ "mql" ] (fun _ ->
          (* MQL reads each of these so that it can read the SQL of this
             repository. A query from outside must not get them. *)
          let cases =
            Mql_ast.
              [
                ("a query in an expression", Scalar_subquery (table_query "test"));
                ("a star on a name", Qualified_star (Identifier (ident "test")));
                ("an array", Array_lit [ Int 1 ]);
                ("an array from a query", Array_query (table_query "test"));
                ("the ? operator", Json_has_key (Identifier (ident "id"), String "k"));
                ( "like with an escape",
                  Like_escape (Identifier (ident "id"), String "x", String "!") );
                ("extract", Extract (ident "epoch", Identifier (ident "id")));
                ("substring from", Substring_from (Identifier (ident "id"), String "x"));
                ("position in", Position_in (String "/", Identifier (ident "id")));
                ("the ~* operator", Regex_imatch (Identifier (ident "id"), String "x"));
                ("the !~* operator", Regex_not_imatch (Identifier (ident "id"), String "x"));
                ("collate", Collate (Identifier (ident "id"), { name = "C"; quoted = true }));
                ("the & operator", Bit_and (Identifier (ident "id"), Int 3));
                ( "a json path that is not a literal",
                  Json_obj_val_path (Identifier (ident "id"), Identifier (ident "id")) );
                ( "a json path that is not a literal",
                  Json_obj_query_path (Identifier (ident "id"), Identifier (ident "id")) );
              ]
          in
          CCList.iter
            (fun (name, expr) -> assert_audit_err (`Audit_construct_err name) (select_expr expr))
            cases;
          ());
      Oth.test ~name:"Audit: a group over sets and a named argument" ~tags:[ "mql" ] (fun _ ->
          (* A group over sets makes rows the schema cannot type. An argument
             with a name before it names a parameter of the function. MQL
             reads both so that it can read the SQL of this repository; a query
             from outside must not get them. *)
          CCList.iter
            (fun (name, query) ->
              Oth.Assert.eq
                ~pp:Of_mql_result.pp
                ~eq:Of_mql_result.equal
                (Error (`Construct_not_allowed_err name))
                (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query))
            [
              ("grouping sets", "select id from test group by grouping sets ((id), ())");
              ("a named argument", "select coalesce(id => 1) from test");
              ("the ~* operator", "select id from test where id ~* 'x'");
              ("the !~* operator", "select id from test where id !~* 'x'");
              ("collate", "select id from test order by id collate \"C\"");
              ("the & operator", "select id & 3 from test");
              ("a json path that is not a literal", "select id #> id from test");
              ("a json path that is not a literal", "select id #>> id from test");
            ];
          ());
      Oth.test ~name:"Audit: a query behind not in" ~tags:[ "mql" ] (fun _ ->
          (* A query where a value stands is read the same way behind [not in]
             as anywhere else, thus the tables of the inner query are checked
             against the schema. *)
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "pg_authid"))
            (of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
                 (build_str [ "select id from test where id not in (select id from pg_authid)" ]));
          ());
      Oth.test ~name:"Audit: a recursive CTE" ~tags:[ "mql" ] (fun _ ->
          (* A recursive CTE names itself, thus the guards that read the schema
             cannot check what it reads. *)
          let query = build_str [ "with recursive r as (select id from test) select id from r" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Construct_not_allowed_err "with recursive"))
            (of_mql ~schema @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Audit: a schema-qualified call" ~tags:[ "mql" ] (fun _ ->
          assert_audit_err
            (`Audit_construct_err "schema-qualified call pg_temp")
            (select_expr
               Mql_ast.(
                 Func
                   {
                     (func "count" [ Identifier (ident "id") ]) with
                     qualifier = Some (ident "pg_temp");
                   }));
          ());
      Oth.test ~name:"Audit: a decorated call" ~tags:[ "mql" ] (fun _ ->
          (* MQL reads [DISTINCT], [ORDER BY], [FILTER] and [OVER] inside a call
             so that it can read the SQL of this repository. A query from
             outside must not get them: a window makes the cost of a query hard
             to bound, and a filter and an order inside a call have no use in a
             read endpoint. *)
          assert_audit_err
            (`Audit_construct_err "distinct")
            (select_expr
               Mql_ast.(Func { (func "count" [ Identifier (ident "id") ]) with distinct = true }));
          assert_audit_err
            (`Audit_construct_err "order by")
            (select_expr
               Mql_ast.(
                 Func
                   {
                     (func "string_agg" [ Identifier (ident "id"); String "," ]) with
                     agg_order_by =
                       Some
                         [ { ob_expr = Identifier (ident "id"); ob_order = None; ob_nulls = None } ];
                   }));
          assert_audit_err
            (`Audit_construct_err "filter")
            (select_expr
               Mql_ast.(Func { (func "count" []) with args = Func_star; filter = Some True }));
          assert_audit_err
            (`Audit_construct_err "over")
            (select_expr
               Mql_ast.(
                 Func
                   {
                     (func "count" []) with
                     args = Func_star;
                     over = Some { partition_by = []; window_order_by = None };
                   }));
          ());
      Oth.test ~name:"Audit: a cast target that is not a plain name" ~tags:[ "mql" ] (fun _ ->
          (* The allow-list holds plain type names.  A target that takes an
             argument, that carries a trailing word, that is qualified, or that
             is an array, can match no entry.  RFD 1724 names this a construct
             that the audit cannot check, thus [`Audit_construct_err].  These
             targets exist so that MQL can read the SQL of this repository; a
             query from outside must not get them. *)
          CCList.iter
            (fun target ->
              assert_audit_refuses
                ~expected:audit_construct_err
                (select_expr Mql_ast.(Cast (String "x", target))))
            Mql_ast.
              [
                { (cast_type "numeric") with args = [ 10; 2 ] };
                { (cast_type "timestamp") with type_extra = With_time_zone };
                {
                  (cast_type "text") with
                  type_ident = { qualifier = Some (ident "pg_catalog"); base = ident "text" };
                };
                { (cast_type "text") with array_dims = 1 };
              ];
          ());
      Oth.test ~name:"Audit: out-of-charset identifier" (fun _ ->
          assert_audit_err
            (`Audit_identifier_err "id; drop table test --")
            (select_expr (Mql_ast.Identifier (Mql_ast.ident "id; drop table test --")));
          ());
      Oth.test ~name:"Audit: surviving variable" (fun _ ->
          assert_audit_err (`Audit_variable_err "sid") (select_expr (Mql_ast.Variable "sid"));
          ());
      Oth.test ~name:"Audit: accepts the compiler's own parameter vectors" (fun _ ->
          (* [rw_lit_*] emits [$texts[1]] and friends.  No name starting with [$]
             can pass [valid_identifier], so the audit has to know these are its
             own; if it did not, every query carrying a literal would fail. *)
          CCList.iter
            (fun v ->
              Oth.Assert.eq
                ~pp:Audit_result.pp
                ~eq:Audit_result.equal
                (Ok ())
                (Mql_to_pgsql.Tests.audit_query ~func_allow_list ~cast_allow_list ~schema
                @@ select_expr Mql_ast.(Index (Identifier (ident v), Int 1))))
            [ "$texts"; "$json"; "$smallints"; "$integers"; "$bigints"; "$floats" ];
          ());
      Oth.test ~name:"Audit: a CTE the query binds is a legal table" (fun _ ->
          (* [c] is in no schema, but the query defines it -- the audit must
             track CTE scope or it would reject every WITH query. *)
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "with c as (select id from test) select id from c" ]
          in
          Oth.Assert.eq
            ~pp:Audit_result.pp
            ~eq:Audit_result.equal
            (Ok ())
            (Mql_to_pgsql.Tests.audit_query ~func_allow_list ~cast_allow_list ~schema ast);
          ());
      (* The whole corpus, once, through the shared refusal rules.  The DB-backed
         suite of [sgs_test] runs the same queries against a real database, but
         that suite needs PostgreSQL -- [make test-unit] does not, and it must
         gate the corpus alone. *)
      Oth.test ~name:"Adversarial corpus: every query is refused" (fun _ ->
          assert_cases ~expected:refused (Mql_adversarial_corpus.refusal_queries ()));
    ]

(* RFD 1724, audit gate: one test for each constructor of [audit_err] that
   the tests above do not reach. *)
let audit_gate_tests =
  let parse ~features sql =
    Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string ~features @@ build_str [ sql ]
  in
  Oth.parallel
    [
      Oth.test ~name:"Audit: a schema-qualified table is outside the schema" (fun _ ->
          CCList.iter
            (fun qualifier ->
              assert_audit_refuses
                ~expected:(function
                  | `Audit_table_err _ -> true
                  | _ -> false)
                Mql_ast.(
                  Query
                    {
                      body =
                        Select
                          {
                            distinct = None;
                            select_list = Star;
                            from =
                              [
                                {
                                  fe_table =
                                    Table_ref
                                      {
                                        table_qualifier = Some (ident qualifier);
                                        name = ident "test";
                                        alias = None;
                                      };
                                  fe_joins = [];
                                };
                              ];
                            where = None;
                            group_by = None;
                            having = None;
                          };
                      order_by = None;
                      limit = None;
                      offset = None;
                      locking = None;
                    }))
            [ "public"; "pg_catalog"; "terrateam"; "terrateam_admin" ];
          ());
      Oth.test ~name:"Audit: a recursive CTE given directly" (fun _ ->
          assert_audit_refuses
            ~expected:audit_construct_err
            (parse ~features:[] "with recursive r as (select id from test) select id from r");
          ());
      Oth.test ~name:"Audit: data-modifying statements" (fun _ ->
          CCList.iter
            (fun sql ->
              assert_audit_refuses
                ~expected:(function
                  | `Audit_data_modifying_err -> true
                  | _ -> false)
                (parse ~features:[ Mql.Feature.Data_modifying ] sql))
            [
              "insert into test (id) values ('a')";
              "update test set name = 'a'";
              "delete from test";
              "with d as (insert into test (id) values ('a') returning id) select id from d";
              "with d as (update test set name = 'a' returning id) select id from d";
              "with d as (delete from test returning id) select id from d";
            ];
          ());
      Oth.test ~name:"Audit: schema statements" (fun _ ->
          CCList.iter
            (fun sql ->
              assert_audit_refuses
                ~expected:(function
                  | `Audit_ddl_err -> true
                  | _ -> false)
                (parse ~features:[ Mql.Feature.Ddl ] sql))
            [
              "create table evil (a integer)";
              "alter table test add column evil text";
              "drop table test";
              "truncate test";
            ];
          ());
    ]

(* A function outside the allow list, put in each position of RFD 1724,
   section "Allow lists". *)
let func_positions =
  [
    ("select list", "select pg_read_file('x') from test");
    ("where", "select id from test where pg_read_file('x') is not null");
    ("join on", "select test.id from test join test2 on pg_read_file('x') is not null");
    ("group by", "select count(*) from test group by pg_read_file('x')");
    ("having", "select count(*) from test group by id having pg_read_file('x') is not null");
    ("order by", "select id from test order by pg_read_file('x')");
    ( "subquery",
      "select id from test where id in (select id from test where pg_read_file('x') is not null)" );
    ("cte body", "with c as (select pg_read_file('x') as v from test) select v from c");
    ( "left branch of a set operation",
      "select id from test where pg_read_file('x') is not null union select id from test2" );
    ( "right branch of a set operation",
      "select id from test union select id from test2 where pg_read_file('x') is not null" );
    ("argument of an allowed function", "select lower(pg_read_file('x')) from test");
  ]

(* RFD 1724, allow lists.  The tests that name the allow lists of the library
   are in [api/], because that API does not exist yet. *)
let allow_list_tests =
  Oth.parallel
    [
      Oth.test ~name:"Allow list: each default function is accepted" (fun _ ->
          assert_cases
            ~expected:accepted
            (CCList.flat_map
               (fun (name, queries) -> CCList.map (fun q -> (name, q)) queries)
               Mql_adversarial_corpus.allowed_function_cases);
          ());
      Oth.test ~name:"Allow list: each default cast is accepted" (fun _ ->
          assert_cases
            ~expected:accepted
            (CCList.map
               (fun t -> (t, "select '1'::" ^ t ^ " from test"))
               Mql_adversarial_corpus.default_cast_allow_list);
          ());
      Oth.test ~name:"Allow list: a function outside the list in each position" (fun _ ->
          assert_cases ~expected:(of_mql_err (`Func_access_err "pg_read_file")) func_positions;
          ());
      Oth.test ~name:"Allow list: case and quotes do not get a function past the list" (fun _ ->
          assert_cases
            ~expected:func_access_err
            [
              ("upper case", "select PG_READ_FILE('x') from test");
              ("mixed case", "select Pg_Read_File('x') from test");
              ("quoted identifier", {|select "pg_read_file"('x') from test|});
            ];
          ());
      Oth.test ~name:"Allow list: a schema-qualified function" (fun _ ->
          assert_cases
            ~expected:construct_not_allowed_err
            [
              ("allowed function", "select pg_catalog.lower(name) from test");
              ("function outside the list", "select pg_catalog.pg_read_file('x') from test");
            ];
          ());
      Oth.test ~name:"Allow list: a cast outside the list" (fun _ ->
          assert_cases
            ~expected:(of_mql_err (`Cast_err "regclass"))
            [
              ("the :: form", "select 'test'::regclass from test");
              ("the CAST form", "select cast('test' as regclass) from test");
            ];
          ());
      Oth.test ~name:"Allow list: a cast target that is not a plain name" (fun _ ->
          assert_cases
            ~expected:refused
            [
              ("schema", "select 'x'::pg_catalog.text from test");
              ("type modifier", "select 'x'::varchar(3) from test");
              ("array suffix", "select '{}'::text[] from test");
            ];
          ());
    ]

(* RFD 1724, schema enforcement: the items that the tests above do not
   cover. *)
let schema_tests =
  Oth.parallel
    [
      Oth.test ~name:"Empty schema: a table is refused" (fun _ ->
          assert_cases
            ~schema:empty_schema
            ~expected:(of_mql_err (`Table_access_err "test"))
            [ ("table", "select * from test") ];
          ());
      Oth.test ~name:"Empty schema: a column is refused" (fun _ ->
          assert_cases
            ~schema:empty_schema
            ~expected:(of_mql_err (`Unknown_column_err "id"))
            [ ("column", "select id") ];
          ());
      Oth.test ~name:"Empty schema: constants and allowed calls pass" (fun _ ->
          assert_cases
            ~schema:empty_schema
            ~expected:accepted
            [
              ("constant", "select 1"); ("operator", "select 1 + 2"); ("call", "select lower('a')");
            ];
          ());
      Oth.test ~name:"Table outside the schema in a subquery in the select list" (fun _ ->
          (* RFD 1724: MQL refuses a subquery in an expression as a construct,
             before it reads the tables of the subquery. *)
          assert_cases
            ~expected:construct_not_allowed_err
            [ ("scalar subquery", "select (select rolname from pg_authid) from test") ];
          ());
      Oth.test ~name:"Schema-qualified table" (fun _ ->
          assert_cases
            ~expected:refused
            (CCList.map
               (fun qualifier -> (qualifier, "select * from " ^ qualifier ^ ".test"))
               [ "public"; "pg_catalog"; "terrateam"; "terrateam_admin" ]);
          ());
      (* The parser removes the quotes and keeps the qualifier, thus a quoted
         qualifier is a qualifier, in each position that reads a table. *)
      Oth.test ~name:"Schema-qualified table: quotes give no extra latitude" (fun _ ->
          assert_cases
            ~expected:construct_not_allowed_err
            [
              ("both quoted", {|select * from "public"."test"|});
              ("quoted qualifier", {|select * from "public".test|});
              ("quoted table", {|select * from public."test"|});
              ("quoted admin qualifier", {|select * from "terrateam_admin"."test"|});
              ("qualifier in upper case", {|select * from "PUBLIC"."test"|});
              ("join", {|select * from test join "public"."test2" on test.id = test2.id|});
              ("exists", {|select * from test where exists (select 1 from "public"."test2")|});
              ("in", {|select * from test where id in (select id from "pg_catalog"."test2")|});
              ("cte body", {|with x as (select id from "public"."test") select id from x|});
              ("derived table", {|select * from (select id from "public"."test") as d|});
              ("union", {|select * from test union select * from "public"."test2"|});
            ];
          (* A dot inside one quoted name is not a qualifier.  The name check
             refuses it. *)
          assert_cases
            ~expected:(of_mql_err (`Invalid_identifier_err "public.test"))
            [ ("dot in a quoted name", {|select * from "public.test"|}) ];
          ());
      Oth.test ~name:"Column outside the schema in JOIN ON and HAVING" (fun _ ->
          assert_cases
            ~expected:unknown_column_err
            [
              ("join on", "select test.id from test join test2 on test.bogus = test2.id");
              ("having", "select count(*) from test group by id having max(bogus) > 0");
            ];
          ());
      Oth.test ~name:"System columns" (fun _ ->
          assert_cases
            ~expected:unknown_column_err
            (CCList.flat_map
               (fun col ->
                 [
                   (col, "select " ^ col ^ " from test");
                   ("qualified " ^ col, "select test." ^ col ^ " from test");
                 ])
               [ "ctid"; "xmin"; "xmax"; "cmin"; "cmax"; "tableoid" ]);
          ());
      Oth.test ~name:"Alias: a table alias reads its schema table" (fun _ ->
          assert_cases
            ~expected:accepted
            [ ("column of the table", "select t.id, t.name from test as t") ];
          assert_cases
            ~expected:unknown_column_err
            [
              ("column outside the schema", "select t.bogus from test as t");
              ("column of another table", "select t.a from test as t");
            ];
          ());
      Oth.test ~name:"Alias: a column alias makes no new column" (fun _ ->
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "foo"))
            [
              ("where", "select id as foo from test where foo is not null");
              ("qualified", "select id as foo from test where test.foo is not null");
            ];
          ());
      Oth.test ~name:"Alias: GROUP BY, DISTINCT ON and ORDER BY read an output column" (fun _ ->
          assert_cases
            ~expected:accepted
            [
              ("group by", "select lower(name) as n from test group by n");
              ("order by", "select lower(name) as n from test order by n");
              ("distinct on", "select distinct on (n) lower(name) as n from test order by n");
              ( "group by, with a CTE in scope",
                "with c as (select id from test) select lower(test.name) as n from test, c where \
                 c.id = test.id group by n" );
            ];
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "n"))
            [ ("where", "select lower(name) as n from test where n is not null") ];
          ());
      Oth.test ~name:"Whole row: a table in scope is a whole-row value" (fun _ ->
          assert_cases
            ~expected:accepted
            [
              ("alias", "select t from test as t");
              ("to_jsonb of an alias", "select to_jsonb(t) from test as t");
              ("json_agg of a table", "select json_agg(test) from test");
              ("a CTE", "with c as (select id from test) select to_jsonb(c) from c");
            ];
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "pg_authid"))
            [ ("a table outside the scope", "select to_jsonb(pg_authid) from test") ];
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "test2"))
            [ ("a schema table outside the scope", "select to_jsonb(test2) from test") ];
          ());
      Oth.test ~name:"CTE: exposes only the columns of its body" (fun _ ->
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "bogus"))
            [ ("column of no table", "with foo as (select id from test) select bogus from foo") ];
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "name"))
            [
              ("column of the table", "with foo as (select id from test) select name from foo");
              ("qualified", "with foo as (select id from test) select foo.name from foo");
            ];
          ());
      Oth.test ~name:"CTE: a column list is refused" (fun _ ->
          (* RFD 1724: MQL refuses a CTE column list as a construct, thus a CTE
             exposes only the names that its body makes. *)
          assert_cases
            ~expected:construct_not_allowed_err
            [
              ("listed column", "with c(x) as (select id from test) select x from c");
              ("renamed column", "with c(x) as (select id from test) select id from c");
              ("column of the table", "with c(x) as (select id from test) select name from c");
            ];
          ());
      Oth.test ~name:"CTE: the name of a table outside the schema reads only its body" (fun _ ->
          assert_cases
            ~expected:accepted
            [ ("own column", "with pg_authid as (select id from test) select id from pg_authid") ];
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "rolname"))
            [
              ( "column of the real table",
                "with pg_authid as (select id from test) select rolname from pg_authid" );
            ];
          ());
      Oth.test ~name:"CTE: the name of a schema table reads only its body" (fun _ ->
          assert_cases
            ~expected:accepted
            [ ("own column", "with test2 as (select id from test) select id from test2") ];
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "name"))
            [
              ( "column of the schema table",
                "with test2 as (select id from test) select name from test2" );
            ];
          ());
      Oth.test ~name:"Comparison: a column and an expression that is no literal" (fun _ ->
          assert_cases
            ~expected:accepted
            [
              ("call on the right", "select id from test where name = lower(name)");
              ("call on the left", "select id from test where lower(name) = name");
              ("cast", "select id from test where name = id::text");
              ("negative number", "select a from test3 where a = -1");
              ( "json field",
                "select resources.address from resources, instances where resources.address = \
                 instances.attributes->>'x'" );
              ("in", "select id from test where name in (lower(name), 'x')");
              ("not in", "select id from test where name not in (lower(name), 'x')");
            ];
          (* The expression gets each check that it gets in another position. *)
          assert_cases
            ~expected:(of_mql_err (`Unknown_column_err "bogus"))
            [ ("unknown column", "select id from test where name = lower(bogus)") ];
          assert_cases
            ~expected:func_access_err
            [
              ("function outside the list", "select id from test where name = pg_read_file('x')");
              ("in", "select id from test where name in (pg_read_file('x'))");
            ];
          ());
      Oth.test ~name:"Joins: a join table gets the checks of a FROM table" (fun _ ->
          assert_cases
            ~expected:construct_not_allowed_err
            [
              ("schema-qualified", "select * from test join public.test2 on test.id = test2.id");
              ("function call", "select * from test cross join lower('x') as f");
              ("lateral function call", "select * from test cross join lateral lower('x') as f");
              ( "lateral derived table",
                "select * from test cross join lateral (select id from test2) as d" );
            ];
          assert_cases
            ~expected:(of_mql_err (`Table_access_err "pg_authid"))
            [
              ( "derived table",
                "select * from test join (select rolname from pg_authid) as d on d.rolname = \
                 test.name" );
            ];
          assert_cases
            ~expected:accepted
            [
              ( "alias of a derived table",
                "select d.id from test join (select id from test2) as d on d.id = test.id" );
            ];
          ());
      Oth.test ~name:"Constructs: a window and a function call in FROM" (fun _ ->
          assert_cases
            ~expected:construct_not_allowed_err
            [
              ("window", "select count(*) over () from test");
              ("function call in FROM", "select * from lower('x')");
            ];
          ());
      Oth.test ~name:"Variable in the select list" (fun _ ->
          assert_cases
            ~expected:(of_mql_err (`Variable_err "sid"))
            [ ("select list", "select $sid from test") ];
          ());
      Oth.test ~name:"Limit set to max_limit when the query has no limit" (fun _ ->
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string "select * from test" in
          let query = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err @@ of_mql ~max_limit:5 ~schema ast in
          Oth.Assert.eq
            ~eq:CCString.equal
            ~pp:CCString.pp
            (build_str [ "select * from test limit 5" ])
            (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.to_string @@ Mql_to_pgsql.query query);
          ());
    ]

let () =
  Random.self_init ();
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ -> Oth.parallel [ test; audit_gate_tests; allow_list_tests; schema_tests ])

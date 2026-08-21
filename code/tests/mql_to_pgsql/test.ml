module Of_mql_result = struct
  type t = (Mql_to_pgsql.t, Mql_to_pgsql.of_mql_err) result [@@deriving show, eq]
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

let assert_eq sql query =
  let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query in
  let query = Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err @@ Mql_to_pgsql.of_mql ~schema ast in
  Oth.Assert.eq
    ~eq:CCString.equal
    ~pp:CCString.pp
    sql
    (Mql.Ast.to_string @@ Mql_to_pgsql.query query)

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
                "where (id = $texts[3]::uuid or name = $texts[2]) and created_at < \
                 $texts[1]::timestamptz limit 20";
              ]
          in
          assert_eq sql query;
          ());
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 2" (fun _ ->
          let query = build_str [ "select * from test inner join other_table on foo = bar" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Bad table access 3" (fun _ ->
          let query = build_str [ "with foo as (select * from other_table) select * from foo" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Unknown column 1" (fun _ ->
          let query = build_str [ "select * from test where foo is not bar" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "foo"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Ambiguous column 1" (fun _ ->
          let query = build_str [ "select * from test, test2 where id = 'bar'" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Ambiguous_column_err "id"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Func access err 1" (fun _ ->
          let query = build_str [ "select * from test, test2 where foobar(test.id)" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Func_access_err "foobar"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Cast err 1" (fun _ ->
          let query = build_str [ "select 'foo'::regclass from test" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Cast_err "regclass"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"unknown qualified column in select list is rejected" (fun _ ->
          let query = build_str [ "select test.bogus from test" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"unknown column in group by is rejected" (fun _ ->
          let query = build_str [ "select * from test group by bogus" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"unknown column in order by is rejected" (fun _ ->
          let query = build_str [ "select id from test order by bogus" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Unknown_column_err "bogus"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"known columns are still allowed" (fun _ ->
          (* The enforcement must not reject legitimate references: a qualified
             column on a real table, an aliased column referenced in order by,
             and any column drawn from a CTE (whose columns are unknown). *)
          CCList.iter
            (fun query ->
              ignore
                (Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err
                @@ Mql_to_pgsql.of_mql ~schema
                @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
                @@ Mql.Ast.of_string query))
            [
              build_str [ "select test.id from test" ];
              build_str [ "select id as other_id from test order by other_id" ];
              build_str [ "with foo as (select id from test) select bogus from foo" ];
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"aliased unknown table is a clean error" (fun _ ->
          (* Must return [`Table_access_err], not raise an uncaught
             [Not_found] (which surfaced as a 500). *)
          let query = build_str [ "select * from other_table as x" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema ast);
          ());
      Oth.test ~name:"invalid identifier in table is rejected" (fun _ ->
          let ast = Mql.Build.(select ~from:[ table "test; drop table test" ] ~cols:star ()) in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Invalid_identifier_err "test; drop table test"))
            (Mql_to_pgsql.of_mql ~schema ast);
          ());
      (* Tenant scoping relies on a query only ever reaching a table through
         its same-named scoping CTE (see sgs_ep_mql); a schema-qualified name
         would resolve past the CTE to the real relation. Both layers refuse
         it: the grammar has no [schema.table] form, and [of_mql] rejects the
         dotted identifier should one ever be built directly. *)
      Oth.test ~name:"schema-qualified table name is rejected at both layers" (fun _ ->
          (match Mql.Ast.of_string "select * from terrateam.test" with
          | Ok _ -> Oth.Assert.false_ "schema-qualified table reference parsed"
          | Error _ -> ());
          let ast = Mql.Build.(select ~from:[ table "terrateam.test" ] ~cols:star ()) in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Invalid_identifier_err "terrateam.test"))
            (Mql_to_pgsql.of_mql ~schema ast);
          ());
      Oth.test ~name:"sensitive Terraform-state columns are queryable" (fun _ ->
          (* Documents (does not flag) the deliberate exposure: instance
             attributes/sensitive_attributes/private and output values are
             queryable by any tenant member. See sgs_ep_mql.ml / the CTE
             wrapper in select_mql_page.sql. *)
          CCList.iter
            (fun query ->
              ignore
                (Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err
                @@ Mql_to_pgsql.of_mql ~schema
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
          let t =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err @@ Mql_to_pgsql.of_mql ~schema ast
          in
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
          let t =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err @@ Mql_to_pgsql.of_mql ~schema ast
          in
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
          let t =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err @@ Mql_to_pgsql.of_mql ~schema ast
          in
          Oth.Assert.eq
            ~eq:(CCResult.equal ~err:Mql_to_pgsql.equal_pages_err (CCOption.equal Ps.equal))
            ~pp:(CCResult.pp' (CCOption.pp Ps.pp) Mql_to_pgsql.pp_pages_err)
            (Error
               (`Order_by_col_not_identifier_err
                  Mql_ast.(
                    Add (Index (Identifier "$bigints", Int 2), Index (Identifier "$bigints", Int 1)))))
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
          Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp sql (Mql.Ast.to_string ast);
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
                 $bigints[6]), graph_roots.c from cnt_s inner join cnt_r on true inner join \
                 graph_roots on true left join most_deployed_mod on true left join largest_mod on \
                 true left join top_rt on true inner join cnt_m on true inner join cnt_p on true \
                 inner join edges on true inner join cnt_i on true limit 20";
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
                 join states on providers.state_id = states.id inner join instances on \
                 instances.state_id = resources.state_id and instances.resource_address = \
                 resources.address inner join resources on resources.state_id = providers.state_id \
                 and resources.provider = providers.name where states.tenant_id = $texts[1]::uuid \
                 and states.deleted_at is null group by providers.name order by instances desc \
                 limit 20";
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
                 instances.state_id = ts.id left join all_deps on all_deps.address = \
                 instances.address left join resources on resources.state_id = instances.state_id \
                 and resources.address = instances.resource_address where resources.address is \
                 null and all_deps.address is null)";
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad table in EXISTS" (fun _ ->
          let query = build_str [ "select * from test where exists (select * from other_table)" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Subquery denial: bad function in subquery" (fun _ ->
          let query =
            build_str [ "select * from test where exists (select foobar(state_id) from resources)" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Func_access_err "foobar"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad table in right branch" (fun _ ->
          let query = build_str [ "select name from states union select name from other_table" ] in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad table in parenthesized branch" (fun _ ->
          let query =
            build_str [ "(select name from other_table) union select name from states" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Table_access_err "other_table"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad function in a branch" (fun _ ->
          let query =
            build_str [ "select foobar(name) from states union select name from resources" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Func_access_err "foobar"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
          ());
      Oth.test ~name:"Union denial: bad cast in a branch" (fun _ ->
          let query =
            build_str [ "select name::regclass from states union select name from resources" ]
          in
          Oth.Assert.eq
            ~pp:Of_mql_result.pp
            ~eq:Of_mql_result.equal
            (Error (`Cast_err "regclass"))
            (Mql_to_pgsql.of_mql ~schema
            @@ Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string query);
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
          let t =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err @@ Mql_to_pgsql.of_mql ~schema ast
          in
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
          let _ =
            Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_of_mql_err @@ Mql_to_pgsql.of_mql ~schema ast
          in
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

module B = Mql.Build

(* The rendered SQL must reparse, because the MQL endpoint parses the query
   string it receives with the same [Mql.Ast.of_string]. *)
let assert_renders sql ast =
  let rendered = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err (Mql.Ast.to_string ast) in
  Oth.Assert.Eq.string ~expected:sql ~actual:rendered;
  Oth.Assert.true_ (CCResult.is_ok (Mql.Ast.of_string rendered))

(* A schema statement parses only behind the DDL feature, which [Mql_sql.read] always gives it. *)
let assert_renders_ddl sql ast =
  let rendered = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err (Mql.Ast.to_string ast) in
  Oth.Assert.Eq.string ~expected:sql ~actual:rendered;
  Oth.Assert.true_ (CCResult.is_ok (Mql.Ast.of_string ~features:Mql.Feature.all rendered))

let test =
  Oth.parallel
    [
      Oth.test ~name:"count_star" (fun _ ->
          assert_renders
            "select count(*) from foo"
            (B.select ~from:[ B.table "foo" ] ~cols:(B.columns [ B.col B.count_star ]) ());
          ());
      Oth.test ~name:"in_query" (fun _ ->
          assert_renders
            "select id from foo where id in (select id from bar)"
            (B.select
               ~from:[ B.table "foo" ]
               ~cols:(B.columns [ B.col (B.id "id") ])
               ~where:
                 (B.in_query
                    (B.id "id")
                    (B.select ~from:[ B.table "bar" ] ~cols:(B.columns [ B.col (B.id "id") ]) ()))
               ());
          ());
      Oth.test ~name:"field_and_func" (fun _ ->
          assert_renders
            "select count(f.id, f.name) from foo as f"
            (B.select
               ~from:[ B.table ~alias:"f" "foo" ]
               ~cols:(B.columns [ B.col (B.func "count" [ B.field "f" "id"; B.field "f" "name" ]) ])
               ());
          ());
      Oth.test ~name:"union_all" (fun _ ->
          assert_renders
            "select a from foo union all select b from bar"
            (B.union_all
               (B.select ~from:[ B.table "foo" ] ~cols:(B.columns [ B.col (B.id "a") ]) ())
               (B.select ~from:[ B.table "bar" ] ~cols:(B.columns [ B.col (B.id "b") ]) ()));
          ());
      Oth.test ~name:"union_all chained left with limit" (fun _ ->
          assert_renders
            "select a from foo union all select b from bar union all select c from baz limit 10"
            (Mql.Ast.set_limit
               10
               (B.union_all
                  (B.union_all
                     (B.select ~from:[ B.table "foo" ] ~cols:(B.columns [ B.col (B.id "a") ]) ())
                     (B.select ~from:[ B.table "bar" ] ~cols:(B.columns [ B.col (B.id "b") ]) ()))
                  (B.select ~from:[ B.table "baz" ] ~cols:(B.columns [ B.col (B.id "c") ]) ())));
          ());
      Oth.test ~name:"drop_table" (fun _ ->
          assert_renders_ddl "drop table if exists foo" (B.drop_table ~if_exists:true "foo");
          assert_renders_ddl "drop table foo" (B.drop_table "foo");
          ());
      Oth.test ~name:"analyze_table" (fun _ ->
          assert_renders_ddl "analyze foo" (B.analyze_table "foo");
          ());
      Oth.test ~name:"create_temp_table_as" (fun _ ->
          assert_renders_ddl
            "create temp table foo as select a from bar"
            (B.create_temp_table_as
               "foo"
               (B.select ~from:[ B.table "bar" ] ~cols:(B.columns [ B.col (B.id "a") ]) ()));
          ());
      Oth.test ~name:"create_temp_table_as on commit drop" (fun _ ->
          assert_renders_ddl
            "create temp table foo on commit drop as select a from bar"
            (B.create_temp_table_as
               ~on_commit_drop:true
               "foo"
               (B.select ~from:[ B.table "bar" ] ~cols:(B.columns [ B.col (B.id "a") ]) ()));
          ());
      Oth.test ~name:"lock_table" (fun _ ->
          assert_renders_ddl "lock table foo in access exclusive mode" (B.lock_table "foo");
          ());
      Oth.test ~name:"lock_table exclusive" (fun _ ->
          assert_renders_ddl
            "lock table foo in exclusive mode"
            (B.lock_table ~mode:Mql_ast.Lock_mode_exclusive "foo");
          ());
      Oth.test ~name:"create_table_partition_of" (fun _ ->
          assert_renders_ddl
            "create table foo partition of bar for values from ('2026-01-05') to('2026-01-12')"
            (B.create_table_partition_of
               ~parent:"bar"
               ~bound:(B.range_bound ~from:"2026-01-05" ~to_:"2026-01-12")
               "foo");
          ());
      Oth.test ~name:"delete_where" (fun _ ->
          assert_renders_ddl
            "delete from foo where created_at >= '2026-01-05'"
            (B.delete_where ~where:(B.gte (B.id "created_at") (B.string "2026-01-05")) "foo");
          ());
      Oth.test ~name:"insert_select" (fun _ ->
          assert_renders_ddl
            "insert into foo select a from bar"
            (B.insert_select
               ~query:(B.select ~from:[ B.table "bar" ] ~cols:(B.columns [ B.col (B.id "a") ]) ())
               "foo");
          ());
      Oth.test ~name:"create_table_partition_of_refuses_partition_clause" (fun _ ->
          let ident name = { Mql_ast.name; quoted = false } in
          let table name = { Mql_ast.qualifier = None; base = ident name } in
          let tree =
            Mql_ast.Create_table
              {
                if_not_exists = false;
                temp = false;
                name = table "foo";
                body =
                  Mql_ast.Table_partition_of { parent = table "bar"; bound = Mql_ast.Pb_default };
                on_commit_drop = false;
                partition =
                  Some
                    {
                      Mql_ast.strategy = Mql_ast.Ps_range;
                      key = [ Mql_ast.Identifier (ident "created_at") ];
                    };
              }
          in
          match Mql.Ast.to_string tree with
          | Error (`Error (_, _, msg)) ->
              Oth.Assert.Eq.string ~expected:"a partition takes no partition clause" ~actual:msg
          | Ok rendered ->
              Oth.Assert.true_
                ~fail_msg:
                  (Printf.sprintf "a partition of a table rendered a partition clause: %s" rendered)
                false);
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

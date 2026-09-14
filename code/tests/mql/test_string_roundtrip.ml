module String_result = struct
  type t = (string, Mql.Ast.err) result [@@deriving show, eq]
end

let build_str = CCFun.(CCList.map CCString.trim %> CCString.concat " ")

let roundtrip sql =
  let open CCResult.Infix in
  Mql.Ast.of_string sql >>= fun ast -> Ok (Mql.Ast.to_string ast)

let assert_roundtrip sql =
  Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (roundtrip sql)

let test =
  Oth.parallel
    [
      Oth.test ~name:"Roundtrip 1" (fun _ ->
          let sql = build_str [ "select * from foo" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 2" (fun _ ->
          let sql =
            build_str
              [
                "select";
                "tx_id as tx_id,";
                "c.state_id as state_id,";
                "jsonb_build_object('config_addr', c.config_addr,";
                "'object_addr', c.object_addr) as data";
                "from check_entries as c";
                "inner join tx_states as txs";
                "on txs.state_id = c.state_id";
                "left join transaction_logs as txl";
                "on txl.tx_id = tx_id";
                "and txl.action = 'state_set'";
                "and txl.object_type = 'check_result_entry'";
                "and c.state_id = txl.state_id";
                "and c.config_addr = (txl.data->>'config_addr')::text";
                "and c.object_addr = (txl.data->>'object_addr')::text";
                "where txl.id is null";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 3" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens where user_id = user_id";
                "order by name";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 4" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens, users where user_id = user_id";
                "order by name";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 5" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens, users where user_id = user_id";
                "order by name, bar";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 6" (fun _ ->
          let sql = build_str [ "select * from foo"; "where c = 'foo\"bar'" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 7" (fun _ ->
          let sql = build_str [ "select * from foo"; "where c = 'foo''bar'" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 8" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens, users where user_id = user_id";
                "order by name asc, bar";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 9" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens, users where user_id = user_id";
                "order by name asc, bar desc";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 10" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens, users where user_id = user_id";
                "group by kind";
                "order by name asc, bar desc";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 11" (fun _ ->
          let sql =
            build_str
              [
                "select id, name, capabilities";
                "from access_tokens, users where user_id = user_id";
                "group by kind, name";
                "order by name asc, bar desc";
                "limit 100";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 12" (fun _ ->
          let sql = build_str [ "select count(*)"; "from foo" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 12" (fun _ ->
          let sql = build_str [ "select count(*)"; "from bar" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 13" (fun _ ->
          let sql = build_str [ "select * from bar"; "where foo[2] = '2'" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 14" (fun _ ->
          let sql = build_str [ "select * from bar"; "where foo in ('one', 'two', 'three')" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip single-element IN" (fun _ ->
          let sql = build_str [ "select * from bar"; "where foo in ('one')" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 15" (fun _ ->
          let sql = build_str [ "select * from bar"; "where foo is distinct from bar" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 16" (fun _ ->
          let sql = build_str [ "select * from bar"; "where foo is not distinct from bar" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 17" (fun _ ->
          let sql = build_str [ "select * from bar"; "group by baz having count(*) > 5" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 18" (fun _ ->
          let sql = build_str [ "with foo as (select * from bar)"; "select * from foo" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 19" (fun _ ->
          let sql =
            build_str
              [
                "with foo as (select * from bar),";
                "bar as (select * from foo)";
                "select * from bar";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip 20" (fun _ ->
          let sql =
            build_str
              [
                "with bar as (select * from foo),";
                "foo as (select * from bar)";
                "select * from bar";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip MATERIALIZED 1" (fun _ ->
          let sql =
            build_str [ "with foo as materialized (select * from bar)"; "select * from foo" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip MATERIALIZED 2" (fun _ ->
          let sql =
            build_str
              [
                "with foo as materialized (select * from bar),";
                "baz as (select * from qux)";
                "select * from foo";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip subquery IN 1" (fun _ ->
          let sql = build_str [ "select * from a where x in (select id from b)" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip subquery EXISTS 1" (fun _ ->
          let sql = build_str [ "select * from a where exists (select 1 from b)" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip subquery NOT EXISTS 1" (fun _ ->
          let sql = build_str [ "select * from a where not exists (select 1 from b)" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip subquery correlated 1" (fun _ ->
          let sql =
            build_str [ "select * from a where exists (select 1 from b where b.x = a.x)" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip subquery with WITH 1" (fun _ ->
          let sql =
            build_str
              [ "select * from a"; "where x in (with c as (select id from b) select id from c)" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION 1" (fun _ ->
          let sql = build_str [ "select a from t1 union select b from t2" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION ALL 1" (fun _ ->
          let sql = build_str [ "select a from t1 union all select b from t2" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION order/limit" (fun _ ->
          let sql = build_str [ "select a from t1 union select b from t2 order by 1 limit 10" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION chained" (fun _ ->
          let sql =
            build_str [ "select a from t1 union select b from t2 union all select c from t3" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION paren branches" (fun _ ->
          let sql =
            build_str [ "(select a from t1 order by a limit 5) union (select b from t2)" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION in subquery" (fun _ ->
          let sql =
            build_str [ "select * from a where id in (select id from b union select id from c)" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNION under WITH" (fun _ ->
          let sql =
            build_str [ "with c as (select id from t)"; "select id from c union select id from t2" ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNNEST 1" (fun _ ->
          let sql = build_str [ "select dep from foo, unnest(bar) as dep" ] in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip UNNEST 2" (fun _ ->
          let sql =
            build_str
              [
                "select dep from foo, unnest(dependencies) as dep";
                "inner join ts on foo.id = ts.id";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip three joins keep source order" (fun _ ->
          (* Each join's ON references the alias of the join before it. *)
          let sql =
            build_str
              [
                "select a.id from t1 as a";
                "inner join t2 as b on b.a_id = a.id";
                "left join t3 as c on c.b_id = b.id";
                "left join t4 as d on d.c_id = c.id";
              ]
          in
          assert_roundtrip sql;
          ());
      Oth.test ~name:"Roundtrip LIKE" (fun _ ->
          assert_roundtrip @@ build_str [ "select * from foo where bar like 'baz%'" ];
          ());
      Oth.test ~name:"Roundtrip NOT LIKE" (fun _ ->
          assert_roundtrip @@ build_str [ "select * from foo where bar not like 'baz%'" ];
          ());
      Oth.test ~name:"Roundtrip ILIKE" (fun _ ->
          assert_roundtrip @@ build_str [ "select * from foo where bar ilike 'baz%'" ];
          ());
      Oth.test ~name:"Roundtrip NOT ILIKE" (fun _ ->
          assert_roundtrip @@ build_str [ "select * from foo where bar not ilike 'baz%'" ];
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

module String_result = struct
  type t = (string, Mql.Ast.err) result [@@deriving show, eq]
end

let build_str = CCFun.(CCList.map CCString.trim %> CCString.concat " ")

let roundtrip ?variables sql =
  let open CCResult.Infix in
  Mql.Ast.of_string ?variables sql >>= fun ast -> Mql.Ast.to_string ast

let assert_roundtrip ?variables sql =
  Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (roundtrip ?variables sql)

(* The lexer signals failure by exception, so what matters is that [of_string]
   returns an [Error] rather than raising -- the endpoint turns it into a 400. *)
let assert_parse_error sql =
  ignore
    (Oth.Assert.error
       ~fail_msg:(Printf.sprintf "expected %S to be rejected" sql)
       (Mql.Ast.of_string sql)
      : Mql.Ast.err)

(* A comment is discarded by the lexer, so the query it decorates renders as if
   the comment were never there.  [expected] is that bare rendering. *)
let assert_comment_stripped ~expected sql =
  Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok expected) (roundtrip sql)

let roundtrip_multi ?variables sql =
  let open CCResult.Infix in
  Mql.Ast.of_string_multi ?variables sql >>= fun asts -> Mql.Ast.to_string_multi asts

let assert_roundtrip_multi ?variables sql =
  Oth.Assert.eq
    ~eq:String_result.equal
    ~pp:String_result.pp
    (Ok sql)
    (roundtrip_multi ?variables sql)

(* [;] is a statement boundary decided by the parser, so assert how many queries
   came back and not only that the whole thing re-renders. *)
let assert_query_count ~expected sql =
  let asts = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string_multi sql in
  Oth.Assert.List.length ~expected asts

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
      (* The order of the terms is the order of the keyset of a page, thus the printer keeps it. *)
      Oth.test ~name:"Roundtrip order by three terms" (fun _ ->
          let sql =
            build_str
              [ "select source, version, id"; "from tf_module_hcl"; "order by source, version, id" ]
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
      Oth.test ~name:"Roundtrip variables" (fun _ ->
          (* One per position a prepared statement parameter is allowed in. *)
          CCList.iter
            (fun sql -> assert_roundtrip ~variables:true @@ build_str [ sql ])
            [
              "select * from resources where state_id = $sid";
              "select $x as c from resources";
              "select * from resources where type in ($a, $b)";
              "select * from resources where a = $x::uuid";
              "select * from resources order by name limit $n";
              "select * from resources where a = $x and b = $x";
              (* The shape [Mql_to_pgsql] itself emits. *)
              "select $texts[1] from resources";
            ];
          ());
      Oth.test ~name:"Variables rejected by default" (fun _ ->
          CCList.iter
            (fun sql -> assert_parse_error @@ build_str [ sql ])
            [
              "select * from resources where state_id = $sid";
              "select $x as c from resources";
              "select * from resources where type in ($a, $b)";
              "select * from resources where a = $x::uuid";
              "select * from resources order by name limit $n";
              "select $texts[1] from resources";
            ];
          ());
      Oth.test ~name:"Unexpected character is an error, not an exception" (fun _ ->
          (* The lexer signals by exception; [of_string] must convert it. *)
          CCList.iter
            assert_parse_error
            [ "select * from foo where a = ?"; "select * from foo &&& bar"; "select $ from foo" ];
          ());
      Oth.test ~name:"Roundtrip dollar in string literal" (fun _ ->
          (* Not a variable: it is inside a string literal, so it needs no gate. *)
          assert_roundtrip @@ build_str [ "select * from resources where name = '$sid'" ];
          ());
      Oth.test ~name:"Roundtrip multiple queries" (fun _ ->
          assert_roundtrip_multi @@ build_str [ "select * from foo; select baz from bar" ];
          assert_roundtrip_multi
          @@ build_str [ "select * from foo; select baz from bar; select a from c" ];
          assert_roundtrip_multi
          @@ build_str [ "select * from foo limit 10; select * from bar limit 20" ];
          ());
      (* The boundary is the parser's.  Each of these is a case a delimiter split
         gets wrong, so assert the count as well as the rendering. *)
      Oth.test ~name:"Multi query boundary: WITH" (fun _ ->
          let sql =
            build_str [ "with a as (select * from foo) select * from a; select * from bar" ]
          in
          assert_query_count ~expected:2 sql;
          assert_roundtrip_multi sql;
          ());
      Oth.test ~name:"Multi query boundary: UNION" (fun _ ->
          let sql = build_str [ "select a from x union select b from y; select c from z" ] in
          assert_query_count ~expected:2 sql;
          assert_roundtrip_multi sql;
          ());
      Oth.test ~name:"Multi query boundary: subquery" (fun _ ->
          let sql =
            build_str [ "select * from foo where id in (select id from bar); select * from baz" ]
          in
          assert_query_count ~expected:2 sql;
          assert_roundtrip_multi sql;
          ());
      Oth.test ~name:"Multi query boundary: semicolon in a string literal" (fun _ ->
          (* One query, not two -- the [;] is inside a literal, which only a real
             lexer can tell. *)
          let sql = build_str [ "select * from foo where name = 'a; b'" ] in
          assert_query_count ~expected:1 sql;
          assert_roundtrip_multi sql;
          ());
      Oth.test ~name:"Multi query trailing semicolon normalizes" (fun _ ->
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Ok (build_str [ "select * from foo; select baz from bar" ]))
            (roundtrip_multi @@ build_str [ "select * from foo; select baz from bar;" ]);
          ());
      Oth.test ~name:"Single query through the multi entry point" (fun _ ->
          let sql = build_str [ "select * from foo" ] in
          assert_query_count ~expected:1 sql;
          assert_roundtrip_multi sql;
          (* [to_string_multi [ q ]] agrees with [to_string q]. *)
          let ast = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string sql in
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Mql.Ast.to_string ast)
            (Mql.Ast.to_string_multi [ ast ]);
          ());
      Oth.test ~name:"of_string accepts one trailing semicolon" (fun _ ->
          (* Accepted on input, never rendered back -- [to_string] output is
             substituted inside [q as ( ... )], where a trailing [;] would not
             parse. *)
          let ast =
            Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
            @@ Mql.Ast.of_string
            @@ build_str [ "select * from foo;" ]
          in
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Ok (build_str [ "select * from foo" ]))
            (Mql.Ast.to_string ast);
          ());
      Oth.test ~name:"Line comments are stripped" (fun _ ->
          let expected = "select a from foo" in
          assert_comment_stripped ~expected "select a from foo -- trailing";
          assert_comment_stripped ~expected "select a from foo --no space before text";
          assert_comment_stripped ~expected "-- leading\nselect a from foo";
          assert_comment_stripped ~expected "select a\n-- in the middle\nfrom foo";
          (* Runs to end of line, not end of input. *)
          assert_comment_stripped
            ~expected:"select a from foo where b = 1"
            "select a from foo -- comment\nwhere b = 1";
          ());
      Oth.test ~name:"Block comments are stripped" (fun _ ->
          let expected = "select a from foo" in
          assert_comment_stripped ~expected "select a /* mid */ from foo";
          assert_comment_stripped ~expected "/* leading */ select a from foo";
          assert_comment_stripped ~expected "select a from foo /* trailing */";
          assert_comment_stripped ~expected "select a from /* multi\nline */ foo";
          ());
      Oth.test ~name:"Block comments nest" (fun _ ->
          (* The first [*/] closes only the inner comment, as in PostgreSQL. *)
          assert_comment_stripped
            ~expected:"select a from foo"
            "select a /* outer /* inner */ still outer */ from foo";
          assert_comment_stripped
            ~expected:"select a from foo"
            "select a /* one /* two /* three */ two */ one */ from foo";
          ());
      Oth.test ~name:"Unterminated block comment is an error" (fun _ ->
          (* Not an implicit close at eof: swallowing the rest of a query would
             turn a typo into a different query. *)
          assert_parse_error "select a from foo /* never closed";
          (* The inner comment's [*/] does not close the outer one. *)
          assert_parse_error "select a from foo /* outer /* inner */";
          ());
      Oth.test ~name:"Comment markers inside a string literal are literal" (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select * from foo where a = '-- not a comment'";
              "select * from foo where a = '/* not a comment */'";
              "select * from foo where a = 'b -- c'";
            ];
          ());
      Oth.test ~name:"Comments compose with multi query and variables" (fun _ ->
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Ok "select a from foo; select b from bar")
            (roundtrip_multi "select a from foo; -- between\nselect b from bar");
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Ok "select * from a where x = $p")
            (roundtrip ~variables:true "select * from a where x = $p /* the param */");
          ());
      (* [AS] is optional in SQL.  The AST records only that there IS an alias,
         not which spelling the SQL used, so the bare form normalizes to the [AS]
         form -- assert the normalization rather than a byte-exact round trip. *)
      Oth.test ~name:"Bare table alias normalizes to AS" (fun _ ->
          assert_comment_stripped ~expected:"select a from foo as f" "select a from foo f";
          assert_comment_stripped
            ~expected:"select a from foo as f, bar as b"
            "select a from foo f, bar b";
          assert_comment_stripped
            ~expected:"select a from foo as f inner join bar as b on f.id = b.id"
            "select a from foo f inner join bar b on f.id = b.id";
          ());
      Oth.test ~name:"Bare column alias normalizes to AS" (fun _ ->
          assert_comment_stripped ~expected:"select a as b from foo" "select a b from foo";
          assert_comment_stripped
            ~expected:"select a as x, b as y from foo"
            "select a x, b y from foo";
          assert_comment_stripped
            ~expected:"select count(*) as n from foo"
            "select count(*) n from foo";
          ());
      Oth.test ~name:"Aliases without AS still round-trip once normalized" (fun _ ->
          (* The AS form is the canonical spelling, so it is byte-exact. *)
          assert_roundtrip @@ build_str [ "select a as b from foo as f" ];
          ());
      Oth.test ~name:"Omitting the alias is still an option" (fun _ ->
          (* Guard against the new production swallowing the next clause. *)
          assert_roundtrip @@ build_str [ "select a from foo" ];
          assert_roundtrip @@ build_str [ "select a from foo where a = 1" ];
          assert_roundtrip @@ build_str [ "select a from foo order by a limit 1" ];
          assert_roundtrip @@ build_str [ "select a from foo group by a" ];
          ());
      Oth.test ~name:"SELECT without FROM" (fun _ ->
          assert_roundtrip @@ build_str [ "select 1" ];
          assert_roundtrip @@ build_str [ "select now()" ];
          assert_roundtrip @@ build_str [ "select 1 as one" ];
          (* An empty FROM must not swallow the clauses that follow. *)
          assert_roundtrip @@ build_str [ "select a from foo" ];
          assert_roundtrip @@ build_str [ "select a from foo where a = 1" ];
          ());
      (* A quoted identifier keeps its quotes on the way out.  This is the whole
         reason the AST carries the flag: unquoted, PostgreSQL folds case, so
         ["Foo"] and [Foo] are different names -- and a quoted keyword would not
         parse back at all. *)
      Oth.test ~name:"Quoted identifiers round-trip" (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              {|select "a" from foo|};
              {|select a from "foo"|};
              {|select "Foo" from bar|};
              {|select a from foo as "F"|};
              {|select a as "My Col" from foo|};
              {|select "t"."a" from foo as "t"|};
              (* A quoted keyword is a legal name; bare it would be a token. *)
              {|select "select" from "from"|};
              {|select a from foo where "b" = 1|};
            ];
          ());
      Oth.test ~name:"Quoted and bare identifiers stay distinct" (fun _ ->
          (* Both spell the same name, so both must survive as written -- if the
             flag were dropped, one of these two would render as the other. *)
          assert_roundtrip @@ build_str [ {|select "a" from foo|} ];
          assert_roundtrip @@ build_str [ "select a from foo" ];
          ());
      Oth.test ~name:"Doubled quote inside a quoted identifier" (fun _ ->
          (* [""] is an escaped quote, as [''] is in a string literal.  The
             printer must re-double it or the output would not re-parse. *)
          assert_roundtrip @@ build_str [ {|select "a""b" from foo|} ];
          ());
      Oth.test ~name:"Unterminated quoted identifier is an error" (fun _ ->
          assert_parse_error {|select "a from foo|};
          ());
      Oth.test ~name:"A quote inside a string literal is not an identifier" (fun _ ->
          assert_roundtrip @@ build_str [ {|select a from foo where b = 'has " quote'|} ];
          ());
      Oth.test ~name:"DISTINCT round-trips" (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select distinct a from foo";
              "select distinct a, b from foo";
              "select distinct * from foo";
              "select distinct a from foo where b = 1 order by a limit 10";
              "select distinct on (a) a, b from foo";
              "select distinct on (a, b) a, b from foo";
              (* [is distinct from] must still lex as one token, not as a bare
                 DISTINCT -- longest match is what keeps these apart. *)
              "select a from foo where a is distinct from b";
              "select a from foo where a is not distinct from b";
            ];
          ());
      Oth.test ~name:"CASE round-trips" (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select case when a then 1 else 2 end from foo";
              "select case when a then 1 end from foo";
              "select case when a then 1 when b then 2 else 3 end from foo";
              (* The [CASE operand WHEN ...] form. *)
              "select case a when 1 then 'x' else 'y' end from foo";
              "select a from foo where case when a then b else c end = 1";
            ];
          ());
      Oth.test ~name:"NOT IN round-trips" (fun _ ->
          assert_roundtrip @@ build_str [ "select * from foo where a not in (1, 2)" ];
          assert_roundtrip @@ build_str [ "select * from foo where a not in ('x')" ];
          (* [IN] must be unaffected. *)
          assert_roundtrip @@ build_str [ "select * from foo where a in (1, 2)" ];
          ());
      Oth.test ~name:"INTERVAL, regex and #> round-trip" (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select * from foo where a > interval '1 day'";
              "select * from foo where a ~ 'x'";
              "select * from foo where a !~ 'x'";
              "select a #> '{b}' from foo";
              (* [#>>] must still lex as its own token. *)
              "select a #>> '{b}' from foo";
            ];
          ());
      Oth.test ~name:"AT TIME ZONE round-trips" (fun _ ->
          assert_roundtrip @@ build_str [ "select a at time zone 'utc' from foo" ];
          assert_roundtrip @@ build_str [ "select * from foo where a at time zone 'utc' > b" ];
          (* Lexed as one token, so [time] and [zone] are NOT reserved and stay
             usable as ordinary column names. *)
          assert_roundtrip @@ build_str [ "select time, zone from foo" ];
          assert_roundtrip @@ build_str [ "select a from foo where time = 1 and zone = 2" ];
          (* Case-insensitive and whitespace-tolerant, like the SQL it mirrors. *)
          assert_comment_stripped
            ~expected:"select a at time zone 'utc' from foo"
            "select a AT  TIME   ZONE 'utc' from foo";
          ());
      Oth.test ~name:"Array casts round-trip" (fun _ ->
          assert_roundtrip @@ build_str [ "select a::text[] from foo" ];
          assert_roundtrip @@ build_str [ "select coalesce(a, '{}'::text[]) from foo" ];
          assert_roundtrip @@ build_str [ "select a::uuid[] from foo" ];
          (* A subscript is still a subscript -- [[]] and [[i]] must not be
             confused, which is why [[]] is lexed as one token. *)
          assert_roundtrip @@ build_str [ "select a[1] from foo" ];
          assert_roundtrip @@ build_str [ "select a::text[] from foo where b[2] = '2'" ];
          (* PostgreSQL takes a subscript only after a name, a [$name] parameter,
             another subscript, or a parenthesized expression.  The MQL grammar
             also reads the plain form, thus the writer has to hold the
             parentheses that PostgreSQL needs: [array_agg(x)[1]] is a syntax
             error to PostgreSQL, and it stopped the subgraph queries. *)
          assert_roundtrip @@ build_str [ "select (array_agg(a))[1] from foo" ];
          assert_roundtrip @@ build_str [ "select (data->'x')[1] from foo" ];
          assert_roundtrip @@ build_str [ "select (array[1, 2])[1] from foo" ];
          assert_roundtrip @@ build_str [ "select (array_agg(a))[1 : 2] from foo" ];
          (* A name, a qualified name, a parameter and a chain of subscripts
             need no parentheses, thus the writer must not add any. *)
          assert_roundtrip @@ build_str [ "select a[1][2] from foo" ];
          assert_roundtrip @@ build_str [ "select f.a[1] from foo as f" ];
          assert_roundtrip ~variables:true @@ build_str [ "select $texts[1] from foo" ];
          (* PostgreSQL binds [::] tighter than [#>] and [#>>], thus it reads
             [a #>> '{}'::boolean] as [a #>> ('{}'::boolean)].  This grammar takes the right side
             of those two as a string, thus it reads the same text as the cast of the whole and
             the writer has to hold the parentheses.  This stopped
             [delete_tx_prune_orphan.sql], where PostgreSQL answered
             "invalid input syntax for type boolean: {}". *)
          assert_roundtrip @@ build_str [ "select (a #>> '{}')::boolean from foo" ];
          assert_roundtrip @@ build_str [ "select (a #> '{}')::jsonb from foo" ];
          (* The other JSON operators take an expression on the right, thus this grammar and
             PostgreSQL agree and the writer must add no parentheses of its own. *)
          assert_roundtrip @@ build_str [ "select (a->'x')::boolean from foo" ];
          assert_roundtrip @@ build_str [ "select (a->>'x')::boolean from foo" ];
          assert_roundtrip @@ build_str [ "select a #>> '{}' from foo" ];
          ());
      Oth.test ~name:"Query clauses round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              (* A CTE can name itself. *)
              "with recursive r as (select 1) select * from r";
              (* Tell PostgreSQL to put the body of the CTE into the query that
                 reads it, or to keep it apart. *)
              "with a as materialized (select 1) select * from a";
              "with a as not materialized (select 1) select * from a";
              (* Where the empty values go. *)
              "select a from foo order by a desc nulls last";
              "select a from foo order by a nulls first";
              "select a from foo order by a asc nulls last, b desc nulls first";
              (* The quantity of rows to omit. *)
              "select a from foo limit 10 offset 20";
              "select a from foo offset 20";
              "select a from foo order by a limit 10 offset 20";
              (* The three set operations. *)
              "select a from foo union select b from bar";
              "select a from foo union all select b from bar";
              "select a from foo except select b from bar";
              "select a from foo except all select b from bar";
              "select a from foo intersect select b from bar";
            ];
          ());
      Oth.test ~name:"Data-modifying statements round-trip" ~tags:[ "mql" ] (fun _ ->
          let features = [ Mql.Feature.Data_modifying ] in
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let sql = build_str [ sql ] in
              Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql))
            [
              (* What PostgreSQL matches the new row against. *)
              "insert into foo(a) values (1) on conflict on constraint ck do nothing";
              "insert into foo(a) values (1) on conflict (a) where b do nothing";
              "insert into foo(a) values (1) on conflict (repo, (params->>'branch')) do nothing";
              (* Set more than one column from one row of values. *)
              "insert into foo(a) values (1) on conflict (a) do update set (a, b) = (1, 2)";
              "update foo set (a, b) = (1, 2)";
              "update foo set a = 1, (b, c) = (2, 3)";
              (* The rows to read while deleting. *)
              "delete from foo using bar where foo.a = bar.a";
              "delete from foo using bar, baz where foo.a = bar.a";
              (* The row that PostgreSQL tried to write. *)
              "insert into foo(a) values (1) on conflict (a) do update set a = excluded.a";
            ];
          ());
      Oth.test ~name:"GROUPING SETS and named arguments round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              (* A set can be empty, and an empty set is not an expression. *)
              "select a from foo group by grouping sets ((a), ())";
              "select a from foo group by grouping sets ((a), (b), ())";
              "select a from foo group by grouping sets ((a)) having a > 1";
              (* A call can name its arguments. *)
              "select make_interval(secs => 1) from foo";
              "select f(a, b => 1) from foo";
            ];
          ());
      Oth.test ~name:"Table and index statements round-trip" ~tags:[ "mql" ] (fun _ ->
          let features = [ Mql.Feature.Ddl ] in
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let sql = build_str [ sql ] in
              Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql))
            [
              (* A temporary table that PostgreSQL deletes at the end of the
                 transaction. *)
              (* The printer writes no blank before a column list. *)
              "create temp table foo(a integer) on commit drop";
              "create temp table foo on commit drop as select a from bar";
              "create temp table if not exists foo on commit drop as select a from bar";
              (* The value is computed from the row, or PostgreSQL gives it. *)
              "create table foo(a integer, b text generated always as (a) stored)";
              "create table foo(a bigint generated always as identity primary key)";
              (* Columns the index carries but does not order on, and which
                 operator class it uses. *)
              "create index i on foo(a, b) include (c, d)";
              "create index i on foo using gin(a jsonb_path_ops)";
              "create index i on foo using gin(a, b jsonb_path_ops)";
              "create unique index concurrently if not exists i on foo(a) include (b)";
              (* The settings of the table, and how to make an old value into a
                 new one. *)
              "alter table foo set (autovacuum_enabled = true, fillfactor = 90)";
              "alter table foo alter column c type jsonb using c::jsonb";
              (* Change an index that is already present to a constraint. *)
              "alter table foo add primary key using index i";
              "alter table foo add constraint ck unique using index i";
              (* A table that is in another database. *)
              "create foreign table s.foo(a text, b uuid) server srv options (schema_name 'x')";
            ];
          ());
      Oth.test ~name:"The remaining schema statements round-trip" ~tags:[ "mql" ] (fun _ ->
          let features = [ Mql.Feature.Ddl ] in
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let sql = build_str [ sql ] in
              Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql))
            [
              (* The word is a keyword of this grammar for a table and for a
                 column. *)
              "comment on table foo is 'a note'";
              "comment on column foo.c is 'a note'";
              "comment on index foo is 'a note'";
              (* An argument list makes one function different from another function with
                 the same name. *)
              "drop function f()";
              "drop function f";
              (* The trigger operates only for these columns. *)
              "create trigger g after update of a on foo for each row execute function f()";
              "create trigger g after insert or update of a, b on foo for each row execute \
               function f()";
              (* The operation that a grant permits to the role. *)
              "grant select on foo to r";
              "grant select (a, b) on foo to r";
              "revoke select on foo from r";
              (* The shapes this repository writes at first boot. *)
              "create role r login password 'x'";
              "create role r";
              "create database d";
              (* Do not read the rows that are already there. *)
              "alter table foo add constraint ck check(a > 0) not valid";
              (* A drop that does not hold the table. *)
              "drop index concurrently i";
              "drop table concurrently if exists foo";
            ];
          ());
      Oth.test ~name:"ANALYZE takes a list of tables" ~tags:[ "mql" ] (fun _ ->
          let features = [ Mql.Feature.Ddl ] in
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let sql = build_str [ sql ] in
              Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql))
            [ "analyze foo"; "analyze foo, bar, baz"; "analyze" ];
          ());
      Oth.test ~name:"LOCK TABLE round-trips" ~tags:[ "mql" ] (fun _ ->
          let features = [ Mql.Feature.Ddl ] in
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let sql = build_str [ sql ] in
              Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql))
            [
              "lock table users in exclusive mode";
              "lock table users in access share mode";
              "lock table users in row share mode";
              "lock table users in row exclusive mode";
              "lock table users in share mode";
              "lock table users in share row exclusive mode";
              "lock table users in access exclusive mode";
              "lock table s.users in exclusive mode";
              (* No [in ... mode] phrase. *)
              "lock table users";
            ];
          (* The gate still holds without the feature. *)
          assert_parse_error @@ build_str [ "lock table users in exclusive mode" ];
          ());
      Oth.test ~name:"Locking needs its feature" ~tags:[ "mql" ] (fun _ ->
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features:[ Mql.Feature.Locking_clause ] sql
            >>= fun ast -> Mql.Ast.to_string ast
          in
          let sql = build_str [ "select a from foo for update of foo" ] in
          Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql);
          let sql = build_str [ "select a from foo for update of foo, bar nowait" ] in
          Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql);
          (* The gate still holds without the feature. *)
          assert_parse_error @@ build_str [ "select a from foo for update of foo" ];
          ());
      Oth.test ~name:"CTEs stand before a data-modifying statement" ~tags:[ "mql" ] (fun _ ->
          let features = [ Mql.Feature.Data_modifying ] in
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~variables:true ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let sql = build_str [ sql ] in
              Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok sql) (rt sql))
            [
              "with a as (select b from bar) delete from foo where c in (select b from a)";
              (* The printer writes no blank before a column list. *)
              "with a as (select b from bar) insert into foo(c) select b from a";
              "with a as (select b from bar) update foo set c = 1";
              "with recursive a as (select b from bar) delete from foo";
            ];
          (* The gate still holds without the feature. *)
          assert_parse_error @@ build_str [ "with a as (select b from bar) delete from foo" ];
          ());
      Oth.test ~name:"The remainder operator and array slices round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a from foo where rn % 2 = 0";
              "select a[1 : 2] from foo";
              "select array_to_string(s.toks[1 : 2], '.') from foo";
              (* A subscript is still a subscript. *)
              "select a[1] from foo";
            ];
          ());
      Oth.test ~name:"count is usable as a name" ~tags:[ "mql" ] (fun _ ->
          (* [count] is no longer a keyword.  The parser reads a call over a
             star in the same way as each other call, thus the name is still
             usable. *)
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select count(*) from foo";
              "select count(a) from foo";
              "select count(*) as count from foo order by count desc";
              "select count from foo";
              "select foo.count from foo";
            ];
          ());
      Oth.test ~name:"A query in the position of a value" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a from foo where a = (select b from bar)";
              "select (select count(*) from bar) as c from foo";
              "select coalesce((select b from bar), 0) from foo";
              (* [in (query)] holds its own form.  It does not become a
                 list of one query. *)
              "select a from foo where a in (select b from bar)";
              "select a from foo where exists (select b from bar)";
            ];
          ());
      Oth.test ~name:"A name can carry a schema or a table" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select foo.a from foo";
              "select pg_temp.f(a) from foo";
              "select pg_temp.f() from foo";
              (* A star on a name. *)
              "select jobs.* from jobs";
              "select p.*, q.a from p, q";
            ];
          ());
      Oth.test ~name:"Arrays and the SQL special forms round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select array[1, 2] from foo";
              "select array[]::text[] from foo";
              "select array(select b from bar) from foo";
              "select extract(epoch from now()) from foo";
              "select substring(a from '^x') from foo";
              "select a from foo where position('/' in b) > 0";
              "select a from foo where d ? 'k'";
              "select a from foo where a like 'x' escape '!'";
            ];
          ());
      Oth.test ~name:"CAST (x AS t) is the same shape as x::t" ~tags:[ "mql" ] (fun _ ->
          (* The AST does not record which form the SQL used. *)
          CCList.iter
            (fun (sql, expected) ->
              Oth.Assert.eq
                ~eq:String_result.equal
                ~pp:String_result.pp
                (Ok expected)
                (roundtrip sql))
            [
              ("select cast(a as text) from foo", "select a::text from foo");
              ("select CAST(a AS text[]) from foo", "select a::text[] from foo");
              ("select cast(a + 1 as bigint) from foo", "select (a + 1)::bigint from foo");
            ];
          ());
      Oth.test ~name:"Both spellings of not-equal are one shape" ~tags:[ "mql" ] (fun _ ->
          (* The AST does not record which spelling the SQL used. *)
          assert_comment_stripped
            ~expected:"select a from foo where a <> 1"
            "select a from foo where a != 1";
          ());
      Oth.test
        ~name:"An escape string becomes the characters that it represents"
        ~tags:[ "mql" ]
        (fun _ ->
          (* The token holds the characters, thus the printer chooses the form.
             A value that a plain string can carry gets a plain string. *)
          assert_comment_stripped
            ~expected:"select trim(a, ' ') from foo"
            {|select trim(a, E' ') from foo|};
          ());
      Oth.test
        ~name:"A value a plain string cannot carry keeps the escape form"
        ~tags:[ "mql" ]
        (fun _ ->
          (* [Pgsql_io.Typed_sql] executes this text and reads a backslash inside
             a literal as an escape of the character after it, thus a plain
             string that ends in one eats its own closing quote.  A newline in a
             plain string puts the rest of the statement on a new line, where
             [Typed_sql] removes each line that starts with [--].  The escape
             form holds each of these, and PostgreSQL reads the two forms as the
             same text. *)
          assert_comment_stripped
            ~expected:{|select a from foo where b = E'\\'|}
            {|select a from foo where b = E'\\'|};
          assert_comment_stripped
            ~expected:{|select a from foo where b = E'a\nb'|}
            {|select a from foo where b = E'a\nb'|};
          assert_comment_stripped
            ~expected:{|select a from foo where b = E'a\tb\rc'|}
            {|select a from foo where b = E'a\tb\rc'|};
          (* One backslash written as a plain string reads back the same way. *)
          assert_comment_stripped
            ~expected:{|select a from foo where b = E'\\n'|}
            {|select a from foo where b = '\n'|};
          ());
      Oth.test ~name:"A list of three or more holds its order" ~tags:[ "mql" ] (fun _ ->
          (* The grammar builds each of these lists to the left.  A printer that
             folds to the right puts the last item before the one that is
             before it.  Two items cannot show the fault. *)
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a from foo order by id, filepath, template_var";
              "select a from foo order by a desc, b asc, c";
              "select a from t1, t2, t3 where a = b";
              "select a from foo group by a, b, c";
              "select a from foo where (a, b, c) = (1, 2, 3)";
              "select a from foo inner join u on a = b inner join v on b = c inner join w on c = d";
              "select f(a, b, c) from foo";
              "select a from foo where a in (1, 2, 3)";
              "select a from foo inner join bar using (a, b, c)";
            ];
          ());
      Oth.test ~name:"A comma can follow a join" ~tags:[ "mql" ] (fun _ ->
          (* Each entry of a FROM clause is a table with the joins that
             attach to it.  A comma separates the entries. *)
          CCList.iter
            (fun sql -> assert_roundtrip ~variables:true @@ build_str [ sql ])
            [
              "select a from foo inner join bar on a = b, baz";
              "select a from foo inner join bar on a = b, baz inner join qux on c = d";
              "select a from foo, bar inner join baz on a = b";
              "select dep from instances inner join ts on instances.state_id = ts.id, \
               unnest(dependencies) as dep";
            ];
          ());
      Oth.test ~name:"The last expression shapes round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip ~variables:true @@ build_str [ sql ])
            [
              (* [unnest], [left] and [right] are words of this grammar, thus
                 each needs its own production to stand as a call. *)
              "select unnest($a) as x, unnest($b) as y";
              "select left(p, 1) from foo";
              "select right(p, 1) from foo";
              (* A query where a value stands, behind [not in]. *)
              "select a from foo where a not in (select b from bar)";
              (* A name that is a word of this grammar. *)
              "with row as (select 1 as a) select a from row";
              (* A call that makes a record needs a type for each column. *)
              "select a from jsonb_to_recordset(d) as e(x text, y jsonb)";
              "select a from jsonb_to_recordset(d) as e(x text, y text[])";
            ];
          ());
      Oth.test ~name:"A limit after the locking clause moves before it" ~tags:[ "mql" ] (fun _ ->
          (* PostgreSQL accepts a limit in each place.  The AST does not
             record which place the SQL used, thus the printer writes it before
             the locking clause. *)
          let rt sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features:[ Mql.Feature.Locking_clause ] sql
            >>= fun ast -> Mql.Ast.to_string ast
          in
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Ok "select a from foo limit 1 for update of foo skip locked")
            (rt "select a from foo for update of foo skip locked limit 1");
          ());
      Oth.test ~name:"A join takes any FROM item" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              (* A join target is each form that a FROM clause accepts. *)
              "select a from foo inner join (select b from bar) as x on a = b";
              "select a from foo cross join lateral (select b from bar) as x";
              "select a from foo left join lateral (select b from bar) as x on true";
              "select a from foo cross join lateral jsonb_each(foo.d) as e";
              "select a from foo inner join jsonb_array_elements(foo.d) as e on true";
            ];
          ());
      Oth.test ~name:"A bare JOIN is an inner join" ~tags:[ "mql" ] (fun _ ->
          (* The AST does not record which spelling the SQL used. *)
          assert_comment_stripped
            ~expected:"select a from foo inner join bar on a = b"
            "select a from foo join bar on a = b";
          ());
      Oth.test ~name:"FROM items round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              (* A schema before a name. *)
              "select count(*) from information_schema.tables where table_name = 'foo'";
              "select a from public.foo as f";
              (* A call in the position of a table. *)
              "select e from jsonb_array_elements_text(data) as e";
              "select a from json_array_elements_text(policy)";
              "select a from jsonb_to_recordset(d) as x(k, v)";
              (* A derived table can name its columns. *)
              "select a from (select b from bar) as x(a)";
            ];
          ());
      Oth.test ~name:"The alias of a FROM item normalizes" ~tags:[ "mql" ] (fun _ ->
          (* [AS] is optional in SQL, and the AST does not record which spelling
             was used. *)
          assert_comment_stripped
            ~expected:"select a from jsonb_each(d) as e"
            "select a from jsonb_each(d) e";
          ());
      Oth.test
        ~name:"UNNEST takes more than one array and names its columns"
        ~tags:[ "mql" ]
        (fun _ ->
          (* More than one array makes more than one column, and the item can
             name them.  These need the variable syntax. *)
          CCList.iter
            (fun sql -> assert_roundtrip ~variables:true @@ build_str [ sql ])
            [
              "select a from unnest($x) as t(id)";
              "select dir, workspace from unnest($dirs, $workspaces) as v(dir, workspace)";
              "select a from foo cross join lateral unnest($x) as t";
            ];
          ());
      Oth.test ~name:"Aggregate calls round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              (* A call over a star, which was the only shape [count] had. *)
              "select count(*) from foo";
              (* A call to [count] over an expression. *)
              "select count(a) from foo";
              "select count(distinct a) from foo";
              "select count(distinct instances.address) from foo";
              "select string_agg(distinct currency, ',') from foo";
              (* The order of an aggregate, which is not the order of the
                 query. *)
              "select string_agg(a, ',' order by b) from foo";
              "select string_agg(rh.key || ',' || rh.hash, ',' order by rh.key) from foo";
              (* The aggregate reads only the rows that satisfy the filter. *)
              "select count(*) filter (where a is true) from foo";
              "select count(*) filter (where df.severity = 'high') as high from foo";
              "select count(a) filter (where b) from foo";
            ];
          ());
      Oth.test ~name:"Window functions round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select row_number() over () from foo";
              "select count(*) over () from foo";
              "select row_number() over (order by n.cursor_id) from foo";
              "select row_number() over (partition by a) from foo";
              "select row_number() over (partition by a, b order by c desc) from foo";
              "select row_number() over (partition by gwm.repo order by gwm.created_at desc) as rn \
               from foo";
            ];
          ());
      Oth.test ~name:"Aggregate and window spellings normalize" ~tags:[ "mql" ] (fun _ ->
          (* The AST does not record the blank, thus the printer writes the
             two spellings in the same way. *)
          assert_comment_stripped
            ~expected:"select row_number() over () from foo"
            "select row_number() over() from foo";
          ());
      Oth.test ~name:"Cast targets are full type names" ~tags:[ "mql" ] (fun _ ->
          (* A cast target is a type name, not a bare identifier.  A type name
             can be a keyword of this grammar ([interval]), can take arguments
             and can carry a trailing word. *)
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a::interval from foo";
              "select a::time::interval from foo";
              "select a::numeric(10, 2) from foo";
              "select a::timestamp with time zone from foo";
              "select a::timestamp without time zone from foo";
              "select a::double precision from foo";
              "select a::text[] from foo";
              "select a::interval[] from foo";
              (* An interval literal is still a literal. *)
              "select interval '1 day' from foo";
              "select a from foo where b::interval > interval '1 day'";
            ];
          ());
      Oth.test ~name:"Join forms round-trip" (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a from foo cross join bar";
              "select a from foo full join bar on a = b";
              "select a from foo inner join bar using (a)";
              "select a from foo inner join bar using (a, b)";
              (* Existing forms must be unchanged. *)
              "select a from foo inner join bar on a = b";
              "select a from foo left join bar on a = b";
              "select a from foo right join bar on a = b";
            ];
          ());
      Oth.test ~name:"OUTER is accepted and normalized away" (fun _ ->
          (* [LEFT OUTER JOIN] means [LEFT JOIN]; the canonical rendering drops
             the noise word. *)
          assert_comment_stripped
            ~expected:"select a from foo left join bar on a = b"
            "select a from foo left outer join bar on a = b";
          assert_comment_stripped
            ~expected:"select a from foo full join bar on a = b"
            "select a from foo full outer join bar on a = b";
          ());
      (* Locking is gated: it does not parse unless the caller opts in, mirroring
         [~variables].  This is the first of the two gates; the second is
         [Mql_to_pgsql.of_mql], tested in code/tests/mql_to_pgsql. *)
      Oth.test ~name:"Locking clauses need the feature" (fun _ ->
          CCList.iter
            (fun sql -> assert_parse_error @@ build_str [ sql ])
            [
              "select a from foo for update";
              "select a from foo for share";
              "select a from foo for update skip locked";
            ];
          ());
      Oth.test ~name:"Locking clauses round-trip when enabled" (fun _ ->
          let rt sql =
            Oth.Assert.eq
              ~eq:String_result.equal
              ~pp:String_result.pp
              (Ok sql)
              (let open CCResult.Infix in
               Mql.Ast.of_string ~features:[ Mql.Feature.Locking_clause ] sql
               >>= fun ast -> Mql.Ast.to_string ast)
          in
          CCList.iter
            (fun sql -> rt @@ build_str [ sql ])
            [
              "select a from foo for update";
              "select a from foo for no key update";
              "select a from foo for share";
              "select a from foo for key share";
              "select a from foo for update nowait";
              "select a from foo for update skip locked";
              "select a from foo where b = 1 order by a limit 10 for update skip locked";
            ];
          ());
      Oth.test ~name:"Locking words stay usable as identifiers" (fun _ ->
          (* [share], [key], [locked] and [no] are non-reserved in PostgreSQL and
             are real column names here -- [revision_hashes.key]. Lexing the
             locking clauses as whole PHRASES is what keeps them usable. *)
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select key from revision_hashes";
              "select share, locked, no from foo";
              "select a from foo where key = 1 and share = 2";
            ];
          ());
      Oth.test ~name:"DML keywords are reserved but reachable when quoted" (fun _ ->
          (* Unlike the locking phrases, each DML keyword starts a statement and
             cannot be lexed as a phrase, so these DO become reserved.  Quoting is
             the escape hatch -- which is exactly what quoted identifiers are for. *)
          assert_parse_error @@ build_str [ "select update from foo" ];
          assert_parse_error @@ build_str [ "select insert, delete from foo" ];
          assert_roundtrip @@ build_str [ {|select "update" from foo|} ];
          assert_roundtrip @@ build_str [ {|select "insert", "delete", "set" from foo|} ];
          ());
      Oth.test ~name:"DML needs the feature" (fun _ ->
          CCList.iter
            (fun sql -> assert_parse_error @@ build_str [ sql ])
            [
              "insert into foo (a, b) values (1, 2)";
              "update foo set a = 1";
              "delete from foo";
              "with d as (delete from foo returning a) select a from d";
            ];
          ());
      (* Rendering must be STABLE and re-parseable: render, re-parse, re-render,
         and the two renderings agree.  That is the property [Mql.Ast.to_string]
         actually owes its callers.  Pinning exact strings here would only pin
         [cat]'s spacing choices, which are cosmetic -- [foo(a, b)] and
         [foo (a, b)] are the same SQL. *)
      Oth.test ~name:"DML rendering is stable and re-parseable" (fun _ ->
          let features = [ Mql.Feature.Data_modifying ] in
          let render sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let once = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err (render (build_str [ sql ])) in
              let twice = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err (render once) in
              Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp once twice)
            [
              "insert into foo values (1, 2)";
              "insert into foo (a, b) values (1, 2)";
              "insert into foo (a, b) values (1, 2), (3, 4)";
              "insert into foo default values";
              "insert into foo (a) select a from bar";
              "insert into foo (a) select a from bar union select b from baz";
              "insert into foo (a) values (1) on conflict do nothing";
              "insert into foo (a) values (1) on conflict (a) do nothing";
              "insert into foo (a) values (1) on conflict (a) do update set a = 2";
              "insert into foo (a) values (1) on conflict (a) do update set a = 2 where b = 3";
              "insert into foo (a) values (1) returning a";
              "update foo set a = 1";
              "update foo set a = 1, b = 2 where c = 3";
              "update foo set a = 1 from bar where c = 3";
              "update foo set a = 1 returning a, b";
              "delete from foo";
              "delete from foo where a = 1";
              "delete from foo where a = 1 returning a";
              (* A data-modifying CTE. *)
              "with d as (delete from foo where a = 1 returning b) select b from d";
            ];
          ());
      Oth.test ~name:"DDL needs the feature" (fun _ ->
          CCList.iter
            (fun sql -> assert_parse_error @@ build_str [ sql ])
            [
              "create table foo (a integer)";
              "alter table foo add column b text";
              (* [SET CONSTRAINTS] tells PostgreSQL when it checks a foreign key.  The fixtures
                 of the reifier write [all deferred], thus they can write the rows in any
                 order. *)
              "set constraints all deferred";
              "set constraints all immediate";
              "set constraints fk_a, fk_b deferred";
              "drop table foo";
              "create index on foo (a)";
            ];
          ());
      Oth.test ~name:"A gated construct in a subquery needs the feature" (fun _ ->
          (* Every construct below hides inside a subquery in expression or
             FROM position, where no top-level form names it.  The walk of
             [features_used] reaches them, so the endpoint posture -- no
             features named -- refuses them all at parse time, and each one
             parses only when its feature is named. *)
          let refused sql = assert_parse_error (build_str [ sql ]) in
          let accepted ~features sql =
            ignore
              (Oth.Assert.ok
                 ~fail_msg:
                   (Printf.sprintf "expected %S to parse with its feature" (build_str [ sql ]))
                 (Mql.Ast.of_string ~features (build_str [ sql ]))
                : Mql.Ast.t)
          in
          (* A CTE holds a data-modifying statement.  The CTE must RETURNING for
             the outer select to read it, as PostgreSQL requires. *)
          let dml =
            "select 1 from t where exists (with a as (delete from x returning *) select 1 from a)"
          in
          refused dml;
          accepted ~features:[ Mql.Feature.Data_modifying ] dml;
          (* A scalar subquery holds a data-modifying statement. *)
          let dml2 =
            "select 1 from t where a = (with b as (update x set a = 1 returning a) select 1 from b)"
          in
          refused dml2;
          accepted ~features:[ Mql.Feature.Data_modifying ] dml2;
          (* A CTE holds a schema statement. *)
          let ddl =
            "select 1 from t where exists (with a as (create table x(a int)) select 1 from a)"
          in
          refused ddl;
          accepted ~features:[ Mql.Feature.Ddl ] ddl;
          (* Row locking hides in [exists], in [in], and in a derived table. *)
          let locking1 = "select 1 from t where exists (select 1 from x for update)" in
          refused locking1;
          accepted ~features:[ Mql.Feature.Locking_clause ] locking1;
          let locking2 = "select 1 from t where a in (select a from x for update)" in
          refused locking2;
          accepted ~features:[ Mql.Feature.Locking_clause ] locking2;
          let locking3 = "select 1 from (select 1 from x for update) as b" in
          refused locking3;
          accepted ~features:[ Mql.Feature.Locking_clause ] locking3);
      Oth.test ~name:"DDL rendering is stable and re-parseable" (fun _ ->
          let features = [ Mql.Feature.Ddl ] in
          let render sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          CCList.iter
            (fun sql ->
              let once = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err (render (build_str [ sql ])) in
              let twice = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err (render once) in
              Oth.Assert.eq ~eq:CCString.equal ~pp:CCString.pp once twice)
            [
              "create table foo (a integer, b text not null)";
              "create table if not exists foo (a uuid primary key, b varchar(255) default 'x')";
              "create temp table foo (a integer)";
              "create table foo (a integer, b integer, primary key (a, b))";
              "create table foo (a integer references bar (id))";
              "create table foo (a integer, constraint ck check (a > 0))";
              "create table foo (a text[], b numeric(10, 2))";
              "alter table foo add column b text";
              "alter table foo add column if not exists b text not null default 'x'";
              "alter table foo drop column b";
              "alter table foo alter column b set not null";
              "alter table foo alter column b drop default";
              "alter table foo alter column b type text";
              "alter table foo add constraint ck unique (a, b)";
              "alter table foo drop constraint ck";
              "alter table foo rename to bar";
              "alter table foo rename column a to b";
              "alter table if exists only foo add column b text";
              "drop table foo";
              "drop table if exists foo, bar cascade";
              "drop index if exists foo";
              "create unique index concurrently idx on foo (a, b)";
              "create index on foo using gin (a)";
              "create index idx on foo (a desc) where b = 1";
              "create view v as select a from foo";
              "create or replace view v (x) as select a from foo";
              "truncate foo";
              "analyze foo";
            ];
          ());
      (* Each form below is in a query of this repository. *)
      Oth.test
        ~name:"The case-blind regular expression operators round-trip"
        ~tags:[ "mql" ]
        (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a ~* b from foo";
              "select a !~* b from foo";
              "select a from foo where a ~* (b->>'k') and c !~* 'x'";
            ];
          ());
      Oth.test ~name:"A comparison with ALL round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip ~variables:true @@ build_str [ sql ])
            [
              "select a from foo where a <> all (b)";
              "select a from foo where coalesce(a, '') <> all ($types::text[])";
              "select a from foo where a = any(b)";
            ];
          ());
      (* A printed float literal has to read back as the same number, and the
         rendered text has to read back a second time unchanged.  The mirror of
         the HCL float tests: [%g] capped at 12 digits once, and an integral or
         underflowed value would print with a bare trailing dot, which the
         lexer reads as an integer and changes the shape of the tree. *)
      Oth.test ~name:"Float literals round-trip" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun (sql, expected) ->
              let sql = build_str [ sql ] in
              let expected = build_str [ expected ] in
              Oth.Assert.eq
                ~eq:String_result.equal
                ~pp:String_result.pp
                (Ok expected)
                (roundtrip sql))
            [
              ("select 0.5 from t", "select 0.5 from t");
              ("select 2.50 from t", "select 2.5 from t");
              ("select 1.0 from t", "select 1.0 from t");
              ("select 3.141592653589793 from t", "select 3.141592653589793 from t");
              ("select 0.1234567890123456 from t", "select 0.1234567890123456 from t");
              ("select 1e19 from t", "select 1e+19 from t");
              ("select 1e-7 from t", "select 1e-07 from t");
              (* Underflows to zero in a double. *)
              ("select 1e-400 from t", "select 0.0 from t");
              ("select 4.9e-324 from t", "select 5e-324 from t");
            ];
          ());
      (* An out-of-range literal is refused by the lexer rather than read as a
         number that cannot render: [int_of_string] would raise [Failure] out
         of the parse path, and an infinite float would render to text that
         cannot be read back. *)
      Oth.test ~name:"An out-of-range numeric literal is refused" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            assert_parse_error
            [
              "select 99999999999999999999 from t";
              "select 1e999 from t";
              "select 1e99999999999999999999 from t";
              "select -1e999 from t";
            ];
          ());
      Oth.test ~name:"The & operator round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [ "select generate_series(1, hashtext(a) & 3) from foo"; "select a & b & c from foo" ];
          ());
      (* PostgreSQL binds [NOT] looser than [IS] and tighter than [AND]: it reads
         [not a = b] as [not (a = b)] and [not a and b] as [(not a) and b].  The
         grammar must read the same text as the same tree, and write it back
         unchanged. *)
      Oth.test
        ~name:"NOT binds looser than a comparison, as PostgreSQL reads it"
        ~tags:[ "mql" ]
        (fun _ ->
          let module A = Mql_ast in
          let parsed sql = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.expr_of_string sql in
          let id n = A.Identifier (A.ident n) in
          let same ~msg expected actual =
            Oth.Assert.true_ ~fail_msg:msg (A.equal_expr expected actual)
          in
          same
            ~msg:"not a = b must read as not (a = b)"
            (A.Not (A.Eq (id "a", id "b")))
            (parsed "not a = b");
          same
            ~msg:"not a is null must read as not (a is null)"
            (A.Not (A.Is (id "a", A.Null)))
            (parsed "not a is null");
          same
            ~msg:"not a in (1) must read as not (a in (1))"
            (A.Not (A.In (id "a", [ A.Int 1 ])))
            (parsed "not a in (1)");
          same
            ~msg:"not a and b must read as (not a) and b"
            (A.And (A.Not (id "a"), id "b"))
            (parsed "not a and b");
          same
            ~msg:"not not a must read as not (not a)"
            (A.Not (A.Not (id "a")))
            (parsed "not not a");
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select 1 from t where not a = b and c = d";
              "select 1 from t where not a is null";
              "select 1 from t where not not a = b";
              (* The form the reifier queries write. *)
              "select 1 from t inner join e on e.f = cs.s and not e.to_id = any(cs.visited)";
            ];
          ());
      Oth.test ~name:"COLLATE round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a from foo order by a collate \"C\", b collate \"C\" desc";
              "select a collate \"C\" from foo";
            ];
          ());
      Oth.test ~name:"HAVING with no GROUP BY round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select count(*) from foo having count(*) > 0";
              "select count(*) from foo where a = 1 having count(*) > 0";
            ];
          ());
      Oth.test ~name:"A json path that is not a literal round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a #> b, a #>> b from foo";
              "select bool_or(a #> p is distinct from b #> p) from foo";
              "select a #>> '{}' from foo";
            ];
          ());
      Oth.test ~name:"WITH ORDINALITY round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select a.e from jsonb_array_elements(x) with ordinality as a(e, ord)";
              "select e from jsonb_array_elements(x) with ordinality";
              "select a.e from foo, lateral jsonb_array_elements(x) with ordinality as a(e, ord)";
            ];
          ());
      Oth.test ~name:"A CTE column list round-trips" ~tags:[ "mql" ] (fun _ ->
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "with c(id) as (select 1) select id from c";
              "with recursive chain(id, depth) as (select 1, 0 union all select id, depth + 1 from \
               chain where depth < 3) select id from chain";
            ];
          ());
      Oth.test ~name:"ALTER FUNCTION SET round-trips" ~tags:[ "mql" ] (fun _ ->
          let sql = "alter function f() set search_path = public, pg_catalog" in
          Oth.Assert.eq
            ~eq:String_result.equal
            ~pp:String_result.pp
            (Ok sql)
            (let open CCResult.Infix in
             Mql.Ast.of_string ~features:[ Mql.Feature.Ddl ] sql >>= Mql.Ast.to_string);
          assert_parse_error sql;
          ());
      Oth.test ~name:"Partition DDL round-trips" (fun _ ->
          let features = Mql.Feature.all in
          let roundtrip sql =
            let open CCResult.Infix in
            Mql.Ast.of_string ~features sql >>= fun ast -> Mql.Ast.to_string ast
          in
          (* The left side is a fixture, the right side the canonical
             rendering: the printer puts no blank before a parenthesis that
             follows a name or a keyword not in its blank list, so [range(a)]
             and [to(10)] come back without one. *)
          CCList.iter
            (fun (sql, expected) ->
              Oth.Assert.eq
                ~eq:String_result.equal
                ~pp:String_result.pp
                (Ok expected)
                (roundtrip (build_str [ sql ])))
            [
              ( "create table foo (a integer, b text) partition by range (a)",
                "create table foo(a integer, b text) partition by range(a)" );
              ( "create table foo (a integer, b text) partition by list (b)",
                "create table foo(a integer, b text) partition by list(b)" );
              (* The render order is the parse order: PostgreSQL puts PARTITION
                 BY ahead of ON COMMIT in the CREATE TABLE synopsis. *)
              ( "create temp table foo (a integer) partition by range (a) on commit drop",
                "create temp table foo(a integer) partition by range(a) on commit drop" );
              ( "create table foo_p partition of foo for values from (0) to (10)",
                "create table foo_p partition of foo for values from (0) to(10)" );
              ( "create table foo_p partition of foo for values in ('a', 'b')",
                "create table foo_p partition of foo for values in ('a', 'b')" );
              ( "create table foo_p partition of foo default",
                "create table foo_p partition of foo default" );
              ( "alter table foo attach partition foo_p for values from (0) to (10)",
                "alter table foo attach partition foo_p for values from (0) to(10)" );
              ( "alter table foo attach partition foo_p default",
                "alter table foo attach partition foo_p default" );
              (* [hash] is not a keyword: a table with that name keeps lexing as
                 an identifier. *)
              ("create table hash (id int)", "create table hash(id int)");
            ];
          ());
      Oth.test ~name:"Partition keywords are reserved" (fun _ ->
          (* Reserved like the other DDL keywords: as bare names each one fails
             to parse, and a column with one of those names needs quotes. *)
          assert_parse_error @@ build_str [ "select attach, range, list from foo" ]);
      Oth.test ~name:"Non-reserved keywords stay usable as names" (fun _ ->
          (* PostgreSQL does not reserve these and they are real columns here --
             [resources.type], [revision_hashes.key].  The schema statements
             must not remove them.

             [unique] is not in this list.  PostgreSQL reserves that word, thus
             a column with that name needs quotes.  No column in this
             repository has that name. *)
          CCList.iter
            (fun sql -> assert_roundtrip @@ build_str [ sql ])
            [
              "select type from resources";
              "select key from revision_hashes";
              "select type, key, comment, index from foo";
              "select a from foo where type = 'x' and key = 'y'";
              "select t.type from resources as t";
              (* [SET CONSTRAINTS] brought these three words in.  PostgreSQL does not reserve them,
                 thus a column may still carry the name. *)
              "select constraints from foo";
              "select deferred from foo";
              "select immediate from foo";
              (* [rows] is a word of [CREATE FUNCTION].  PostgreSQL does not reserve it. *)
              "select count(*) as rows from foo";
              "select x.rows from foo as x";
              (* The phrases of [LOCK TABLE] keep [lock], [mode], [share] and
                 [exclusive] as names. *)
              "select lock, mode, share, exclusive from foo";
              "select x.mode from foo as x";
            ];
          ());
      Oth.test ~name:"to_string_multi of no queries is empty" (fun _ ->
          Oth.Assert.eq ~eq:String_result.equal ~pp:String_result.pp (Ok "")
          @@ Mql.Ast.to_string_multi [];
          ());
      Oth.test ~name:"of_string rejects multiple queries" (fun _ ->
          (* What keeps the HTTP endpoint single-query. *)
          assert_parse_error @@ build_str [ "select * from foo; select baz from bar" ];
          assert_parse_error @@ build_str [ "select * from foo;; select baz from bar" ];
          ());
      Oth.test ~name:"Multi query composes with variables" (fun _ ->
          let sql = build_str [ "select * from a where x = $p; select * from b limit $n" ] in
          assert_roundtrip_multi ~variables:true sql;
          ignore
            (Oth.Assert.error ~fail_msg:"variables must stay gated in the multi entry point"
             @@ Mql.Ast.of_string_multi sql
              : Mql.Ast.err);
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

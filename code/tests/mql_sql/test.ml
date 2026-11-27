let assert_read ~expected sql = Oth.Assert.Eq.string ~expected ~actual:(Mql_sql.read sql)

(* The failure must be an exception and not a result: the caller applies [read] at module level,
   where there is nobody to give a result to. *)
let assert_read_fails sql =
  match Mql_sql.read sql with
  | _ -> Oth.Assert.false_ (Printf.sprintf "MQL must refuse %S" sql)
  | exception Mql_sql.Sql_err _ -> ()

let test =
  Oth.parallel
    [
      Oth.test ~name:"Read a query" (fun _ ->
          assert_read ~expected:"select a from t" "select   a\n  from t";
          ());
      Oth.test ~name:"A comment goes away" (fun _ ->
          assert_read ~expected:"select a from t" "-- why\nselect a from t";
          ());
      (* [Pgsql_io.Typed_sql] gives a number to each [$name] after this step, thus the name must
         come out as it went in. *)
      Oth.test ~name:"A variable stays" (fun _ ->
          assert_read ~expected:"select a from t where id = $id" "select a from t where id = $id";
          ());
      (* The repository writes these forms, thus [read] must enable each MQL feature. *)
      Oth.test ~name:"A data-modifying statement is legal" (fun _ ->
          assert_read ~expected:"delete from t where id = $id" "delete from t where id = $id";
          ());
      Oth.test ~name:"A lock is legal" (fun _ ->
          assert_read ~expected:"select a from t for update" "select a from t for update";
          ());
      Oth.test ~name:"A schema statement is legal" (fun _ ->
          assert_read ~expected:"create index on t(a)" "create index on t (a)";
          ());
      Oth.test ~name:"A fault raises" (fun _ ->
          assert_read_fails "select from where";
          ());
      Oth.test ~name:"Read many statements" (fun _ ->
          Oth.Assert.String_list.eq
            ~expected:[ "truncate t"; "analyze t" ]
            ~actual:(Mql_sql.read_multi "truncate t;\nanalyze t;\n");
          ());
      (* PostgreSQL takes no parameter in a SET statement, thus the value goes in the text.
         MQL makes it a string literal and escapes it. *)
      Oth.test ~name:"Build a session setting" (fun _ ->
          Oth.Assert.Eq.string
            ~expected:"set local statement_timeout = '5s'"
            ~actual:(Mql_sql.set ~local:true ~name:"statement_timeout" "5s");
          Oth.Assert.Eq.string
            ~expected:"set lock_timeout = '3s'"
            ~actual:(Mql_sql.set ~name:"lock_timeout" "3s");
          Oth.Assert.Eq.string
            ~expected:"set lock_timeout = '3''s'"
            ~actual:(Mql_sql.set ~name:"lock_timeout" "3's");
          ());
      (* The name is spliced into the text unquoted, so anything but a legal
         identifier is refused rather than written. *)
      Oth.test ~name:"A setting name that is not an identifier is refused" (fun _ ->
          CCList.iter
            (fun name ->
              match Mql_sql.set ~name "v" with
              | _ -> Oth.Assert.false_ (Printf.sprintf "the name %S must be refused" name)
              | exception Mql_sql.Sql_err _ -> ())
            [ "a; drop table x"; "a b"; "1a"; ""; "a-b" ]);
      Oth.test ~name:"A legal setting name still works" (fun _ ->
          Oth.Assert.Eq.string ~expected:"set _a1 = 'v'" ~actual:(Mql_sql.set ~name:"_a1" "v");
          ());
      (* The [.sql] file writes [where $where], thus MQL reads the whole file when the module
         loads.  The filter arrives at the request and takes the place of the variable. *)
      Oth.test ~name:"Put a filter in the place of the where variable" (fun _ ->
          let q = Mql_sql.read_ast "select a from t where $where" in
          Oth.Assert.Eq.string
            ~expected:"select a from t where b = $strings[1]"
            ~actual:
              (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err
              @@ Mql_sql.with_where ~name:"where" q "b = ($strings)[1]");
          (* No filter means every row. *)
          Oth.Assert.Eq.string
            ~expected:"select a from t where true"
            ~actual:(Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql_sql.with_where ~name:"where" q "");
          ());
      (* A CTE chain is the shape every one of these files has. *)
      Oth.test ~name:"Put a filter through a CTE chain" (fun _ ->
          let q = Mql_sql.read_ast "with q as (select a from t) select a from q where $where" in
          Oth.Assert.Eq.string
            ~expected:"with q as (select a from t) select a from q where a > 1"
            ~actual:
              (Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql_sql.with_where ~name:"where" q "a > 1");
          ());
      (* A query with no such clause is a fault of the file, thus it must be reported. *)
      Oth.test ~name:"A query with no where variable fails" (fun _ ->
          let q = Mql_sql.read_ast "select a from t where b = 1" in
          ignore
            (Oth.Assert.error_pp ~pp:CCString.pp (Mql_sql.with_where ~name:"where" q "a > 1")
              : Mql.Ast.err);
          ());
      (* The parser decides where a statement ends, thus a [;] in a literal is not a boundary. *)
      Oth.test ~name:"A semicolon in a literal is not a boundary" (fun _ ->
          Oth.Assert.Eq.int
            ~expected:1
            ~actual:(CCList.length (Mql_sql.read_multi "select 'a;b' from t"));
          ());
      (* A builder statement has no text to read, thus [write_exn] gives the text back at module
         level and raises rather than return a result. *)
      Oth.test ~name:"Write a statement the builder made" (fun _ ->
          Oth.Assert.Eq.string
            ~expected:"drop table if exists foo"
            ~actual:(Mql_sql.write_exn (Mql.Build.drop_table ~if_exists:true "foo"));
          Oth.Assert.Eq.string
            ~expected:"analyze foo"
            ~actual:(Mql_sql.write_exn (Mql.Build.analyze_table "foo"));
          Oth.Assert.Eq.string
            ~expected:"create temp table foo on commit drop as select a from bar"
            ~actual:
              (Mql_sql.write_exn
                 (Mql.Build.create_temp_table_as
                    ~on_commit_drop:true
                    "foo"
                    (Mql.Build.select
                       ~from:[ Mql.Build.table "bar" ]
                       ~cols:(Mql.Build.columns [ Mql.Build.col (Mql.Build.id "a") ])
                       ())));
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

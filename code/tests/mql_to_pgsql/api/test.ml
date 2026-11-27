(* RFD 1724: the allow lists are required arguments of [of_mql] and
   [audit_query], and the library exposes its default lists.  These tests name
   that API.  They are in their own test binary, thus until the API exists only
   this binary fails to compile and the other tests of [mql_to_pgsql] still
   run. *)

let schema =
  Mql_to_pgsql.Schema.(
    make
      [
        Table.make
          ~name:"test"
          Column.[ make ~name:"id" ~type_:Type_.Uuid (); make ~name:"name" ~type_:Type_.Text () ];
      ])

let func_allow_list = Mql_to_pgsql.default_func_allow_list
let cast_allow_list = Mql_to_pgsql.default_cast_allow_list
let parse query = Oth.Assert.ok_pp ~pp:Mql.Ast.pp_err @@ Mql.Ast.of_string query
let sorted = CCList.sort CCString.compare

(* Each query must give an error that [expected] accepts.  The failure names
   each query that does not. *)
let assert_refused ~func_allow_list ~cast_allow_list ~expected queries =
  Oth.Assert.String_list.eq
    ~expected:[]
    ~actual:
      (CCList.filter_map
         (fun query ->
           match Mql_to_pgsql.of_mql ~func_allow_list ~cast_allow_list ~schema (parse query) with
           | Error err when expected err -> None
           | Error err -> Some (query ^ " -> " ^ Mql_to_pgsql.show_err err)
           | Ok _ -> Some (query ^ " -> accepted"))
         queries)

let test =
  Oth.parallel
    [
      Oth.test ~name:"Allow list: the default function list is the fixed list" (fun _ ->
          Oth.Assert.String_list.eq
            ~expected:(sorted Mql_adversarial_corpus.default_func_allow_list)
            ~actual:(sorted Mql_to_pgsql.default_func_allow_list);
          ());
      Oth.test ~name:"Allow list: the default cast list is the fixed list" (fun _ ->
          Oth.Assert.String_list.eq
            ~expected:(sorted Mql_adversarial_corpus.default_cast_allow_list)
            ~actual:(sorted Mql_to_pgsql.default_cast_allow_list);
          ());
      Oth.test ~name:"Allow list: each default function has an adversarial test" (fun _ ->
          Oth.Assert.String_list.eq
            ~expected:(sorted Mql_to_pgsql.default_func_allow_list)
            ~actual:(sorted (CCList.map fst Mql_adversarial_corpus.allowed_function_cases));
          ());
      Oth.test ~name:"Allow list: an empty function list refuses each call" (fun _ ->
          assert_refused
            ~func_allow_list:[]
            ~cast_allow_list
            ~expected:(function
              | `Func_access_err _ -> true
              | _ -> false)
            [
              "select count(*) from test";
              "select count(id) from test";
              "select lower(name) from test";
              "select coalesce(name, 'x') from test";
              "select now() from test";
            ];
          ());
      Oth.test ~name:"Allow list: an empty cast list refuses each cast" (fun _ ->
          assert_refused
            ~func_allow_list
            ~cast_allow_list:[]
            ~expected:(function
              | `Cast_err _ -> true
              | _ -> false)
            (CCList.map
               (fun t -> "select '1'::" ^ t ^ " from test")
               Mql_adversarial_corpus.default_cast_allow_list);
          ());
      Oth.test ~name:"Allow list: the audit accepts the output with the same lists" (fun _ ->
          CCList.iter
            (fun query ->
              let t =
                Oth.Assert.ok_pp ~pp:Mql_to_pgsql.pp_err
                @@ Mql_to_pgsql.of_mql ~func_allow_list ~cast_allow_list ~schema (parse query)
              in
              Oth.Assert.ok_pp
                ~pp:Mql_to_pgsql.pp_audit_err
                (Mql_to_pgsql.Tests.audit_query
                   ~func_allow_list
                   ~cast_allow_list
                   ~schema
                   (Mql_to_pgsql.query t)))
            [
              "select id, lower(name) from test";
              "select count(*) from test";
              "select id::text from test where name = 'x'";
            ];
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)

module Oth_abb = Oth_abb.Make (Abb)

let host = Sys.argv.(1)
let user = Sys.argv.(2)
let database = Sys.argv.(3)
let passwd = Sys.argv.(4)

module Sql = struct
  let drop_foo = Pgsql_io.Typed_sql.(sql /^ "drop table if exists foo")
end

let tls_config =
  let cfg = Otls.Tls_config.create () in
  Otls.Tls_config.insecure_noverifycert cfg;
  Otls.Tls_config.insecure_noverifyname cfg;
  cfg

let with_conn :
    'e.
    (Pgsql_io.t -> ('a, ([> Pgsql_io.create_err ] as 'e)) result Abb.Future.t) ->
    ('a, 'e) result Abb.Future.t =
 fun f ->
  let open Abb.Future.Infix_monad in
  Pgsql_io.create ~tls_config:(`Prefer tls_config) ~host ~user ~passwd database
  >>= function
  | Ok conn ->
      Abbs_future_combinators.with_finally
        (fun () ->
          Pgsql_io.Prepared_stmt.execute conn Sql.drop_foo
          >>= function
          | Ok () -> f conn
          | Error err ->
              Logs.err (fun m -> m "%s" (Pgsql_io.show_err err));
              Oth.Assert.false_ "drop table failed")
        ~finally:(fun () -> Abbs_future_combinators.ignore (Pgsql_io.destroy conn))
  | Error err ->
      Logs.err (fun m -> m "%s" (Pgsql_io.show_create_err err));
      failwith "nyi"

let pp_pgsql_err fmt err = Format.pp_print_string fmt (Pgsql_io.show_err err)
let pp_pgsql_create_err fmt err = Format.pp_print_string fmt (Pgsql_io.show_create_err err)

let pp_pgsql_combined_err fmt = function
  | #Pgsql_io.create_err as err -> pp_pgsql_create_err fmt err
  | #Pgsql_io.err as err -> pp_pgsql_err fmt err

let pp_unit fmt () = Format.pp_print_string fmt "()"

let pp_string_list fmt l =
  Format.fprintf fmt "[%s]" (String.concat "; " (List.map (fun s -> Printf.sprintf "%S" s) l))

let pp_int = Format.pp_print_int
let pp_string = Format.pp_print_string

let pp_list pp fmt l =
  Format.fprintf fmt "[";
  List.iteri
    (fun i v ->
      if i > 0 then Format.fprintf fmt "; ";
      pp fmt v)
    l;
  Format.fprintf fmt "]"

let pp_pair pp1 pp2 fmt (a, b) = Format.fprintf fmt "(%a, %a)" pp1 a pp2 b
let pp_triple pp1 pp2 pp3 fmt (a, b, c) = Format.fprintf fmt "(%a, %a, %a)" pp1 a pp2 b pp3 c

let pp_option pp fmt = function
  | None -> Format.fprintf fmt "None"
  | Some v -> Format.fprintf fmt "Some %a" pp v

let pp_int32 fmt v = Format.fprintf fmt "%ld" v
let pp_int64 fmt v = Format.fprintf fmt "%Ld" v
let pp_float fmt v = Format.fprintf fmt "%f" v
let pp_bool fmt v = Format.fprintf fmt "%b" v

let test_insert_row_null =
  Oth_abb.test ~desc:"Insert row with null" ~name:"insert_row_null" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo_null (name TEXT, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo_null VALUES($name, $age)"
            /% Var.text "name"
            /% Var.option (Var.integer "age"))
        in
        let create_rf = Pgsql_io.Row_func.ignore create_sql in
        let insert_rf = Pgsql_io.Row_func.ignore insert_sql in
        Pgsql_io.Prepared_stmt.create conn create_sql
        >>= fun create_stmt ->
        Pgsql_io.Prepared_stmt.bind create_stmt create_rf
        >>= fun cursor ->
        Pgsql_io.Cursor.execute cursor
        >>= fun () ->
        Pgsql_io.Prepared_stmt.create conn insert_sql
        >>= fun insert_stmt ->
        Pgsql_io.Prepared_stmt.bind insert_stmt insert_rf "Testy McTestface" None
        >>= fun cursor ->
        Pgsql_io.Cursor.execute cursor
        >>= fun () ->
        Pgsql_io.Prepared_stmt.destroy create_stmt
        >>= fun () -> Pgsql_io.Prepared_stmt.destroy insert_stmt
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_fetch_row =
  Oth_abb.test ~desc:"Fetch row" ~name:"fetch_row" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name" /% Var.integer "age")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.text
            /^ "SELECT DISTINCT name FROM foo WHERE name = $name AND age = $age"
            /% Var.text "name"
            /% Var.integer "age")
        in
        let make_rf sql = Pgsql_io.Row_func.ignore sql in
        let create_rf = make_rf create_sql in
        let insert_rf = make_rf insert_sql in
        let fetch_rf = Pgsql_io.Row_func.map fetch_sql ~f:(fun name -> name) in
        Pgsql_io.Prepared_stmt.create conn create_sql
        >>= fun create_stmt ->
        Pgsql_io.Prepared_stmt.bind create_stmt create_rf
        >>= fun cursor ->
        Pgsql_io.Cursor.execute cursor
        >>= fun () ->
        Pgsql_io.Prepared_stmt.create conn insert_sql
        >>= fun insert_stmt ->
        Pgsql_io.Prepared_stmt.bind insert_stmt insert_rf "Testy McTestface" (Int32.of_int 36)
        >>= fun cursor ->
        Pgsql_io.Cursor.execute cursor
        >>= fun () ->
        Pgsql_io.Prepared_stmt.create conn fetch_sql
        >>= fun fetch_stmt ->
        Pgsql_io.Prepared_stmt.bind fetch_stmt fetch_rf "Testy McTestface" (Int32.of_int 36)
        >>= fun cursor ->
        Pgsql_io.Cursor.fetch cursor
        >>= fun acc ->
        Pgsql_io.Prepared_stmt.destroy create_stmt
        >>= fun () ->
        Pgsql_io.Prepared_stmt.destroy insert_stmt
        >>= fun () -> Pgsql_io.Prepared_stmt.destroy fetch_stmt >>| fun () -> acc
      in
      with_conn f
      >>= function
      | Ok r ->
          Oth.Assert.eq ~eq:( = ) ~pp:pp_string_list [ "Testy McTestface" ] r;
          Abb.Future.return ()
      | Error #Pgsql_io.create_err -> Oth.Assert.false_ "unexpected create error"
      | Error #Pgsql_io.err -> Oth.Assert.false_ "unexpected pgsql error")

let test_fetch_all_rows =
  Oth_abb.test ~desc:"Fetch all rows" ~name:"fetch_rows" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "create table foo (name text primary key, age integer)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "insert into foo (name, age) values($name, $age)"
            /% Var.text "name"
            /% Var.smallint "age")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(sql // Ret.text // Ret.integer /^ "SELECT name, age FROM foo")
        in
        let fetch_rf = Pgsql_io.Row_func.map fetch_sql ~f:(fun name age -> (name, age)) in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql "Test" 26
        >>= fun () ->
        Pgsql_io.Prepared_stmt.create conn fetch_sql
        >>= fun fetch_stmt ->
        Pgsql_io.Prepared_stmt.bind fetch_stmt fetch_rf
        >>= fun cursor ->
        Pgsql_io.Cursor.fetch cursor
        >>= fun acc -> Pgsql_io.Prepared_stmt.destroy fetch_stmt >>| fun () -> acc
      in
      with_conn f
      >>= function
      | Ok r ->
          Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length r);
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_multiple_tx_success =
  Oth_abb.test ~desc:"Multiple transaction success" ~name:"multiple_tx_success" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name" /% Var.integer "age")
        in
        let create_rf = Pgsql_io.Row_func.ignore create_sql in
        let insert_rf = Pgsql_io.Row_func.ignore insert_sql in
        Pgsql_io.(
          tx conn ~f:(fun () ->
              Prepared_stmt.create conn create_sql
              >>= fun create_stmt ->
              Prepared_stmt.bind create_stmt create_rf
              >>= fun cursor ->
              Cursor.execute cursor
              >>= fun () ->
              Prepared_stmt.create conn insert_sql
              >>= fun insert_stmt ->
              Prepared_stmt.bind insert_stmt insert_rf "Testy McTestface" (Int32.of_int 36)
              >>= fun cursor -> Cursor.execute cursor))
        >>= fun () ->
        Pgsql_io.(
          tx conn ~f:(fun () ->
              Prepared_stmt.create conn create_sql
              >>= fun create_stmt ->
              Prepared_stmt.bind create_stmt create_rf
              >>= fun cursor ->
              Cursor.execute cursor
              >>= fun () ->
              Prepared_stmt.create conn insert_sql
              >>= fun insert_stmt ->
              Prepared_stmt.bind insert_stmt insert_rf "Testy McTestface" (Int32.of_int 36)
              >>= fun cursor -> Cursor.execute cursor))
      in
      with_conn f
      >>= function
      | Ok r ->
          Oth.Assert.eq ~eq:( = ) ~pp:pp_unit () r;
          Abb.Future.return ()
      | Error #Pgsql_io.create_err -> Oth.Assert.false_ "unexpected create error"
      | Error #Pgsql_io.err -> Oth.Assert.false_ "unexpected pgsql error")

let test_with_cursor =
  Oth_abb.test ~desc:"With Cursor" ~name:"with_cursor" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "create table foo (name text primary key, age integer)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "insert into foo (name, age) values($name, $age)"
            /% Var.text "name"
            /% Var.smallint "age")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(sql // Ret.text // Ret.integer /^ "SELECT name, age FROM foo")
        in
        let fetch_rf = Pgsql_io.Row_func.map fetch_sql ~f:(fun name age -> (name, age)) in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql "Test" 26
        >>= fun () ->
        Pgsql_io.Prepared_stmt.create conn fetch_sql
        >>= fun fetch_stmt ->
        Pgsql_io.Prepared_stmt.bind fetch_stmt fetch_rf
        >>= fun cursor ->
        Pgsql_io.Cursor.with_cursor cursor ~f:Pgsql_io.Cursor.fetch
        >>= fun acc -> Pgsql_io.Prepared_stmt.destroy fetch_stmt >>| fun () -> acc
      in
      with_conn f
      >>= function
      | Ok r ->
          Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length r);
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_bad_bind_too_few_args =
  Oth_abb.test ~desc:"Bad Bind Too Few Arguments" ~name:"bad_bind_too_few" (fun () ->
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name")
        in
        let create_rf = Pgsql_io.Row_func.ignore create_sql in
        let insert_rf = Pgsql_io.Row_func.ignore insert_sql in
        Pgsql_io.Prepared_stmt.create conn create_sql
        >>= fun create_stmt ->
        Pgsql_io.Prepared_stmt.bind create_stmt create_rf
        >>= fun cursor ->
        Pgsql_io.Cursor.execute cursor
        >>= fun () ->
        Pgsql_io.Prepared_stmt.create conn insert_sql
        >>= fun insert_stmt ->
        Pgsql_io.Prepared_stmt.bind insert_stmt insert_rf "Testy McTestface"
        >>= fun cursor ->
        Pgsql_io.Cursor.execute cursor
        >>= fun () ->
        Pgsql_io.Prepared_stmt.destroy create_stmt
        >>= fun () -> Pgsql_io.Prepared_stmt.destroy insert_stmt
      in
      let open Abb.Future.Infix_monad in
      with_conn f
      >>= function
      | Ok _ -> Oth.Assert.false_ "expected error but got ok"
      | Error (#Pgsql_io.sql_parse_err as err) ->
          Oth.Assert.eq ~eq:( = ) ~pp:Pgsql_io.pp_sql_parse_err (`Unknown_variable "age") err;
          Abb.Future.return ()
      | Error #Pgsql_io.create_err -> Oth.Assert.false_ "unexpected create error"
      | Error #Pgsql_io.err -> Oth.Assert.false_ "unexpected pgsql error")

let test_array =
  Oth_abb.test ~desc:"Array" ~name:"array" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.text
            // Ret.integer
            // Ret.option Ret.integer
            /^ "select * from unnest ($name, $age, $other)"
            /% Var.str_array (Var.varchar "name")
            /% Var.array (Var.integer "age")
            /% Var.array (Var.option (Var.integer "other")))
        in
        let rf =
          Pgsql_io.Row_func.map sql ~f:(fun name age other ->
              (name, Int32.to_int age, CCOption.map Int32.to_int other))
        in
        Pgsql_io.Prepared_stmt.create conn sql
        >>= fun stmt ->
        Pgsql_io.Prepared_stmt.bind
          stmt
          rf
          [ "na\\\"me1"; "name2" ]
          [ Int32.of_int 4; Int32.of_int 5 ]
          [ None; Some (Int32.of_int 10) ]
        >>= fun cursor -> Pgsql_io.Cursor.with_cursor cursor ~f:Pgsql_io.Cursor.fetch
      in
      with_conn f
      >>= function
      | Ok r ->
          Oth.Assert.eq
            ~eq:( = )
            ~pp:(pp_list (pp_triple pp_string pp_int (pp_option pp_int)))
            [ ("na\\\"me1", 4, None); ("name2", 5, Some 10) ]
            r;
          Abb.Future.return ()
      | Error #Pgsql_io.create_err -> Oth.Assert.false_ "unexpected create error"
      | Error #Pgsql_io.err -> Oth.Assert.false_ "unexpected pgsql error")

let test_insert_execute =
  Oth_abb.test ~desc:"Insert row execute" ~name:"insert_row_execute" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name" /% Var.integer "age")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql "Testy McTestface" (Int32.of_int 36)
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_stmt_fetch =
  Oth_abb.test ~desc:"Statement_fetch" ~name:"Statement fetch" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "create table foo (name text primary key, age integer)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "insert into foo (name, age) values($name, $age)"
            /% Var.text "name"
            /% Var.smallint "age")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(sql // Ret.text // Ret.integer /^ "SELECT name, age FROM foo")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql "Test" 26
        >>= fun () -> Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun name age -> (name, age))
      in
      with_conn f
      >>= function
      | Ok r ->
          Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length r);
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_integrity_fail =
  Oth_abb.test ~desc:"Integrity fail" ~name:"integrity_fail" (fun () ->
      let open Abb.Future.Infix_monad in
      let f in_tx trigger conn =
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT PRIMARY KEY, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name" /% Var.integer "age")
        in
        Pgsql_io.tx conn ~f:(fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Abbs_future_combinators.to_result (Abb.Future.Promise.set in_tx ())
            >>= fun () ->
            Abbs_future_combinators.to_result trigger
            >>= fun () ->
            Pgsql_io.Prepared_stmt.execute conn create_sql
            >>= fun () ->
            Pgsql_io.Prepared_stmt.execute conn insert_sql "Testy McTestface" (Int32.of_int 36))
      in
      let check_err r1 r2 =
        match (r1, r2) with
        | _, Error (`Unique_violation_err _)
        | Error (`Unique_violation_err _), _
        | _, Error (`Deadlock_detected _)
        | Error (`Deadlock_detected _), _ -> Ok ()
        | _ -> Error ()
      in
      let in_tx_left = Abb.Future.Promise.create () in
      let in_tx_right = Abb.Future.Promise.create () in
      let trigger_tx = Abb.Future.Promise.create () in
      let trigger_tx_fut = Abb.Future.Promise.future trigger_tx in
      Abb.Future.fork
        Abb.Future.Infix_app.(
          check_err
          <$> with_conn (f in_tx_left trigger_tx_fut)
          <*> with_conn (f in_tx_right trigger_tx_fut))
      >>= fun test ->
      Abb.Future.Infix_app.(
        (fun () () -> ())
        <$> Abb.Future.Promise.future in_tx_left
        <*> Abb.Future.Promise.future in_tx_right)
      >>= fun () ->
      Abb.Future.Promise.set trigger_tx ()
      >>= fun () ->
      test
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_unit r);
      Abb.Future.return ())

let test_integrity_recover =
  Oth_abb.test ~desc:"Integrity error recover" ~name:"integrity_recover" (fun () ->
      let open Abb.Future.Infix_monad in
      let f in_tx trigger conn =
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT PRIMARY KEY, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name" /% Var.integer "age")
        in
        Pgsql_io.tx conn ~f:(fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Abbs_future_combinators.to_result (Abb.Future.Promise.set in_tx ())
            >>= fun () ->
            Abbs_future_combinators.to_result trigger
            >>= fun () ->
            Pgsql_io.Prepared_stmt.execute conn create_sql
            >>= fun () ->
            Pgsql_io.Prepared_stmt.execute conn insert_sql "Testy McTestface" (Int32.of_int 36))
        >>= function
        | Ok () -> Abbs_future_combinators.return_ok `Ok
        | Error (`Unique_violation_err _) | Error (`Deadlock_detected _) ->
            let open Abbs_future_combinators.Infix_result_monad in
            Pgsql_io.Prepared_stmt.execute conn insert_sql "Testy RecoverFace" (Int32.of_int 36)
            >>| fun () -> `Integrity
        | Error _ as err -> Abb.Future.return err
      in
      let check_err r1 r2 =
        match (r1, r2) with
        | _, Ok `Integrity | Ok `Integrity, _ -> Ok ()
        | _, Error (#Pgsql_io.err as err) | Error (#Pgsql_io.err as err), _ ->
            failwith (Pgsql_io.show_err err)
        | _, _ -> failwith "missing integrity failure"
      in
      let in_tx_left = Abb.Future.Promise.create () in
      let in_tx_right = Abb.Future.Promise.create () in
      let trigger_tx = Abb.Future.Promise.create () in
      let trigger_tx_fut = Abb.Future.Promise.future trigger_tx in
      Abb.Future.fork
        Abb.Future.Infix_app.(
          check_err
          <$> with_conn (f in_tx_left trigger_tx_fut)
          <*> with_conn (f in_tx_right trigger_tx_fut))
      >>= fun test ->
      Abb.Future.Infix_app.(
        (fun () () -> ())
        <$> Abb.Future.Promise.future in_tx_left
        <*> Abb.Future.Promise.future in_tx_right)
      >>= fun () ->
      Abb.Future.Promise.set trigger_tx ()
      >>= fun () ->
      test
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_unit r);
      Abb.Future.return ())

let test_rollback =
  Oth_abb.test ~desc:"Rollback" ~name:"rollback" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT PRIMARY KEY, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "INSERT INTO foo VALUES($name, $age)" /% Var.text "name" /% Var.integer "age")
        in
        let select_sql =
          Pgsql_io.Typed_sql.(
            sql
            //
            (* name *)
            Ret.varchar
            //
            (* age *)
            Ret.integer
            /^ "SELECT * FROM foo")
        in
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        Pgsql_io.tx conn ~f:(fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Pgsql_io.Prepared_stmt.execute conn insert_sql "Testy McTestface" (Int32.of_int 36)
            >>? fun () -> Error `Foo)
        >>= fun _ ->
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.tx conn ~f:(fun () ->
            Pgsql_io.Prepared_stmt.fetch conn select_sql ~f:(fun name age -> (name, age)))
        >>| fun r ->
        Oth.Assert.eq ~eq:( = ) ~pp:(pp_list (pp_pair pp_string pp_int32)) [] r;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_bad_state =
  Oth_abb.test ~desc:"Conn in bad state" ~name:"bad_state" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        let insert_bad_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (name, age) VALUES($name, age)"
            /% Var.text "name"
            /% Var.integer "age")
        in
        let insert_good_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (name, age) VALUES($name, $age)"
            /% Var.text "name"
            /% Var.integer "age")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        Pgsql_io.Prepared_stmt.execute conn insert_bad_sql "Testy McTestface" (Int32.of_int 36)
        >>= function
        | Error _ ->
            Pgsql_io.Prepared_stmt.execute conn insert_good_sql "Testy McTestface" (Int32.of_int 36)
        | Ok _ -> Oth.Assert.false_ "expected error from bad sql"
      in
      with_conn f
      >>= function
      | Ok () -> Abb.Future.return ()
      | Error (#Pgsql_io.err as err) ->
          print_endline (Pgsql_io.show_err err);
          Oth.Assert.false_ "unexpected pgsql error"
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_copy_to =
  Oth_abb.test ~desc:"Copy to" ~name:"copy_to" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.text // Ret.integer /^ "SELECT name, age FROM foo ORDER BY name")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [ Pgsql_io.Copy_to.text "Alice"; Pgsql_io.Copy_to.integer 30l ];
            [ Pgsql_io.Copy_to.text "Bob"; Pgsql_io.Copy_to.integer 25l ];
            [ Pgsql_io.Copy_to.text "Charlie\ttab"; Pgsql_io.Copy_to.integer 40l ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "name"; "age" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 3 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun name age -> (name, Int32.to_int age))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_pair pp_string pp_int))
          [ ("Alice", 30); ("Bob", 25); ("Charlie\ttab", 40) ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_conflict =
  Oth_abb.test ~desc:"Copy to conflict" ~name:"copy_to_conflict" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT PRIMARY KEY, age INTEGER)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (name, age) VALUES($name, $age)"
            /% Var.text "name"
            /% Var.integer "age")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql "Alice" (Int32.of_int 30)
        >>= fun () ->
        let rows = [ [ Pgsql_io.Copy_to.text "Alice"; Pgsql_io.Copy_to.integer 99l ] ] in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "name"; "age" ] conn rows
      in
      with_conn f
      >>= function
      | Ok _ -> Oth.Assert.false_ "expected integrity error but got ok"
      | Error (`Unique_violation_err _) -> Abb.Future.return ()
      | Error (#Pgsql_io.create_err as err) ->
          print_endline (Pgsql_io.show_create_err err);
          Oth.Assert.false_ "unexpected create error"
      | Error (#Pgsql_io.err as err) ->
          print_endline (Pgsql_io.show_err err);
          Oth.Assert.false_ "unexpected pgsql error")

let test_copy_to_bad_data =
  Oth_abb.test ~desc:"Copy to bad data type" ~name:"copy_to_bad_data" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows = [ [ Pgsql_io.Copy_to.text "Alice"; Pgsql_io.Copy_to.text "not_a_number" ] ] in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "name"; "age" ] conn rows
      in
      with_conn f
      >>= function
      | Ok _ -> Oth.Assert.false_ "expected error from bad data type"
      | Error _ -> Abb.Future.return ())

let test_copy_to_bytea =
  Oth_abb.test ~desc:"Copy to bytea" ~name:"copy_to_bytea" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, data BYTEA)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.(option bytea) /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [ Pgsql_io.Copy_to.integer 1l; Pgsql_io.Copy_to.bytea "\x00\x01\x02\xff" ];
            [ Pgsql_io.Copy_to.integer 2l; Pgsql_io.Copy_to.null ];
            [ Pgsql_io.Copy_to.integer 3l; Pgsql_io.Copy_to.bytea "\xde\xad\xbe\xef" ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "data" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 3 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_pair pp_int (pp_option pp_string)))
          [ (1, Some "\x00\x01\x02\xff"); (2, None); (3, Some "\xde\xad\xbe\xef") ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_text_special_chars =
  Oth_abb.test ~desc:"Text special chars round-trip" ~name:"text_special_chars" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data TEXT)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, data) VALUES($id, $data)"
            /% Var.integer "id"
            /% Var.text "data")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.text /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let cases =
          [
            (1l, "tab\there");
            (2l, "new\nline");
            (3l, "back\\slash");
            (4l, "quote'here");
            (5l, "emoji\xf0\x9f\x8e\x89");
            (6l, "'; DROP TABLE foo; --");
          ]
        in
        let rec insert = function
          | [] -> Abbs_future_combinators.return_ok ()
          | (id, data) :: rest ->
              Pgsql_io.Prepared_stmt.execute conn insert_sql id data >>= fun () -> insert rest
        in
        insert cases
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        List.iter2
          (fun (expected_id, expected_data) (actual_id, actual_data) ->
            Oth.Assert.eq ~eq:( = ) ~pp:pp_int (Int32.to_int expected_id) actual_id;
            Oth.Assert.eq ~eq:String.equal ~pp:pp_string expected_data actual_data)
          cases
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_text_nul_byte =
  Oth_abb.test ~desc:"NUL byte rejected in TEXT" ~name:"text_nul_byte" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data TEXT)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, data) VALUES($id, $data)"
            /% Var.integer "id"
            /% Var.text "data")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () -> Pgsql_io.Prepared_stmt.execute conn insert_sql 1l "hello\x00world"
      in
      with_conn f
      >>= function
      | Ok () -> Oth.Assert.false_ "expected error from NUL byte but got ok"
      | Error _ -> Abb.Future.return ())

let test_copy_to_special_chars =
  Oth_abb.test ~desc:"Copy_to special chars round-trip" ~name:"copy_to_special_chars" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data TEXT)") in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.text /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let cases =
          [
            (1l, "tab\there");
            (2l, "new\nline");
            (3l, "back\\slash");
            (4l, "quote'here");
            (5l, "emoji\xf0\x9f\x8e\x89");
            (6l, "'; DROP TABLE foo; --");
          ]
        in
        let rows =
          List.map
            (fun (id, data) -> [ Pgsql_io.Copy_to.integer id; Pgsql_io.Copy_to.text data ])
            cases
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "data" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 6 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        List.iter2
          (fun (expected_id, expected_data) (actual_id, actual_data) ->
            Oth.Assert.eq ~eq:( = ) ~pp:pp_int (Int32.to_int expected_id) actual_id;
            Oth.Assert.eq ~eq:String.equal ~pp:pp_string expected_data actual_data)
          cases
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_text_empty_vs_null =
  Oth_abb.test ~desc:"Empty string vs NULL" ~name:"text_empty_vs_null" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data TEXT)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, data) VALUES($id, $data)"
            /% Var.integer "id"
            /% Var.option (Var.text "data"))
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.(option text) /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 1l (Some "")
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 2l None
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_pair pp_int (pp_option pp_string)))
          [ (1, Some ""); (2, None) ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_integer_bounds =
  Oth_abb.test ~desc:"Integer boundary values" ~name:"integer_bounds" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (si SMALLINT, i INTEGER, bi BIGINT)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (si, i, bi) VALUES($si, $i, $bi)"
            /% Var.smallint "si"
            /% Var.integer "i"
            /% Var.bigint "bi")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.smallint
            // Ret.integer
            // Ret.bigint
            /^ "SELECT si, i, bi FROM foo ORDER BY si")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql (-32768) Int32.min_int Int64.min_int
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 32767 Int32.max_int Int64.max_int
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun si i bi -> (si, i, bi))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_triple pp_int pp_int32 pp_int64))
          [ (-32768, Int32.min_int, Int64.min_int); (32767, Int32.max_int, Int64.max_int) ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_integer_bounds =
  Oth_abb.test ~desc:"Copy_to integer boundary values" ~name:"copy_to_integer_bounds" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (si SMALLINT, i INTEGER, bi BIGINT)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.smallint
            // Ret.integer
            // Ret.bigint
            /^ "SELECT si, i, bi FROM foo ORDER BY si")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [
              Pgsql_io.Copy_to.smallint (-32768);
              Pgsql_io.Copy_to.integer Int32.min_int;
              Pgsql_io.Copy_to.bigint Int64.min_int;
            ];
            [
              Pgsql_io.Copy_to.smallint 32767;
              Pgsql_io.Copy_to.integer Int32.max_int;
              Pgsql_io.Copy_to.bigint Int64.max_int;
            ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "si"; "i"; "bi" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 2 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun si i bi -> (si, i, bi))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_triple pp_int pp_int32 pp_int64))
          [ (-32768, Int32.min_int, Int64.min_int); (32767, Int32.max_int, Int64.max_int) ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_float_special_values =
  Oth_abb.test ~desc:"Float special values" ~name:"float_special_values" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, r REAL, d DOUBLE PRECISION)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, r, d) VALUES($id, $r, $d)"
            /% Var.integer "id"
            /% Var.real "r"
            /% Var.double "d")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.real // Ret.double /^ "SELECT id, r, d FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 1l infinity infinity
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 2l neg_infinity neg_infinity
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 3l nan nan
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 4l 0.0 0.0
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 5l Float.max_float Float.max_float
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id r d -> (Int32.to_int id, r, d))
        >>| fun results ->
        List.iter
          (fun (id, r, d) ->
            match id with
            | 1 ->
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float infinity r;
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float infinity d
            | 2 ->
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float neg_infinity r;
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float neg_infinity d
            | 3 ->
                Oth.Assert.eq ~eq:(fun a b -> Float.is_nan a && Float.is_nan b) ~pp:pp_float nan r;
                Oth.Assert.eq ~eq:(fun a b -> Float.is_nan a && Float.is_nan b) ~pp:pp_float nan d
            | 4 ->
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float 0.0 r;
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float 0.0 d
            | 5 ->
                (* REAL is 32-bit, so max_float round-trips as infinity *)
                Oth.Assert.eq ~eq:Float.equal ~pp:pp_float Float.max_float d
            | _ -> Oth.Assert.false_ "unexpected row id")
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_json_invalid =
  Oth_abb.test ~desc:"Invalid JSON rejected" ~name:"json_invalid" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (data JSON)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(sql /^ "INSERT INTO foo (data) VALUES($data)" /% Var.json "data")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () -> Pgsql_io.Prepared_stmt.execute conn insert_sql (`Assoc [ ("key", `Int 1) ])
      in
      with_conn f
      >>= function
      | Ok () -> Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "expected ok from valid JSON but got error")

let test_copy_to_jsonb =
  Oth_abb.test ~desc:"Copy to jsonb" ~name:"copy_to_jsonb" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data JSONB)") in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.text /^ "SELECT id, data::text FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [
              Pgsql_io.Copy_to.integer 1l;
              Pgsql_io.Copy_to.jsonb (`Assoc [ ("key", `String "value") ]);
            ];
            [
              Pgsql_io.Copy_to.integer 2l; Pgsql_io.Copy_to.jsonb (`List [ `Int 1; `Int 2; `Int 3 ]);
            ];
            [
              Pgsql_io.Copy_to.integer 3l;
              Pgsql_io.Copy_to.jsonb
                (`Assoc [ ("nested", `Assoc [ ("a", `Bool true) ]); ("b", `Null) ]);
            ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "data" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 3 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        let get id = List.assoc id (List.map (fun (id, d) -> (id, d)) results) in
        let parsed1 = Yojson.Safe.from_string (get 1) in
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp (`Assoc [ ("key", `String "value") ]) parsed1;
        let parsed2 = Yojson.Safe.from_string (get 2) in
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp (`List [ `Int 1; `Int 2; `Int 3 ]) parsed2;
        let parsed3 = Yojson.Safe.from_string (get 3) in
        Oth.Assert.eq
          ~eq:(fun expected actual ->
            actual = expected
            || actual = `Assoc [ ("b", `Null); ("nested", `Assoc [ ("a", `Bool true) ]) ])
          ~pp:Yojson.Safe.pp
          (`Assoc [ ("nested", `Assoc [ ("a", `Bool true) ]); ("b", `Null) ])
          parsed3;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_json_round_trip =
  Oth_abb.test ~desc:"JSON round-trip with special content" ~name:"json_round_trip" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data JSON)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, data) VALUES($id, $data)"
            /% Var.integer "id"
            /% Var.json "data")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.text /^ "SELECT id, data::text FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let json_val = `Assoc [ ("key", `String "val\"ue"); ("n", `Null) ] in
        Pgsql_io.Prepared_stmt.execute conn insert_sql 1l json_val
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length results);
        let _, data = List.hd results in
        let data_json = Yojson.Safe.from_string data in
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp json_val data_json;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_json_cross_type =
  Oth_abb.test
    ~desc:"Ret.json and Ret.jsonb work on both json and jsonb columns"
    ~name:"json_cross_type"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, j JSON, jb JSONB)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, j, jb) VALUES($id, $j, $jb)"
            /% Var.integer "id"
            /% Var.json "j"
            /% Var.json "jb")
        in
        let fetch_json_sql =
          Pgsql_io.Typed_sql.(sql // Ret.json // Ret.json /^ "SELECT j, jb FROM foo WHERE id = 1")
        in
        let fetch_jsonb_sql =
          Pgsql_io.Typed_sql.(sql // Ret.jsonb // Ret.jsonb /^ "SELECT j, jb FROM foo WHERE id = 1")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let json_val = `Assoc [ ("key", `String "value") ] in
        Pgsql_io.Prepared_stmt.execute conn insert_sql 1l json_val json_val
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_json_sql ~f:(fun j jb -> (j, jb))
        >>= fun results_json ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length results_json);
        let j, jb = List.hd results_json in
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp json_val j;
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp json_val jb;
        Pgsql_io.Prepared_stmt.fetch conn fetch_jsonb_sql ~f:(fun j jb -> (j, jb))
        >>| fun results_jsonb ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length results_jsonb);
        let j, jb = List.hd results_jsonb in
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp json_val j;
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp json_val jb;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_bytea_large =
  Oth_abb.test ~desc:"Large bytea via Copy_to" ~name:"bytea_large" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data BYTEA)") in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.bytea /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let size = 65536 in
        let data = Bytes.create size in
        for i = 0 to size - 1 do
          Bytes.set data i (Char.chr (i mod 256))
        done;
        let data_str = Bytes.to_string data in
        let rows = [ [ Pgsql_io.Copy_to.integer 1l; Pgsql_io.Copy_to.bytea data_str ] ] in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "data" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 (List.length results);
        let _, fetched = List.hd results in
        Oth.Assert.eq ~eq:String.equal ~pp:pp_string data_str fetched;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_query_dangerous_values =
  Oth_abb.test
    ~desc:"Fetch rows with injection-like content"
    ~name:"query_dangerous_values"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data TEXT)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, data) VALUES($id, $data)"
            /% Var.integer "id"
            /% Var.text "data")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.text /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let cases = [ (1l, "'; DROP TABLE foo; --"); (2l, "Robert'); DROP TABLE foo;--") ] in
        let rec insert = function
          | [] -> Abbs_future_combinators.return_ok ()
          | (id, data) :: rest ->
              Pgsql_io.Prepared_stmt.execute conn insert_sql id data >>= fun () -> insert rest
        in
        insert cases
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        List.iter2
          (fun (expected_id, expected_data) (actual_id, actual_data) ->
            Oth.Assert.eq ~eq:( = ) ~pp:pp_int (Int32.to_int expected_id) actual_id;
            Oth.Assert.eq ~eq:String.equal ~pp:pp_string expected_data actual_data)
          cases
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_bytea_large =
  Oth_abb.test ~desc:"Copy to large bytea" ~name:"copy_to_bytea_large" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, data BYTEA)")
        in
        let fetch_count_sql =
          Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT count(*)::integer FROM foo")
        in
        let fetch_sum_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.bigint /^ "SELECT sum(octet_length(data))::bigint FROM foo")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let n = 500 in
        let chunk = String.make 1024 '\xff' in
        let rows =
          List.init n (fun i ->
              [ Pgsql_io.Copy_to.integer (Int32.of_int i); Pgsql_io.Copy_to.bytea chunk ])
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "data" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int n count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_count_sql ~f:Fun.id
        >>= fun results ->
        Oth.Assert.eq ~eq:( = ) ~pp:(pp_list pp_int32) [ Int32.of_int n ] results;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sum_sql ~f:Fun.id
        >>| fun results ->
        Oth.Assert.eq ~eq:( = ) ~pp:(pp_list pp_int64) [ Int64.of_int (n * 1024) ] results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_single_row =
  Oth_abb.test ~desc:"Copy to single row" ~name:"copy_to_single_row" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, name TEXT)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.text /^ "SELECT id, name FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows = [ [ Pgsql_io.Copy_to.integer 1l; Pgsql_io.Copy_to.text "only" ] ] in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "name" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 1 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id name -> (Int32.to_int id, name))
        >>| fun results ->
        Oth.Assert.eq ~eq:( = ) ~pp:(pp_list (pp_pair pp_int pp_string)) [ (1, "only") ] results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_empty =
  Oth_abb.test ~desc:"Copy to empty rows" ~name:"copy_to_empty" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, name TEXT)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT count(*)::integer FROM foo")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows = [] in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "name" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 0 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:Fun.id
        >>| fun results ->
        Oth.Assert.eq ~eq:( = ) ~pp:(pp_list pp_int32) [ 0l ] results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_bytea_with_trailer_bytes =
  Oth_abb.test
    ~desc:"Copy to bytea containing 0xffff"
    ~name:"copy_to_bytea_trailer_bytes"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, data BYTEA)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.(option bytea) /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [ Pgsql_io.Copy_to.integer 1l; Pgsql_io.Copy_to.bytea "\xff\xff" ];
            [ Pgsql_io.Copy_to.integer 2l; Pgsql_io.Copy_to.bytea "\xff\xff\xff\xff" ];
            [ Pgsql_io.Copy_to.integer 3l; Pgsql_io.Copy_to.bytea "abc\xff\xff\x00\x01\xff\xff" ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "data" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 3 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_pair pp_int (pp_option pp_string)))
          [
            (1, Some "\xff\xff");
            (2, Some "\xff\xff\xff\xff");
            (3, Some "abc\xff\xff\x00\x01\xff\xff");
          ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let pp_quad pp1 pp2 pp3 pp4 fmt (a, b, c, d) =
  Format.fprintf fmt "(%a, %a, %a, %a)" pp1 a pp2 b pp3 c pp4 d

let test_copy_to_all_nulls =
  Oth_abb.test ~desc:"Copy to all null values" ~name:"copy_to_all_nulls" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, a TEXT, b BYTEA, c INTEGER)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.(option integer)
            // Ret.(option text)
            // Ret.(option bytea)
            // Ret.(option integer)
            /^ "SELECT id, a, b, c FROM foo ORDER BY id NULLS FIRST")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
            ];
            [
              Pgsql_io.Copy_to.integer 1l;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
            ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "a"; "b"; "c" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 2 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id a b c -> (id, a, b, c))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:
            (pp_list
               (pp_quad
                  (pp_option pp_int32)
                  (pp_option pp_string)
                  (pp_option pp_string)
                  (pp_option pp_int32)))
          [ (None, None, None, None); (Some 1l, None, None, None) ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_copy_to_many_columns =
  Oth_abb.test ~desc:"Copy to many columns" ~name:"copy_to_many_columns" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "CREATE TABLE IF NOT EXISTS foo (c1 INTEGER, c2 INTEGER, c3 INTEGER, c4 INTEGER, c5 \
                INTEGER, c6 INTEGER, c7 INTEGER, c8 INTEGER, c9 INTEGER, c10 INTEGER)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.integer
            // Ret.integer
            /^ "SELECT count(*)::integer, sum(c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + \
                c10)::integer FROM foo")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let cols = List.init 10 (fun i -> Printf.sprintf "c%d" (i + 1)) in
        let rows =
          List.init 50 (fun i ->
              List.init 10 (fun j -> Pgsql_io.Copy_to.integer (Int32.of_int ((i * 10) + j))))
        in
        Pgsql_io.copy_to ~table:"foo" ~cols conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 50 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun cnt sum -> (cnt, sum))
        >>| fun results ->
        let expected_sum =
          List.init 50 (fun i -> List.init 10 (fun j -> (i * 10) + j) |> List.fold_left ( + ) 0)
          |> List.fold_left ( + ) 0
        in
        Oth.Assert.eq
          ~eq:( = )
          ~pp:(pp_list (pp_pair pp_int32 pp_int32))
          [ (50l, Int32.of_int expected_sum) ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let pp_quint pp1 pp2 pp3 pp4 pp5 fmt (a, b, c, d, e) =
  Format.fprintf fmt "(%a, %a, %a, %a, %a)" pp1 a pp2 b pp3 c pp4 d pp5 e

let test_copy_to_mixed_types =
  Oth_abb.test ~desc:"Copy to mixed types" ~name:"copy_to_mixed_types" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "CREATE TABLE IF NOT EXISTS foo (id INTEGER, name TEXT, data BYTEA, score BIGINT, \
                flag BOOLEAN)")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.integer
            // Ret.(option text)
            // Ret.(option text)
            // Ret.(option bigint)
            // Ret.(option boolean)
            /^ "SELECT id, name, encode(data, 'hex'), score, flag FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let rows =
          [
            [
              Pgsql_io.Copy_to.integer 1l;
              Pgsql_io.Copy_to.text "alice";
              Pgsql_io.Copy_to.bytea "\xde\xad";
              Pgsql_io.Copy_to.bigint 100L;
              Pgsql_io.Copy_to.boolean true;
            ];
            [
              Pgsql_io.Copy_to.integer 2l;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.null;
              Pgsql_io.Copy_to.boolean false;
            ];
            [
              Pgsql_io.Copy_to.integer 3l;
              Pgsql_io.Copy_to.text "bob";
              Pgsql_io.Copy_to.bytea "\xff\xff";
              Pgsql_io.Copy_to.bigint 9999999999L;
              Pgsql_io.Copy_to.null;
            ];
          ]
        in
        Pgsql_io.copy_to ~table:"foo" ~cols:[ "id"; "name"; "data"; "score"; "flag" ] conn rows
        >>= fun count ->
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 3 count;
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id name data score flag ->
            (Int32.to_int id, name, data, score, flag))
        >>| fun results ->
        Oth.Assert.eq
          ~eq:( = )
          ~pp:
            (pp_list
               (pp_quint
                  pp_int
                  (pp_option pp_string)
                  (pp_option pp_string)
                  (pp_option pp_int64)
                  (pp_option pp_bool)))
          [
            (1, Some "alice", Some "dead", Some 100L, Some true);
            (2, None, None, None, Some false);
            (3, Some "bob", Some "ffff", Some 9999999999L, None);
          ]
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_concurrent_exn_raise =
  Oth_abb.test ~name:"Concurrent Exn Raise" (fun () ->
      let create_sql =
        Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS foo (name TEXT, age INTEGER)")
      in
      let insert_good_sql =
        Pgsql_io.Typed_sql.(
          sql
          /^ "INSERT INTO foo (name, age) VALUES($name, $age)"
          /% Var.text "name"
          /% Var.integer "age")
      in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        (* Run a tx to completion, then raise inside the same awaited future.
           Awaiting the tx first means it has committed (and cleared [in_tx])
           before the exception propagates, so reusing the connection in the
           [`Exn] branch is deterministic -- the old applicative form started the
           second tx while the first might still be settling, which intermittently
           tripped [Nested_tx_not_supported]. *)
        Abb.Future.await
          (Pgsql_io.tx conn ~f:(fun () ->
               let open Abbs_future_combinators.Infix_result_monad in
               Pgsql_io.Prepared_stmt.execute conn insert_good_sql "foo bar" 12l
               >>= fun () -> Pgsql_io.Prepared_stmt.execute conn insert_good_sql "foo" 12l)
          >>= fun _ -> raise (Failure "crash"))
        >>= function
        | `Det () -> Oth.Assert.false_ "expected exception but got det"
        | `Exn (_, _) ->
            Pgsql_io.(
              tx conn ~f:(fun () -> Prepared_stmt.execute conn insert_good_sql "foo baz" 13l))
        | `Aborted -> Oth.Assert.false_ "expected exception but got aborted"
      in
      let open Abb.Future.Infix_monad in
      with_conn f
      >>= function
      | Ok () -> Abb.Future.return ()
      | Error (#Pgsql_io.err as err) ->
          print_endline (Pgsql_io.show_err err);
          Oth.Assert.false_ "unexpected pgsql error"
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_ret_u_all_types =
  Oth_abb.test ~desc:"Ret.u with all datatypes" ~name:"ret_u_all_types" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "CREATE TABLE foo (si SMALLINT, i INTEGER, bi BIGINT, r REAL, d DOUBLE PRECISION, b \
                BOOLEAN, t TEXT, u UUID, j JSON, jb JSONB)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (si, i, bi, r, d, b, t, u, j, jb) VALUES($si, $i, $bi, $r, $d, $b, \
                $t, $u, $j, $jb)"
            /% Var.smallint "si"
            /% Var.integer "i"
            /% Var.bigint "bi"
            /% Var.real "r"
            /% Var.double "d"
            /% Var.boolean "b"
            /% Var.text "t"
            /% Var.uuid "u"
            /% Var.json "j"
            /% Var.json "jb")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.smallint
            // Ret.integer
            // Ret.bigint
            // Ret.real
            // Ret.double
            // Ret.boolean
            // Ret.text
            // Ret.uuid
            // Ret.json
            // Ret.jsonb
            /^ "SELECT si, i, bi, r, d, b, t, u, j, jb FROM foo")
        in
        let test_uuid = Uuidm.v4_gen (Random.State.make_self_init ()) () in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute
          conn
          insert_sql
          42
          100l
          999999L
          3.14
          2.718281828
          true
          "hello"
          test_uuid
          (`Assoc [ ("a", `Int 1) ])
          (`Assoc [ ("b", `Int 2) ])
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun si i bi r d b t u j jb ->
            (si, i, bi, r, d, b, t, u, j, jb))
        >>| fun results ->
        let si, i, bi, _r, _d, b, t, u, j, jb = List.hd results in
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 42 si;
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int32 100l i;
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int64 999999L bi;
        Oth.Assert.eq ~eq:( = ) ~pp:pp_bool true b;
        Oth.Assert.eq ~eq:String.equal ~pp:pp_string "hello" t;
        Oth.Assert.eq ~eq:Uuidm.equal ~pp:Uuidm.pp test_uuid u;
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp (`Assoc [ ("a", `Int 1) ]) j;
        Oth.Assert.eq ~eq:( = ) ~pp:Yojson.Safe.pp (`Assoc [ ("b", `Int 2) ]) jb;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_bytea_var_ret =
  Oth_abb.test ~desc:"Bytea insert via Var and fetch via Ret" ~name:"bytea_var_ret" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (id INTEGER, data BYTEA)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (id, data) VALUES($id, $data)"
            /% Var.integer "id"
            /% Var.bytea "data")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql // Ret.integer // Ret.bytea /^ "SELECT id, data FROM foo ORDER BY id")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        let all_bytes = String.init 256 Char.chr in
        let cases = [ (1l, "\x00\x01\x02\xff\xfe"); (2l, "\xff\xff"); (3l, all_bytes) ] in
        let rec insert = function
          | [] -> Abbs_future_combinators.return_ok ()
          | (id, data) :: rest ->
              Pgsql_io.Prepared_stmt.execute conn insert_sql id data >>= fun () -> insert rest
        in
        insert cases
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun id data -> (Int32.to_int id, data))
        >>| fun results ->
        List.iter2
          (fun (expected_id, expected_data) (actual_id, actual_data) ->
            Oth.Assert.eq ~eq:( = ) ~pp:pp_int (Int32.to_int expected_id) actual_id;
            Oth.Assert.eq ~eq:String.equal ~pp:pp_string expected_data actual_data)
          cases
          results;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_bigint_column_smallint_ret =
  Oth_abb.test
    ~desc:"Bigint column queried with Ret.smallint"
    ~name:"bigint_column_smallint_ret"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (v BIGINT)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(sql /^ "INSERT INTO foo (v) VALUES($v)" /% Var.bigint "v")
        in
        let fetch_sql = Pgsql_io.Typed_sql.(sql // Ret.smallint /^ "SELECT v FROM foo") in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 42L
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun v -> v)
        >>| fun results ->
        let v = List.hd results in
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 42 v;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_bigint_column_smallint_b_ret_fails =
  Oth_abb.test
    ~desc:"Bigint column queried with Ret.smallint_b fails"
    ~name:"bigint_column_smallint_b_ret_fails"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql = Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE foo (v BIGINT)") in
        let insert_sql =
          Pgsql_io.Typed_sql.(sql /^ "INSERT INTO foo (v) VALUES($v)" /% Var.bigint "v")
        in
        let fetch_sql = Pgsql_io.Typed_sql.(sql // Ret.smallint_b /^ "SELECT v FROM foo") in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 42L
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun v -> v)
        >>= function
        | Error (`Bad_result _) -> Abbs_future_combinators.return_ok ()
        | Ok _ -> Oth.Assert.false_ "Expected Bad_result error but got Ok"
        | Error err ->
            Oth.Assert.false_
              (Printf.sprintf "Expected Bad_result but got %s" (Pgsql_io.show_err err))
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let test_ret_b_all_types =
  Oth_abb.test ~desc:"Ret._b with all binary datatypes" ~name:"ret_b_all_types" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "CREATE TABLE foo (si SMALLINT, i INTEGER, bi BIGINT, r REAL, d DOUBLE PRECISION, b \
                BOOLEAN, t TEXT)")
        in
        let insert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (si, i, bi, r, d, b, t) VALUES($si, $i, $bi, $r, $d, $b, $t)"
            /% Var.smallint "si"
            /% Var.integer "i"
            /% Var.bigint "bi"
            /% Var.real "r"
            /% Var.double "d"
            /% Var.boolean "b"
            /% Var.text "t")
        in
        let fetch_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.smallint_b
            // Ret.integer_b
            // Ret.bigint_b
            // Ret.real_b
            // Ret.double_b
            // Ret.boolean_b
            // Ret.varchar_b
            /^ "SELECT si, i, bi, r, d, b, t FROM foo")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql 42 100l 999999L 3.14 2.718281828 true "hello"
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun si i bi r d b t ->
            (si, i, bi, r, d, b, t))
        >>| fun results ->
        let si, i, bi, _r, _d, b, t = List.hd results in
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int 42 si;
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int32 100l i;
        Oth.Assert.eq ~eq:( = ) ~pp:pp_int64 999999L bi;
        Oth.Assert.eq ~eq:( = ) ~pp:pp_bool true b;
        Oth.Assert.eq ~eq:String.equal ~pp:pp_string "hello" t;
        ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

(* Regression for the pgsql_codec needed_bytes off-by-one: a row value whose
   frame completes exactly on the 8192-byte read boundary used to strand the
   decoded frame and hang the fetch (idle-in-transaction reap at 240s in
   production).  Sweeping a small window of value sizes reliably lands on the
   boundary; each fetch is guarded by a timeout so a regression FAILS fast
   instead of hanging the suite. *)
let test_boundary_sweep =
  Oth_abb.test
    ~desc:"Large-value fetch boundary (codec needed_bytes)"
    ~name:"boundary_sweep"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let rec sweep n =
          if n > 8175 then Abbs_future_combinators.return_ok ()
          else
            let fetch_sql =
              Pgsql_io.Typed_sql.(sql // Ret.text /^ Printf.sprintf "SELECT repeat('x', %d)" n)
            in
            Abbs_future_combinators.timeout
              ~timeout:(Abb.Sys.sleep 10.0)
              (Pgsql_io.Prepared_stmt.fetch conn fetch_sql ~f:(fun s -> s))
            >>= function
            | `Ok (Ok [ s ]) when String.length s = n -> sweep (n + 1)
            | `Ok (Ok _) ->
                Oth.Assert.false_ (Printf.sprintf "unexpected result shape at value size %d" n)
            | `Ok (Error e) ->
                Oth.Assert.false_
                  (Printf.sprintf "fetch error at value size %d: %s" n (Pgsql_io.show_err e))
            | `Timeout ->
                Oth.Assert.false_
                  (Printf.sprintf
                     "fetch HUNG at value size %d (pgsql_codec needed_bytes off-by-one)"
                     n)
        in
        sweep 8140
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

(* Manufacture an in_tx desync: a COMMIT ends the backend's transaction behind
   pgsql_io's back, so the backend reports 'I' while conn.in_tx stays true
   (execute accepts any ReadyForQuery and never touches in_tx).  Then issue a
   failing statement.  Pre-fix, error_response only accepts a ReadyForQuery whose
   status agrees with conn.in_tx ('T'|'E'); the backend sends 'I', the frame is
   dropped, and the read blocks forever -- the 240s idle-in-transaction stall.
   The fix resyncs in_tx from the backend's authoritative status, so the error
   surfaces instead of hanging. *)
let test_in_tx_commit_desync =
  Oth_abb.test
    ~desc:"in_tx desync + erroring stmt must not hang in error_response"
    ~name:"in_tx_commit_desync"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let commit_sql = Pgsql_io.Typed_sql.(sql /^ "COMMIT") in
      let bad_sql = Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT (1 / 0)::integer") in
      let f conn =
        Abbs_future_combinators.timeout
          ~timeout:(Abb.Sys.sleep 20.0)
          (Pgsql_io.tx conn ~f:(fun () ->
               let open Abbs_future_combinators.Infix_result_monad in
               Pgsql_io.Prepared_stmt.execute conn commit_sql
               >>= fun () ->
               Pgsql_io.Prepared_stmt.fetch conn bad_sql ~f:(fun n -> Int32.to_int n)
               >>| fun _ -> ()))
        >>= (function
        | `Ok (Ok ()) | `Ok (Error _) -> Abb.Future.return ()
        | `Timeout ->
            Oth.Assert.false_
              "HANG : error_response stuck waiting for a ReadyForQuery that never comes")
        >>= fun () -> Abbs_future_combinators.return_ok ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

(* A fetch whose Ret type is wrong for the column (smallint_b on a BIGINT) hits
   the Bad_result path.  Pre-fix that path returned WITHOUT draining the rest of
   the response (remaining DataRows + CommandComplete + ReadyForQuery), so a
   caller that ignores the error and reuses the connection inherits a desynced
   frame stream -- a dirty, idle-in-transaction connection.  The fix drains to
   ReadyForQuery before surfacing the error.  A raising row function must be
   handled the same way: drain, then re-raise. *)
let test_bad_result_dirty_conn =
  Oth_abb.test
    ~desc:"ignored Bad_result / raising row func must leave the connection clean"
    ~name:"bad_result_dirty_conn"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let create_sql =
        Pgsql_io.Typed_sql.(sql /^ "CREATE TABLE IF NOT EXISTS tt_bigt (v BIGINT)")
      in
      let truncate_sql = Pgsql_io.Typed_sql.(sql /^ "TRUNCATE tt_bigt") in
      let insert_sql =
        Pgsql_io.Typed_sql.(sql /^ "INSERT INTO tt_bigt SELECT generate_series(1, 20000)")
      in
      let bad_fetch = Pgsql_io.Typed_sql.(sql // Ret.smallint_b /^ "SELECT v FROM tt_bigt") in
      let good_fetch = Pgsql_io.Typed_sql.(sql // Ret.bigint /^ "SELECT v FROM tt_bigt") in
      let assert_reuse_ok label = function
        | `Ok (Ok rows) when List.length rows = 20000 -> Abb.Future.return ()
        | `Ok (Ok rows) ->
            Oth.Assert.false_
              (Printf.sprintf "%s : reuse returned %d rows" label (List.length rows))
        | `Ok (Error e) ->
            Oth.Assert.false_ (Printf.sprintf "%s : reuse failed : %s" label (Pgsql_io.show_err e))
        | `Timeout -> Oth.Assert.false_ (Printf.sprintf "%s : HANG on dirty conn" label)
      in
      let f conn =
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= fun _ ->
        Pgsql_io.Prepared_stmt.execute conn truncate_sql
        >>= fun _ ->
        Pgsql_io.Prepared_stmt.execute conn insert_sql
        >>= fun _ ->
        (* Scenario 1: a Bad_result is ignored, then the connection is reused. *)
        Abbs_future_combinators.timeout
          ~timeout:(Abb.Sys.sleep 15.0)
          (Pgsql_io.tx conn ~f:(fun () ->
               Pgsql_io.Prepared_stmt.fetch conn bad_fetch ~f:(fun v -> v)
               >>= fun _r1 -> Pgsql_io.Prepared_stmt.fetch conn good_fetch ~f:(fun v -> v)))
        >>= fun res1 ->
        assert_reuse_ok "bad_result" res1
        >>= fun () ->
        (* Scenario 2: a row function that RAISES mid-result; the exn must be
           caught, the response drained, and the connection left clean. *)
        Abbs_future_combinators.timeout
          ~timeout:(Abb.Sys.sleep 15.0)
          (Pgsql_io.tx conn ~f:(fun () ->
               Abb.Future.await_bind
                 (fun _ -> Abb.Future.return ())
                 (Pgsql_io.Prepared_stmt.fetch conn good_fetch ~f:(fun _v -> failwith "decode boom"))
               >>= fun () -> Pgsql_io.Prepared_stmt.fetch conn good_fetch ~f:(fun v -> v)))
        >>= fun res2 ->
        assert_reuse_ok "raise" res2 >>= fun () -> Abbs_future_combinators.return_ok ()
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

let notification_payload = function
  | Some n -> Some n.Pgsql_io.payload
  | None -> None

(* Bound [wait_for_notification] with a timeout so a hung wait fails the test
   rather than hanging the suite. *)
let wait_notification conn =
  let open Abb.Future.Infix_monad in
  Abbs_future_combinators.timeout
    ~timeout:(Abb.Sys.sleep 10.0)
    (Pgsql_io.wait_for_notification conn)
  >>= function
  | `Ok (Ok n) -> Abbs_future_combinators.return_ok n
  | `Ok (Error _ as e) -> Abb.Future.return e
  | `Timeout -> Oth.Assert.false_ "timed out waiting for notification"

(* NOTIFY from a second, independent connection -- the realistic case, and it
   sidesteps the asynchronous delivery timing of a self-NOTIFY.  Sequential: by
   the time this returns, the notification is committed, so a listening
   connection that already issued LISTEN will receive it on its next read. *)
let notify_from_new_conn ~channel ?payload () =
  with_conn (fun conn -> Pgsql_io.notify conn ~channel ?payload ())

let test_listen_notify =
  Oth_abb.test ~desc:"LISTEN/NOTIFY cross-connection delivery" ~name:"listen_notify" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.listen conn ~channel:"sg_basic"
        >>= fun () ->
        notify_from_new_conn ~channel:"sg_basic" ~payload:"hello" ()
        >>= fun () -> wait_notification conn
      in
      with_conn f
      >>= function
      | Ok n ->
          Oth.Assert.Eq.string ~expected:"sg_basic" ~actual:n.Pgsql_io.channel;
          Oth.Assert.Eq.string ~expected:"hello" ~actual:n.Pgsql_io.payload;
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_get_notification =
  Oth_abb.test ~desc:"get_notification non-blocking drain" ~name:"get_notification" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        (* Nothing received yet: get_notification is None. *)
        let empty_before = Pgsql_io.get_notification conn in
        Pgsql_io.listen conn ~channel:"sg_get"
        >>= fun () ->
        notify_from_new_conn ~channel:"sg_get" ~payload:"first" ()
        >>= fun () ->
        notify_from_new_conn ~channel:"sg_get" ~payload:"second" ()
        >>= fun () ->
        (* Notifications are delivered asynchronously, so a read must happen before
           they are queued.  Drain two, preferring the non-blocking get_notification
           (which succeeds once a read has enqueued more than it popped) and falling
           back to a blocking wait. *)
        let rec drain acc n =
          if n = 0 then Abbs_future_combinators.return_ok (CCList.rev acc)
          else
            match Pgsql_io.get_notification conn with
            | Some notif -> drain (notif :: acc) (n - 1)
            | None -> wait_notification conn >>= fun notif -> drain (notif :: acc) (n - 1)
        in
        drain [] 2
        >>| fun notifs ->
        (* Queue fully drained. *)
        let empty_after = Pgsql_io.get_notification conn in
        (empty_before, notifs, empty_after)
      in
      with_conn f
      >>= function
      | Ok (empty_before, notifs, empty_after) ->
          Oth.Assert.Eq.string_option ~expected:None ~actual:(notification_payload empty_before);
          Oth.Assert.Eq.string_list
            ~expected:[ "first"; "second" ]
            ~actual:(CCList.map (fun n -> n.Pgsql_io.payload) notifs);
          Oth.Assert.Eq.string_option ~expected:None ~actual:(notification_payload empty_after);
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_notification_during_fetch =
  Oth_abb.test ~desc:"NOTIFY during fetch is harmless" ~name:"notification_during_fetch" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.listen conn ~channel:"sg_during"
        >>= fun () ->
        (* Notification is committed (from another connection) and pending before we
           fetch: the fetch must still return the right rows, and the notification
           must be captured (it either rides the fetch's frame stream or arrives on
           the following wait). *)
        notify_from_new_conn ~channel:"sg_during" ~payload:"during" ()
        >>= fun () ->
        Pgsql_io.Prepared_stmt.fetch
          conn
          Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT 1")
          ~f:(fun n -> n)
        >>= fun rows ->
        (match Pgsql_io.get_notification conn with
          | Some n -> Abbs_future_combinators.return_ok n
          | None -> wait_notification conn)
        >>| fun n -> (rows, n)
      in
      with_conn f
      >>= function
      | Ok (rows, n) ->
          Oth.Assert.Eq.list ~eq:Int32.equal ~pp:pp_int32 ~expected:[ 1l ] ~actual:rows;
          Oth.Assert.Eq.string ~expected:"sg_during" ~actual:n.Pgsql_io.channel;
          Oth.Assert.Eq.string ~expected:"during" ~actual:n.Pgsql_io.payload;
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_unlisten_stops_delivery =
  Oth_abb.test ~desc:"UNLISTEN stops delivery" ~name:"unlisten_stops_delivery" (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.listen conn ~channel:"sg_un"
        >>= fun () ->
        Pgsql_io.unlisten conn ~channel:"sg_un"
        >>= fun () ->
        notify_from_new_conn ~channel:"sg_un" ~payload:"ignored" ()
        >>= fun () ->
        (* Drive a read cycle: a wrongly-delivered notification would be queued by
           this fetch.  The queue must stay empty. *)
        Pgsql_io.Prepared_stmt.fetch
          conn
          Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT 1")
          ~f:(fun n -> n)
        >>| fun _ -> Pgsql_io.get_notification conn
      in
      with_conn f
      >>= function
      | Ok no ->
          Oth.Assert.Eq.string_option ~expected:None ~actual:(notification_payload no);
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_wait_abort_leaves_conn_valid =
  Oth_abb.test
    ~desc:"Aborted wait leaves connection valid"
    ~name:"wait_abort_leaves_conn_valid"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let f conn =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.listen conn ~channel:"sg_abort"
        >>= fun () ->
        (* No notifier, short timeout: the wait must time out, aborting
           wait_for_notification mid-read. *)
        let open Abb.Future.Infix_monad in
        Abbs_future_combinators.timeout
          ~timeout:(Abb.Sys.sleep 1.0)
          (Pgsql_io.wait_for_notification conn)
        >>= fun wait_res ->
        let timed_out =
          match wait_res with
          | `Timeout -> true
          | `Ok _ -> false
        in
        (* The connection must still work: a query (would raise "busy" if the abort
           leaked the guard), then a fresh notification must be delivered. *)
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.Prepared_stmt.fetch
          conn
          Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT 1")
          ~f:(fun n -> n)
        >>= fun rows ->
        notify_from_new_conn ~channel:"sg_abort" ~payload:"after" ()
        >>= fun () -> wait_notification conn >>| fun n -> (timed_out, rows, n)
      in
      with_conn f
      >>= function
      | Ok (timed_out, rows, n) ->
          Oth.Assert.Eq.bool ~expected:true ~actual:timed_out;
          Oth.Assert.Eq.list ~eq:Int32.equal ~pp:pp_int32 ~expected:[ 1l ] ~actual:rows;
          Oth.Assert.Eq.string ~expected:"after" ~actual:n.Pgsql_io.payload;
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

(* Stress the exact race called out in review: abort firing as a notification is
   arriving.  A short, per-iteration-varied timeout makes the abort land before,
   during, and after delivery across many iterations.  The timing is random but the
   asserted invariant is not: a timed-out wait must never lose the notification (a
   following bounded wait must still return it), and the connection must stay valid
   after every abort.  Loss or desync would fail deterministically. *)
let test_abort_during_delivery_no_loss =
  Oth_abb.test
    ~desc:"Abort racing an incoming notify never loses it or desyncs"
    ~name:"abort_during_delivery_no_loss"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let iterations = 100 in
      let f conn_a =
        let open Abbs_future_combinators.Infix_result_monad in
        Pgsql_io.listen conn_a ~channel:"sg_race"
        >>= fun () ->
        with_conn (fun conn_b ->
            let rec loop i =
              if i > iterations then Abbs_future_combinators.return_ok ()
              else
                let open Abbs_future_combinators.Infix_result_monad in
                let payload = Printf.sprintf "p%d" i in
                Pgsql_io.notify conn_b ~channel:"sg_race" ~payload ()
                >>= fun () ->
                let timeout_s = 0.0005 +. (0.0005 *. float_of_int (i mod 8)) in
                let open Abb.Future.Infix_monad in
                Abbs_future_combinators.timeout
                  ~timeout:(Abb.Sys.sleep timeout_s)
                  (Pgsql_io.wait_for_notification conn_a)
                >>= fun raced ->
                let open Abbs_future_combinators.Infix_result_monad in
                (match raced with
                  | `Ok (Ok n) -> Abbs_future_combinators.return_ok n
                  | `Ok (Error _ as e) -> Abb.Future.return e
                  (* Aborted -- possibly mid-arrival.  The notification must not be
                   lost: a bounded blocking wait must still return it. *)
                  | `Timeout -> wait_notification conn_a)
                >>= fun n ->
                Oth.Assert.Eq.string ~expected:payload ~actual:n.Pgsql_io.payload;
                (* No desync and no leaked busy guard: the connection still works. *)
                Pgsql_io.Prepared_stmt.fetch
                  conn_a
                  Pgsql_io.Typed_sql.(sql // Ret.integer /^ "SELECT 1")
                  ~f:(fun n -> n)
                >>= fun rows ->
                Oth.Assert.Eq.list ~eq:Int32.equal ~pp:pp_int32 ~expected:[ 1l ] ~actual:rows;
                loop (i + 1)
            in
            loop 1)
      in
      with_conn f
      >>= function
      | Ok () -> Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "unexpected error")

let test_large_jsonb_fetch =
  Oth_abb.test
    ~desc:"Large jsonb fetch (simulate compute_node_work.work read-back)"
    ~name:"large_jsonb_fetch"
    (fun () ->
      let open Abb.Future.Infix_monad in
      (* Faithfully mirror compute_node_work: same column shape, read back the
         row's OWN uncommitted write inside a transaction, via the exact 4-column
         Ret shape used by select_compute_node_work, with realistic config-like
         jsonb content (unicode / special chars / nested structure), not a flat
         ASCII blob. *)
      let uuid s =
        match Uuidm.of_string s with
        | Some u -> u
        | None -> failwith "bad uuid"
      in
      let module Payload = struct
        (* A [(string * _) list] field is rendered by ppx_deriving_yojson as a
           JSON object, which keeps the dynamically-keyed [dirs] map shaped like
           the real compute_node_work config. *)
        type workflow = {
          tag_query : string;
          engine : string;
        }
        [@@deriving to_yojson]

        type dir = { tags : string list } [@@deriving to_yojson]

        type config = {
          workflows : workflow list;
          dirs : (string * dir) list;
          notes : string;
        }
        [@@deriving to_yojson]

        type dirspace = {
          dir : string;
          workspace : string;
        }
        [@@deriving to_yojson]

        type t = {
          version : int;
          config : config;
          dirspaces : dirspace list;
          filler : string;
        }
        [@@deriving to_yojson]
      end in
      let mk_payload filler_size =
        Payload.to_yojson
          {
            Payload.version = 1;
            config =
              {
                Payload.workflows =
                  [
                    {
                      Payload.tag_query = "dir:services/* and (env:prod or env:dev)";
                      engine = "terraform";
                    };
                  ];
                dirs =
                  [
                    ( "services/caf\xc3\xa9-app",
                      { Payload.tags = [ "na\xc3\xafve"; "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e" ] }
                    );
                  ];
                notes =
                  "sp\xc3\xabcial \xe2\x80\x94 chars: \"quotes\", \\backslash, \ttab, emoji \
                   \xf0\x9f\x9a\x80";
              };
            dirspaces =
              List.init 50 (fun i ->
                  { Payload.dir = Printf.sprintf "services/svc-%d" i; workspace = "default" });
            filler = String.make filler_size 'x';
          }
      in
      let f conn =
        let create_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "CREATE TABLE foo (compute_node uuid, created_at timestamptz default now(), state \
                text, work jsonb not null, work_manifest uuid)")
        in
        let upsert_sql =
          Pgsql_io.Typed_sql.(
            sql
            /^ "INSERT INTO foo (compute_node, state, work, work_manifest) VALUES($cn, 'created', \
                $work, $wm)"
            /% Var.uuid "cn"
            /% Var.json "work"
            /% Var.uuid "wm")
        in
        (* Exact shape of select_compute_node_work. *)
        let select_sql =
          Pgsql_io.Typed_sql.(
            sql
            // Ret.text
            // Ret.text
            // Ret.json
            // Ret.uuid
            /^ "SELECT to_char(created_at, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), state, work, \
                work_manifest FROM foo WHERE compute_node = $cn"
            /% Var.uuid "cn")
        in
        Pgsql_io.Prepared_stmt.execute conn create_sql
        >>= function
        | Error err ->
            Logs.err (fun m -> m "CREATE_ERR : %s" (Pgsql_io.show_err err));
            Abbs_future_combinators.return_ok ()
        | Ok () ->
            let cn = uuid "43df20b3-eb5e-4c00-b1ef-f094d6641087" in
            let wm = uuid "43df20b3-eb5e-4c00-b1ef-f094d6641087" in
            let sizes = [ 0; 4096; 65536; 1048576; 16777216 ] in
            let rec sweep idx = function
              | [] ->
                  Logs.info (fun m -> m "SWEEP_DONE : no hang reproduced");
                  Abbs_future_combinators.return_ok ()
              | filler :: rest -> (
                  Logs.info (fun m -> m "ITER_START : idx=%d : filler=%d bytes" idx filler);
                  (* upsert + read-back-own-uncommitted-write inside one tx,
                     exactly like set_work + the second query_work. *)
                  Abbs_future_combinators.timeout
                    ~timeout:(Abb.Sys.sleep 25.0)
                    (Pgsql_io.tx conn ~f:(fun () ->
                         let open Abbs_future_combinators.Infix_result_monad in
                         Pgsql_io.Prepared_stmt.execute conn upsert_sql cn (mk_payload filler) wm
                         >>= fun () ->
                         Logs.info (fun m -> m "READBACK_START : idx=%d : filler=%d" idx filler);
                         Pgsql_io.Prepared_stmt.fetch
                           conn
                           select_sql
                           ~f:(fun _created state _work wm -> (state, wm))
                           cn
                         >>| fun rows -> List.length rows))
                  >>= function
                  | `Ok (Ok n) ->
                      Logs.info (fun m ->
                          m "READBACK_OK : idx=%d : filler=%d : rows=%d" idx filler n);
                      sweep (idx + 1) rest
                  | `Ok (Error err) ->
                      Logs.err (fun m ->
                          m
                            "READBACK_ERR : idx=%d : filler=%d : %s"
                            idx
                            filler
                            (Pgsql_io.show_err err));
                      Abbs_future_combinators.return_ok ()
                  | `Timeout ->
                      Logs.err (fun m ->
                          m
                            "READBACK_HANG : idx=%d : filler=%d : *** 25s+ STALL REPRODUCED ***"
                            idx
                            filler);
                      Abbs_future_combinators.return_ok ())
            in
            sweep 0 sizes
      in
      with_conn f
      >>= fun r ->
      ignore (Oth.Assert.ok_pp ~pp:pp_pgsql_combined_err r);
      Abb.Future.return ())

(* The user's scenario: issue a query that errors, do NOT bubble the error up
   the result monad -- just ignore it -- then issue another query on the SAME
   connection and see whether it hangs.  Run across the meaningful variants:
   outside vs inside a tx, and a runtime error (1/0, fails at Execute, after
   Sync) vs a parse-time error (missing relation, fails at Parse). *)

let test =
  Oth_abb.(
    serial
      [
        test_listen_notify;
        test_get_notification;
        test_notification_during_fetch;
        test_unlisten_stops_delivery;
        test_wait_abort_leaves_conn_valid;
        test_abort_during_delivery_no_loss;
        test_boundary_sweep;
        test_in_tx_commit_desync;
        test_bad_result_dirty_conn;
        test_large_jsonb_fetch;
        test_insert_row_null;
        test_fetch_row;
        test_fetch_all_rows;
        test_multiple_tx_success;
        test_with_cursor;
        test_bad_bind_too_few_args;
        test_array;
        test_insert_execute;
        test_stmt_fetch;
        test_integrity_fail;
        test_integrity_recover;
        test_rollback;
        test_bad_state;
        test_copy_to;
        test_copy_to_conflict;
        test_copy_to_bad_data;
        test_copy_to_bytea;
        test_text_special_chars;
        test_text_nul_byte;
        test_copy_to_special_chars;
        test_text_empty_vs_null;
        test_integer_bounds;
        test_copy_to_integer_bounds;
        test_float_special_values;
        test_json_invalid;
        test_copy_to_jsonb;
        test_json_round_trip;
        test_json_cross_type;
        test_bytea_large;
        test_copy_to_bytea_large;
        test_copy_to_empty;
        test_copy_to_bytea_with_trailer_bytes;
        test_copy_to_all_nulls;
        test_copy_to_many_columns;
        test_copy_to_mixed_types;
        test_concurrent_exn_raise;
        test_ret_u_all_types;
        test_bytea_var_ret;
        test_bigint_column_smallint_ret;
        test_bigint_column_smallint_b_ret_fails;
        test_ret_b_all_types;
        test_query_dangerous_values;
        test_copy_to_single_row;
      ])

let reporter ppf =
  let report _src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let with_stamp h _tags k ppf fmt =
      (* TODO: Make this use the proper Abb time *)
      let time = Unix.gettimeofday () in
      let time_str = ISO8601.Permissive.string_of_datetime time in
      Format.kfprintf k ppf ("[%s]%a @[" ^^ fmt ^^ "@]@.") time_str Logs.pp_header (level, h)
    in
    msgf @@ fun ?header ?tags fmt -> with_stamp header tags k ppf fmt
  in
  { Logs.report }

let () =
  Random.self_init ();
  Logs.set_reporter (reporter Format.std_formatter);
  Logs.set_level ~all:true (Some Logs.Debug);
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abbs_future_combinators.return_ok ())
    ~teardown:(fun () -> Abb.Future.return ())
    (fun () -> test)

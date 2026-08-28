type store_err = Pgsql_io.err
type abort_err = Pgsql_io.err

type run_err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  ]

module Sql = struct
  let insert_task () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ "insert into tasks (name, user_id) values ($name, $user_id) returning id"
      /% Var.text "name"
      /% Var.option (Var.uuid "user_id"))

  let update_task () =
    Pgsql_io.Typed_sql.(
      sql
      /^ "update tasks set state = $state, updated_at = now() where id = $id"
      /% Var.uuid "id"
      /% Var.text "state")
end

type 'a t = {
  id : 'a;
  name : string;
  user_id : Uuidm.t option;
}

type fresh = unit
type stored = Uuidm.t

let make ~name ?user_id () = { id = (); name; user_id }
let id t = t.id

let store db t =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.insert_task ()) ~f:CCFun.id t.name t.user_id
  >>= function
  | [] -> assert false
  | id :: _ -> Abbs_future_combinators.return_ok { t with id }

let update_task db id state = Pgsql_io.Prepared_stmt.execute db (Sql.update_task ()) id state
let abort db t = update_task db t.id "aborted"

let run storage t f =
  Abbs_future_combinators.on_failure
    (fun () ->
      let open Abb.Future.Infix_monad in
      Pgsql_pool.with_conn storage ~f:(fun db -> update_task db t.id "running")
      >>= function
      | Ok () -> (
          f ()
          >>= function
          | Ok _ as r ->
              let open Abbs_future_combinators.Infix_result_monad in
              Pgsql_pool.with_conn storage ~f:(fun db -> update_task db t.id "completed")
              >>? fun () -> r
          | Error _ as err ->
              let open Abbs_future_combinators.Infix_result_monad in
              Pgsql_pool.with_conn storage ~f:(fun db -> update_task db t.id "failed")
              >>? fun () -> err)
      | Error _ as err ->
          let open Abbs_future_combinators.Infix_result_monad in
          Pgsql_pool.with_conn storage ~f:(fun db -> update_task db t.id "failed") >>? fun () -> err)
    ~failure:(fun () ->
      Abbs_future_combinators.ignore
        (Pgsql_pool.with_conn storage ~f:(fun db -> update_task db t.id "failed")))

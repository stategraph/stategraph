module Sql = struct
  let github_more_rows =
    Pgsql_io.Typed_sql.(
      sql // Ret.bigint /^ "select repository from github_dirspace_locking_migration limit 1")

  let github_perform_sql =
    {|
     with
     batch as (
         select * from github_dirspace_locking_migration limit 100 for update skip locked
     ),
     deleted as (
         delete from github_dirspace_locking_migration as mig
         using batch
         where batch.repository = mig.repository and batch.pull_number = mig.pull_number
         returning mig.repository, mig.pull_number
     )
     select update_github_pull_request_dirspace_locks(repository, pull_number) from deleted
     |}

  let github_perform = Pgsql_io.Typed_sql.(sql // Ret.text /^ github_perform_sql)

  let gitlab_more_rows =
    Pgsql_io.Typed_sql.(
      sql // Ret.bigint /^ "select repository from gitlab_dirspace_locking_migration limit 1")

  let gitlab_perform_sql =
    {|
     with
     batch as (
         select * from gitlab_dirspace_locking_migration limit 100 for update skip locked
     ),
     deleted as (
         delete from gitlab_dirspace_locking_migration as mig
         using batch
         where batch.repository = mig.repository and batch.pull_number = mig.pull_number
         returning mig.repository, mig.pull_number
     )
     select update_gitlab_pull_request_dirspace_locks(repository, pull_number) from deleted
     |}

  let gitlab_perform = Pgsql_io.Typed_sql.(sql // Ret.text /^ gitlab_perform_sql)
end

let rec run_batch storage update while_ =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          while_ db
          >>= function
          | `Cont -> update db >>| fun () -> `Cont
          | `Done -> Abbs_future_combinators.return_ok `Done))
  >>= function
  | `Cont -> run_batch storage update while_
  | `Done -> Abbs_future_combinators.return_ok ()

let update' sql db =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db ~f:(fun x -> x) sql >>| fun _ -> ()

let while' sql db =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db sql ~f:CCFun.id
  >>| function
  | [] -> `Done
  | _ :: _ -> `Cont

let run_github (_config, storage) =
  run_batch storage (update' Sql.github_perform) (while' Sql.github_more_rows)

let run_gitlab (_config, storage) =
  run_batch storage (update' Sql.gitlab_perform) (while' Sql.gitlab_more_rows)

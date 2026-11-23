let src = Logs.Src.create "terrat_installation_retention"

module Logs = (val Logs.src_log src : Logs.LOG)

type counts = {
  scheduled : int;
  unscheduled : int;
  deleted : (int64 * Yojson.Safe.t) list;
  failed : int;
}

let advisory_lock_key = 3920l
let max_deletions_per_run = 10

type provider =
  | Github
  | Gitlab

let provider_name = function
  | Github -> "github"
  | Gitlab -> "gitlab"

module Sql = struct
  let try_advisory_lock_sql = Mql_sql.read [%blob "./sql/try_advisory_lock.sql"]

  let try_advisory_lock () =
    Pgsql_io.Typed_sql.(
      sql // Ret.boolean /^ try_advisory_lock_sql /% Var.integer "key" /% Var.text "provider")

  let schedule_github_sql = Mql_sql.read [%blob "./sql/schedule_github.sql"]
  let schedule_gitlab_sql = Mql_sql.read [%blob "./sql/schedule_gitlab.sql"]

  let schedule_sql = function
    | Github -> schedule_github_sql
    | Gitlab -> schedule_gitlab_sql

  let schedule provider =
    Pgsql_io.Typed_sql.(
      sql // Ret.bigint /^ schedule_sql provider /% Var.integer "days" /% Var.integer "notice_days")

  let unschedule_github_sql = Mql_sql.read [%blob "./sql/unschedule_github.sql"]
  let unschedule_gitlab_sql = Mql_sql.read [%blob "./sql/unschedule_gitlab.sql"]

  let unschedule_sql = function
    | Github -> unschedule_github_sql
    | Gitlab -> unschedule_gitlab_sql

  let unschedule provider = Pgsql_io.Typed_sql.(sql // Ret.bigint /^ unschedule_sql provider)
  let select_due_github_sql = Mql_sql.read [%blob "./sql/select_due_github.sql"]
  let select_due_gitlab_sql = Mql_sql.read [%blob "./sql/select_due_gitlab.sql"]

  let select_due_sql = function
    | Github -> select_due_github_sql
    | Gitlab -> select_due_gitlab_sql

  let select_due provider =
    Pgsql_io.Typed_sql.(sql // Ret.bigint /^ select_due_sql provider /% Var.integer "limit")

  let lock_due_github_sql = Mql_sql.read [%blob "./sql/lock_due_github.sql"]
  let lock_due_gitlab_sql = Mql_sql.read [%blob "./sql/lock_due_gitlab.sql"]

  let lock_due_sql = function
    | Github -> lock_due_github_sql
    | Gitlab -> lock_due_gitlab_sql

  let lock_due provider =
    Pgsql_io.Typed_sql.(sql // Ret.bigint /^ lock_due_sql provider /% Var.bigint "installation_id")

  let delete_installation_github_sql = Mql_sql.read [%blob "./sql/delete_github_installation.sql"]
  let delete_installation_gitlab_sql = Mql_sql.read [%blob "./sql/delete_gitlab_installation.sql"]

  let delete_installation_sql = function
    | Github -> delete_installation_github_sql
    | Gitlab -> delete_installation_gitlab_sql

  let delete_installation provider =
    Pgsql_io.Typed_sql.(
      sql // Ret.jsonb /^ delete_installation_sql provider /% Var.bigint "installation_id")

  let record_deletion_sql = Mql_sql.read [%blob "./sql/record_deletion.sql"]

  let record_deletion () =
    Pgsql_io.Typed_sql.(
      sql
      /^ record_deletion_sql
      /% Var.text "provider"
      /% Var.bigint "installation_id"
      /% Var.json "deleted_rows")
end

let log_err what = function
  | #Pgsql_pool.err as err -> Logs.err (fun m -> m "%s : %s" what (Pgsql_pool.show_err err))
  | #Pgsql_io.err as err -> Logs.err (fun m -> m "%s : %a" what Pgsql_io.pp_err err)

(* The schedule changes under the run's lock, in one transaction.  [None]: another runner holds
   the lock, or the transaction failed. *)
let update_schedule provider storage retention =
  let module R = Terrat_config.Installation_retention in
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.try_advisory_lock ())
            ~f:CCFun.id
            advisory_lock_key
            (provider_name provider)
          >>= function
          | [ true ] ->
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.schedule provider)
                ~f:CCFun.id
                (Int32.of_int (R.days retention))
                (Int32.of_int (R.notice_days retention))
              >>= fun scheduled ->
              Pgsql_io.Prepared_stmt.fetch db (Sql.unschedule provider) ~f:CCFun.id
              >>| fun unscheduled -> Some (CCList.length scheduled, CCList.length unscheduled)
          | _ ->
              Logs.info (fun m ->
                  m
                    "INSTALLATION_RETENTION : provider=%s : skipped, another runner holds the lock"
                    (provider_name provider));
              Abbs_fc.return_ok None))
  >>= function
  | Ok r -> Abb.Future.return r
  | Error err ->
      log_err
        (Printf.sprintf "INSTALLATION_RETENTION : SCHEDULE : provider=%s" (provider_name provider))
        err;
      Abb.Future.return None

(* One deletion: lock the installation while its deletion is still due, delete its rows, and record
   the deletion.  [Ok None]: the deletion was no longer due. *)
let delete_one provider storage installation_id =
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_io.Prepared_stmt.fetch db (Sql.lock_due provider) ~f:CCFun.id installation_id
          >>= function
          | [] -> Abbs_fc.return_ok None
          | _ :: _ -> (
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.delete_installation provider)
                ~f:CCFun.id
                installation_id
              >>= function
              | deleted_rows :: _ ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    (Sql.record_deletion ())
                    (provider_name provider)
                    installation_id
                    deleted_rows
                  >>| fun () -> Some deleted_rows
              | [] -> Abbs_fc.return_ok None)))

let delete_due provider storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_due provider)
        ~f:CCFun.id
        (Int32.of_int max_deletions_per_run))
  >>= function
  | Error err ->
      log_err
        (Printf.sprintf
           "INSTALLATION_RETENTION : SELECT_DUE : provider=%s"
           (provider_name provider))
        err;
      Abb.Future.return ([], 1)
  | Ok ids ->
      let rec loop deleted failed = function
        | [] -> Abb.Future.return (CCList.rev deleted, failed)
        | installation_id :: rest -> (
            delete_one provider storage installation_id
            >>= function
            | Ok (Some deleted_rows) ->
                Logs.info (fun m ->
                    m
                      "INSTALLATION_RETENTION : DELETED : provider=%s : installation_id=%Ld : \
                       rows=%s"
                      (provider_name provider)
                      installation_id
                      (Yojson.Safe.to_string deleted_rows));
                loop ((installation_id, deleted_rows) :: deleted) failed rest
            | Ok None -> loop deleted failed rest
            | Error err ->
                log_err
                  (Printf.sprintf
                     "INSTALLATION_RETENTION : DELETE : provider=%s : installation_id=%Ld"
                     (provider_name provider)
                     installation_id)
                  err;
                loop deleted (failed + 1) rest)
      in
      loop [] 0 ids

let run_counts provider config storage =
  let module R = Terrat_config.Installation_retention in
  let open Abb.Future.Infix_monad in
  let retention = Terrat_config.installation_retention config in
  match R.mode retention with
  | R.Off -> Abb.Future.return None
  | (R.Schedule | R.Delete) as mode -> (
      update_schedule provider storage retention
      >>= function
      | None -> Abb.Future.return None
      | Some (scheduled, unscheduled) ->
          (match mode with
            | R.Delete -> delete_due provider storage
            | R.Off | R.Schedule -> Abb.Future.return ([], 0))
          >>| fun (deleted, failed) ->
          Logs.info (fun m ->
              m
                "INSTALLATION_RETENTION : provider=%s : mode=%s : scheduled=%d : unscheduled=%d : \
                 deleted=%d : failed=%d"
                (provider_name provider)
                (R.show_mode mode)
                scheduled
                unscheduled
                (CCList.length deleted)
                failed);
          Some { scheduled; unscheduled; deleted; failed })

let run provider config storage =
  let open Abb.Future.Infix_monad in
  run_counts provider config storage >>| fun _ -> ()

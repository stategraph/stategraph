let src = Logs.Src.create "sgs_tenant_retention"

module Logs = (val Logs.src_log src : Logs.LOG)

type settings = {
  mode : [ `Off | `Schedule | `Delete ];
  days : int;
  notice_days : int;
}

let settings_of_config config =
  {
    mode = Sgs_config.tenant_retention_mode config;
    days = Sgs_config.tenant_retention_days config;
    notice_days = Sgs_config.tenant_retention_notice_days config;
  }

type counts = {
  scheduled : int;
  unscheduled : int;
  deleted : (Uuidm.t * Yojson.Safe.t) list;
  failed : int;
}

let kind = "tenant_retention"
let advisory_lock_key = 3921l
let max_deletions_per_run = 10

module Sql = struct
  let try_advisory_lock_sql = Mql_sql.read [%blob "./sql/try_advisory_lock.sql"]

  let try_advisory_lock () =
    Pgsql_io.Typed_sql.(sql // Ret.boolean /^ try_advisory_lock_sql /% Var.integer "key")

  let schedule_sql = Mql_sql.read [%blob "./sql/schedule.sql"]

  let schedule () =
    Pgsql_io.Typed_sql.(
      sql // Ret.uuid /^ schedule_sql /% Var.integer "days" /% Var.integer "notice_days")

  let unschedule_sql = Mql_sql.read [%blob "./sql/unschedule.sql"]
  let unschedule () = Pgsql_io.Typed_sql.(sql // Ret.uuid /^ unschedule_sql)
  let select_due_sql = Mql_sql.read [%blob "./sql/select_due.sql"]
  let select_due () = Pgsql_io.Typed_sql.(sql // Ret.uuid /^ select_due_sql /% Var.integer "limit")
  let lock_due_sql = Mql_sql.read [%blob "./sql/lock_due.sql"]
  let lock_due () = Pgsql_io.Typed_sql.(sql // Ret.uuid /^ lock_due_sql /% Var.uuid "tenant_id")
  let select_members_sql = Mql_sql.read [%blob "./sql/select_members.sql"]

  let select_members () =
    Pgsql_io.Typed_sql.(sql // Ret.uuid /^ select_members_sql /% Var.uuid "tenant_id")

  let delete_tenant_sql = Mql_sql.read [%blob "./sql/delete_tenant.sql"]

  let delete_tenant () =
    Pgsql_io.Typed_sql.(sql // Ret.jsonb /^ delete_tenant_sql /% Var.uuid "tenant_id")

  let cleanup_users_sql = Mql_sql.read [%blob "./sql/cleanup_users.sql"]

  let cleanup_users () =
    Pgsql_io.Typed_sql.(sql // Ret.jsonb /^ cleanup_users_sql /% Var.(array (uuid "user_ids")))

  let record_deletion_sql = Mql_sql.read [%blob "./sql/record_deletion.sql"]

  let record_deletion () =
    Pgsql_io.Typed_sql.(
      sql /^ record_deletion_sql /% Var.uuid "tenant_id" /% Var.json "deleted_rows")
end

let log_err what = function
  | #Pgsql_pool.err as err -> Logs.err (fun m -> m "%s : %s" what (Pgsql_pool.show_err err))
  | #Pgsql_io.err as err -> Logs.err (fun m -> m "%s : %a" what Pgsql_io.pp_err err)

let update_schedule storage settings =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_io.Prepared_stmt.fetch db (Sql.try_advisory_lock ()) ~f:CCFun.id advisory_lock_key
          >>= function
          | [ true ] ->
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.schedule ())
                ~f:CCFun.id
                (Int32.of_int settings.days)
                (Int32.of_int settings.notice_days)
              >>= fun scheduled ->
              Pgsql_io.Prepared_stmt.fetch db (Sql.unschedule ()) ~f:CCFun.id
              >>| fun unscheduled -> Some (CCList.length scheduled, CCList.length unscheduled)
          | _ ->
              Logs.info (fun m -> m "TENANT_RETENTION : skipped, another runner holds the lock");
              Abbs_fc.return_ok None))
  >>= function
  | Ok r -> Abb.Future.return r
  | Error err ->
      log_err "TENANT_RETENTION : SCHEDULE" err;
      Abb.Future.return None

(* The deleted rows of each table, with the counts of the members that left with the tenant. *)
let merge_rows tenant_rows user_rows =
  match (tenant_rows, user_rows) with
  | `Assoc a, `Assoc b -> `Assoc (a @ b)
  | rows, _ -> rows

let delete_one storage tenant_id =
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          let open Abbs_fc.Infix_result_monad in
          Pgsql_io.Prepared_stmt.fetch db (Sql.lock_due ()) ~f:CCFun.id tenant_id
          >>= function
          | [] -> Abbs_fc.return_ok None
          | _ :: _ -> (
              Pgsql_io.Prepared_stmt.fetch db (Sql.select_members ()) ~f:CCFun.id tenant_id
              >>= fun members ->
              Pgsql_io.Prepared_stmt.fetch db (Sql.delete_tenant ()) ~f:CCFun.id tenant_id
              >>= function
              | [] -> Abbs_fc.return_ok None
              | tenant_rows :: _ -> (
                  Pgsql_io.Prepared_stmt.fetch db (Sql.cleanup_users ()) ~f:CCFun.id members
                  >>= function
                  | [] -> Abbs_fc.return_ok None
                  | user_rows :: _ ->
                      let deleted_rows = merge_rows tenant_rows user_rows in
                      Pgsql_io.Prepared_stmt.execute
                        db
                        (Sql.record_deletion ())
                        tenant_id
                        deleted_rows
                      >>| fun () -> Some deleted_rows))))

let delete_due storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_due ())
        ~f:CCFun.id
        (Int32.of_int max_deletions_per_run))
  >>= function
  | Error err ->
      log_err "TENANT_RETENTION : SELECT_DUE" err;
      Abb.Future.return ([], 1)
  | Ok ids ->
      let rec loop deleted failed = function
        | [] -> Abb.Future.return (CCList.rev deleted, failed)
        | tenant_id :: rest -> (
            delete_one storage tenant_id
            >>= function
            | Ok (Some deleted_rows) ->
                Logs.info (fun m ->
                    m
                      "TENANT_RETENTION : DELETED : tenant=%a : rows=%s"
                      Uuidm.pp
                      tenant_id
                      (Yojson.Safe.to_string deleted_rows));
                loop ((tenant_id, deleted_rows) :: deleted) failed rest
            | Ok None -> loop deleted failed rest
            | Error err ->
                log_err
                  (Format.asprintf "TENANT_RETENTION : DELETE : tenant=%a" Uuidm.pp tenant_id)
                  err;
                loop deleted (failed + 1) rest)
      in
      loop [] 0 ids

let show_mode = function
  | `Off -> "off"
  | `Schedule -> "schedule"
  | `Delete -> "delete"

let run_counts settings storage =
  let open Abb.Future.Infix_monad in
  match settings.mode with
  | `Off -> Abb.Future.return None
  | (`Schedule | `Delete) as mode -> (
      update_schedule storage settings
      >>= function
      | None -> Abb.Future.return None
      | Some (scheduled, unscheduled) ->
          (match mode with
            | `Delete -> delete_due storage
            | `Schedule -> Abb.Future.return ([], 0))
          >>| fun (deleted, failed) ->
          Logs.info (fun m ->
              m
                "TENANT_RETENTION : mode=%s : scheduled=%d : unscheduled=%d : deleted=%d : \
                 failed=%d"
                (show_mode mode)
                scheduled
                unscheduled
                (CCList.length deleted)
                failed);
          Some { scheduled; unscheduled; deleted; failed })

let run config storage _db _data =
  let open Abb.Future.Infix_monad in
  run_counts (settings_of_config config) storage >>| fun _ -> ()

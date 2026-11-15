(* The daily repo-tree retention task.

   One transaction for the pair of tables. The transaction runs three steps on each table:

   1. Drop every partition whose upper bound is on or before the cutoff day, that is
      [current_date - days * 1 day]. Such a partition holds only expired rows.
   2. Delete the rows of the default partition whose [cache_day] is before the cutoff day. No
      partition of such a day can exist again, so these rows are expired data that missed their
      partition.
   3. Re-house the in-horizon days that hold rows in the default partition into day-stamped
      partitions. The current day and the next day are always candidates. Every other day at
      or after the cutoff day is a candidate only if the default partition holds rows of it.

   The catalog decides the path of each candidate day:

   - A child partition covers the day exactly: the day is already re-housed. Skip it.
   - No child partition intersects the day: create the day's partition. When the default
     partition holds rows of the day, drain them into the new partition first. When it holds no
     row of the day, the new partition stays empty.
   - A child partition intersects the day but does not match its bounds: log the day and skip
     it. Creation would fail with an overlap error. A later run can re-house the day after the
     misaligned partition expires.

   The drain moves the rows out of the default partition before it creates the day's partition,
   because PostgreSQL refuses a new partition whose range the default partition still holds rows
   for. The drain runs in this order: copy the day's rows into a session-temp table, delete those
   rows from the default partition, create the day's partition, and insert the copied rows into
   it. The new partition carries the parent's primary key from birth, so no standalone table and
   no attach step are necessary.

   Each table's walk opens with [lock table <parent> in exclusive mode]. The walk and a store then
   take the parent and the child locks in the same order, so they queue instead of deadlocking.
   EXCLUSIVE stops inserts into the parent and every child, and it lets [select] run. PostgreSQL
   holds it to the end of the walk's transaction. A read still waits for the rest of the walk,
   because the walk's own DDL takes ACCESS EXCLUSIVE on the parent; that wait is the accepted cost
   of the ordering, recorded in the [.mli].

   Example. [days] is 7, the default, and today is Wednesday 2025-02-12. The cutoff day is
   2025-02-05. The current day is 2025d043 (2025-02-12 to 2025-02-13) and the next day is
   2025d044 (2025-02-13 to 2025-02-14). [repo_trees] has these children:

   - [repo_trees_d2025d033], bounds 2025-02-02 to 2025-02-03.
   - [repo_trees_d2025d043], bounds 2025-02-12 to 2025-02-13.
   - [repo_trees_default], which holds 5 rows of day 2025d035 (2025-02-04), 40 rows of day
     2025d040 (2025-02-09), and 7 rows of day 2025d042 (2025-02-11).

   Step 1 drops [repo_trees_d2025d033], because its upper bound 2025-02-03 is on or before the
   cutoff day. Step 2 deletes the 5 rows of day 2025d035, because their cache_day is before the
   cutoff day. Step 3 takes four candidates: 2025d043 and 2025d044 from the horizon, and
   2025d040 and 2025d042 from the default partition. It skips 2025d043, because
   [repo_trees_d2025d043] covers it exactly. It creates [repo_trees_d2025d044] empty. It drains
   40 rows into [repo_trees_d2025d040] and 7 rows into [repo_trees_d2025d042]. The table's walk
   answers [created=3, dropped=1, drained=47].

   If a child partition with bounds 2025-02-11 to 2025-02-13 also existed, day 2025d042 would
   take the third path instead. The task would log the day and skip it, so the 7 rows would stay
   in the default partition, and a later run would re-house them after that partition expires.

   Every step is idempotent, so a failure mid-run is safe to retry: the pair's transaction rolls
   back whole, the task logs the failure and returns, and the next run redoes both tables. The
   transaction takes one non-blocking advisory lock first, so two competing runners change the pair
   one at a time: a runner that finds the lock held skips both tables and logs the skip. The task
   never raises: its driver forks the task and sleeps, and a raised exception settles that future
   dead -- the loop would never run again for the life of the process.

   The pair is one transaction because the two tables are one cache. [store_repo_tree] writes a
   tree's rows and its build row together, and the build row is the only thing that tells a
   built-and-empty tree from a never-built one. Expiring one table without the other strands a build
   row whose tree rows are gone, and [select_repo_tree_build.sql] then lifts that row forward on
   every evaluation, so no retention cutoff reaches it. The deleted [delete_old_repo_trees.sql]
   emptied both tables in one statement for the same reason.

   The transaction guards and the dynamic DDL come from
   [Terrat_repo_tree_retention_partitions]: the naming rule and the day-label rule are its,
   shared with the migration that seeds the horizon partitions. The guards are issued first thing
   in the pair's transaction, before any bound is read, because the bounds and [current_date]
   render under the transaction's UTC setting. *)

let src = Logs.Src.create "repo_tree_retention"

module Logs = (val Logs.src_log src : Logs.LOG)

type counts = {
  created : int;
  dropped : int;
  drained : int;
}

(* The pair advisory lock's key. It carries no meaning beyond being distinct from every other
   advisory lock this installation takes, but the test that pins the lock's skip takes the
   blocking form of the same lock, so the number lives here and not twice. *)
let advisory_lock_key = 3919l

(* The dynamic DDL of the walk: the naming rule, the day-label rule, the guards, and the builders
   are [Terrat_repo_tree_retention_partitions]'s. *)
module P = Terrat_repo_tree_retention_partitions

module Sql = struct
  let expired_partitions_sql = Mql_sql.read [%blob "./sql/retention_expired_partitions.sql"]

  let expired_partitions () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* relname *)
      Ret.text
      /^ expired_partitions_sql
      /% Var.text "parent"
      /% Var.integer "days")

  let default_days_repo_trees_sql =
    Mql_sql.read [%blob "./sql/retention_default_days_repo_trees.sql"]

  let default_days_repo_trees () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* day_start *)
      Ret.text
      //
      (* day_end *)
      Ret.text
      //
      (* label *)
      Ret.text
      /^ default_days_repo_trees_sql
      /% Var.integer "days")

  let default_days_repo_tree_builds_sql =
    Mql_sql.read [%blob "./sql/retention_default_days_repo_tree_builds.sql"]

  let default_days_repo_tree_builds () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* day_start *)
      Ret.text
      //
      (* day_end *)
      Ret.text
      //
      (* label *)
      Ret.text
      /^ default_days_repo_tree_builds_sql
      /% Var.integer "days")

  let intersecting_partitions_sql =
    Mql_sql.read [%blob "./sql/retention_intersecting_partitions.sql"]

  let intersecting_partitions () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* relname *)
      Ret.text
      //
      (* bound_from *)
      Ret.text
      //
      (* bound_to *)
      Ret.text
      /^ intersecting_partitions_sql
      /% Var.text "parent"
      /% Var.text "from"
      /% Var.text "to")

  let count_default_repo_trees_sql =
    Mql_sql.read [%blob "./sql/retention_count_default_repo_trees.sql"]

  let count_default_repo_trees () =
    Pgsql_io.Typed_sql.(
      sql // Ret.bigint /^ count_default_repo_trees_sql /% Var.text "from" /% Var.text "to")

  let count_default_repo_tree_builds_sql =
    Mql_sql.read [%blob "./sql/retention_count_default_repo_tree_builds.sql"]

  let count_default_repo_tree_builds () =
    Pgsql_io.Typed_sql.(
      sql // Ret.bigint /^ count_default_repo_tree_builds_sql /% Var.text "from" /% Var.text "to")

  let delete_expired_default_repo_trees_sql =
    Mql_sql.read [%blob "./sql/retention_delete_expired_default_repo_trees.sql"]

  let delete_expired_default_repo_trees () =
    Pgsql_io.Typed_sql.(sql /^ delete_expired_default_repo_trees_sql /% Var.integer "days")

  let delete_expired_default_repo_tree_builds_sql =
    Mql_sql.read [%blob "./sql/retention_delete_expired_default_repo_tree_builds.sql"]

  let delete_expired_default_repo_tree_builds () =
    Pgsql_io.Typed_sql.(sql /^ delete_expired_default_repo_tree_builds_sql /% Var.integer "days")

  let try_advisory_lock_sql = Mql_sql.read [%blob "./sql/retention_try_advisory_lock.sql"]

  let try_advisory_lock () =
    Pgsql_io.Typed_sql.(sql // Ret.boolean /^ try_advisory_lock_sql /% Var.integer "key")
end

(* The names are [pg_class.relname] values the catalog answers, not constants of this module: the
   exception the name rule of RFD 1724 records for this maintenance path.  The partitions they
   name are created only by the migration and by [create_day_partition], both under one naming
   rule, so the catalog's answer is trusted and goes into the tree as an identifier. *)
let drop_expired_partitions db ~parent days =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.expired_partitions ()) ~f:CCFun.id parent (Int32.of_int days)
  >>= fun expired ->
  CCList.fold_left
    (fun acc relname ->
      acc
      >>= fun dropped ->
      P.exec_tree db (Mql.Build.drop_table ~if_exists:true relname)
      >>= fun () -> Abbs_fc.return_ok (dropped + 1))
    (Abbs_fc.return_ok 0)
    expired

let delete_expired_default_rows db stmt days =
  Pgsql_io.Prepared_stmt.execute db (stmt ()) (Int32.of_int days)

let day_candidates db ~default_days days =
  let open Abbs_fc.Infix_result_monad in
  P.horizon_days db
  >>= fun horizon ->
  Pgsql_io.Prepared_stmt.fetch
    db
    (default_days ())
    ~f:(fun day_start day_end label -> (day_start, day_end, label))
    (Int32.of_int days)
  >>= fun from_default ->
  (* The horizon and the days the default partition holds may name the same day: the union of the
     two, keyed by the day start, is the candidate set. *)
  let candidates =
    CCList.fold_left
      (fun acc ((day_start, _, _) as day) ->
        if CCList.exists (fun (s, _, _) -> CCString.equal s day_start) acc then acc
        else acc @ [ day ])
      horizon
      from_default
  in
  Abbs_fc.return_ok candidates

(* The staging table of the drain: one session-temp table per day, named after the day's
   partition via the shared naming rule, because a walk drains every candidate day in one
   transaction and two days sharing one per-parent name would collide -- the second
   [create temp table] would raise and roll the whole walk back.  The table is dropped when the
   transaction that creates it ends, so a committed or rolled-back day leaves nothing behind. *)
let staging_name ~label parent = P.day_partition_name ~parent ~label ^ "_retention_stage"

(* The drain sequence: the rows of the day are staged in a session-temp copy, deleted from the
   default partition, the day's partition is created -- PostgreSQL refuses a partition whose
   range the default still holds rows for -- and the staged rows are inserted into the new
   partition, which carries the parent's primary key from birth and needs no attach. The walk
   already holds the parent's EXCLUSIVE lock, which covers every child, so no store can add a row
   to the default partition while the drain runs. *)
let drain_day db ~parent ~label ~day_start ~day_end count =
  let open Abbs_fc.Infix_result_monad in
  let target = P.day_partition_name ~parent ~label in
  let tmp = staging_name ~label parent in
  P.exec_tree db (P.stage_default_rows ~parent ~tmp ~from_bound:day_start ~to_bound:day_end)
  >>= fun () ->
  P.exec_tree db (P.delete_default_rows ~parent ~from_bound:day_start ~to_bound:day_end)
  >>= fun () ->
  P.exec_tree
    db
    (P.create_day_partition
       ~if_not_exists:true
       ~parent
       ~from_bound:day_start
       ~to_bound:day_end
       target)
  >>= fun () ->
  P.exec_tree db (P.insert_staged ~target ~tmp)
  >>= fun () -> Abbs_fc.return_ok (1, Int64.to_int count)

let day_step db ~parent ~count_default (day_start, day_end, label) =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.intersecting_partitions ())
    ~f:(fun relname bound_from bound_to -> (relname, bound_from, bound_to))
    parent
    day_start
    day_end
  >>= fun covering ->
  match covering with
  | [] -> (
      Pgsql_io.Prepared_stmt.fetch db (count_default ()) ~f:CCFun.id day_start day_end
      >>= fun counts ->
      match counts with
      | [ count ] ->
          if count = 0L then
            P.exec_tree
              db
              (P.create_day_partition
                 ~if_not_exists:true
                 ~parent
                 ~from_bound:day_start
                 ~to_bound:day_end
                 (P.day_partition_name ~parent ~label))
            >>= fun () -> Abbs_fc.return_ok (1, 0)
          else drain_day db ~parent ~label ~day_start ~day_end count
      | [] | _ :: _ :: _ ->
          (* A count of no row, or of more than one, is a defect of this task and not of the
             data: the count query answers one row, so neither shape is reachable. Log it and
             skip the day, the way every failure here is handled -- the task never raises. *)
          Logs.err (fun m ->
              m "REPO_TREE_RETENTION : table=%s : the default row count returned no row" parent);
          Abbs_fc.return_ok (0, 0))
  | [ (relname, bound_from, bound_to) ]
    when CCString.equal bound_from day_start && CCString.equal bound_to day_end ->
      Logs.info (fun m ->
          m
            "REPO_TREE_RETENTION : table=%s : day %s..%s is covered by %s"
            parent
            day_start
            day_end
            relname);
      Abbs_fc.return_ok (0, 0)
  | covering ->
      Logs.info (fun m ->
          m
            "REPO_TREE_RETENTION : table=%s : day %s..%s skipped, partly covered by %s"
            parent
            day_start
            day_end
            (CCString.concat ", " (CCList.map (fun (n, _, _) -> n) covering)));
      Abbs_fc.return_ok (0, 0)

(* The pair's lock: the try-lock answers one row, one boolean. Any other shape is a defect of the
   statement, and reads as the lock not taken -- skipping is always safe, the work is idempotent. *)
let try_pair_lock db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.try_advisory_lock ()) ~f:CCFun.id advisory_lock_key
  >>| function
  | [ true ] -> `Locked
  | [ false ] | [] | _ :: _ :: _ -> `Not_locked

(* The parent's EXCLUSIVE lock is the walk's first statement. A store takes the parent's ROW
   EXCLUSIVE lock when its [insert] begins, and the child's when PostgreSQL routes the row. The
   parent-first order here is the order a store uses, so no cycle forms. On a day with an expiring
   partition [drop_expired_partitions] takes the parent's lock itself. On a day without one, the
   drain would be the walk's first parent lock, and the drain takes the default partition's lock
   before it creates the day's partition: that is the cycle this lock closes. The lock recurses
   to the children, so a store that would route a row into the default partition waits on the
   parent instead. [set_transaction_guards] bounds that wait: [lock_timeout] applies to the [LOCK
   TABLE] itself. *)
let walk_locked db ~parent ~default_days ~count_default ~delete_expired days =
  let open Abbs_fc.Infix_result_monad in
  P.exec_tree db (P.lock_parent parent)
  >>= fun () ->
  drop_expired_partitions db ~parent days
  >>= fun dropped ->
  delete_expired_default_rows db delete_expired days
  >>= fun () ->
  day_candidates db ~default_days days
  >>= fun candidates ->
  CCList.fold_left
    (fun acc candidate ->
      acc
      >>= fun (created, drained) ->
      day_step db ~parent ~count_default candidate
      >>= fun (c, d) -> Abbs_fc.return_ok (created + c, drained + d))
    (Abbs_fc.return_ok (0, 0))
    candidates
  >>| fun (created, drained) -> { created; dropped; drained }

(* The failures the three swallow arms below answer, counted in the shared
   [Terrat_metrics.errors_total] family: the walk never raises, so the counter is the only signal
   past the log lines.  No table dimension: the pair fails or succeeds together, and per-table
   detail lives in the log lines. *)
let errors_total = Terrat_metrics.errors_total ~m:"repo_tree_retention"

(* One connection and one transaction for the pair.  The guards are issued first thing, before any
   bound is read: the bounds render under the transaction's UTC setting, and [set local] is
   transaction-scoped and last-writer-wins, so nothing after them re-sets them.  The advisory lock
   is taken after the guards and before the first catalog read, so the whole walk acts on the
   catalog state it read while holding the lock.  [repo_trees] is walked before [repo_tree_builds]
   so the two parents' EXCLUSIVE locks are always taken in the same order.

   A failure rolls both tables back, which is the point: the two tables are one cache, and this
   transaction boundary is what keeps a tree row and its build row consistent. *)
let run_counts config storage =
  let days = Terrat_config.repo_tree_retention_days config in
  let lock_timeout = Terrat_config.db_lock_timeout config in
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          let open Abbs_fc.Infix_result_monad in
          P.set_transaction_guards db ~lock_timeout
          >>= fun () ->
          try_pair_lock db
          >>= function
          | `Not_locked ->
              (* Logged and skipped, not an error: the runner that holds the lock does the work,
                 and this run answers no counts. *)
              Logs.info (fun m -> m "REPO_TREE_RETENTION : skipped, another runner holds the lock");
              Abbs_fc.return_ok None
          | `Locked ->
              walk_locked
                db
                ~parent:"repo_trees"
                ~default_days:Sql.default_days_repo_trees
                ~count_default:Sql.count_default_repo_trees
                ~delete_expired:Sql.delete_expired_default_repo_trees
                days
              >>= fun trees ->
              walk_locked
                db
                ~parent:"repo_tree_builds"
                ~default_days:Sql.default_days_repo_tree_builds
                ~count_default:Sql.count_default_repo_tree_builds
                ~delete_expired:Sql.delete_expired_default_repo_tree_builds
                days
              >>= fun builds -> Abbs_fc.return_ok (Some (trees, builds))))
  >>= function
  | Ok counts ->
      CCOption.iter
        (fun (trees, builds) ->
          Logs.info (fun m ->
              m
                "REPO_TREE_RETENTION : repo_trees : created=%d : dropped=%d : drained=%d"
                trees.created
                trees.dropped
                trees.drained);
          Logs.info (fun m ->
              m
                "REPO_TREE_RETENTION : repo_tree_builds : created=%d : dropped=%d : drained=%d"
                builds.created
                builds.dropped
                builds.drained))
        counts;
      Abb.Future.return counts
  | Error (#Pgsql_pool.err as err) ->
      (* Logged and swallowed, never raised: a raised exception ends the driver's loop for the life
         of the process.  The pair's transaction rolled back whole, and the next run redoes both
         tables. *)
      Logs.err (fun m -> m "REPO_TREE_RETENTION : %s" (Pgsql_pool.show_err err));
      Prmths.Counter.inc_one (errors_total ~t:"pgsql_pool");
      Abb.Future.return None
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "REPO_TREE_RETENTION : %a" Pgsql_io.pp_err err);
      Prmths.Counter.inc_one (errors_total ~t:"pgsql");
      Abb.Future.return None
  | Error (`Mql_err err) ->
      (* The statement writer failed, a defect of the writer: logged and swallowed, never
         raised. *)
      Logs.err (fun m ->
          m "REPO_TREE_RETENTION : the statement writer failed: %s" (Mql.Ast.show_err err));
      Prmths.Counter.inc_one (errors_total ~t:"mql");
      Abb.Future.return None

let run config storage =
  let open Abb.Future.Infix_monad in
  run_counts config storage >>| fun _ -> ()

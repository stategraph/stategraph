(* The daily repo-tree retention task: it drops the day partitions of [repo_trees] and
   [repo_tree_builds] whose upper bound the horizon has passed -- the horizon being
   {!Terrat_config.repo_tree_retention_days} days -- deletes the default-partition rows older
   than the horizon's cutoff day, and re-houses the in-horizon days that hold default rows into
   day-stamped partitions. One transaction for the pair of tables, because a tree row and its
   build row are one cache and must expire together; a DDL failure is logged and swallowed, never
   raised -- the next run redoes both tables, whose transaction rolled back whole.

   The retention rationale: the rows of [repo_trees] are written for each commit whose tree is
   fetched or built, and nothing else removes them. The tree of a repository of 100 000 files is
   100 000 rows, so a repository which is pushed to often fills the table and never empties it.
   The table is keyed by installation and not by repository, so delete_repo.sql does not reach it
   either. A tree which is removed is not work which is lost: the head of a branch is fetched and
   stored again on the next evaluation, and a run whose tree is gone counts as a run whose files
   all changed, so its dirspace runs again. The knob's default of seven days is shorter than the
   plans cleanup's 14-day horizon, so a plan can outlive the tree it was stored with: a run whose
   tree is gone counts as a run whose files all changed, so its dirspace runs again -- the
   fail-safe, not the plan's expiry, is what keeps the shorter horizon safe.

   The naming rule ([day_partition_name]) and the day-label rule the migration and this task
   share are [Terrat_repo_tree_retention_partitions]'s; this task calls them and carries no second
   expression of either. The HOW of the walk -- the drain sequence, the guards, the pair's
   transaction -- is carried in the [terrat_repo_tree_retention.ml] header.

   Accepted cost: a read of a table waits for the rest of that table's walk. The walk's own
   [create table ... partition of] and [drop table] take ACCESS EXCLUSIVE on the parent, and
   PostgreSQL holds that lock to commit. The parent's EXCLUSIVE lock adds no read wait of its own,
   because it does not conflict with [select]. What it buys is the lock order: the walk and a store
   both take the parent first, so they queue instead of deadlocking. The wait is the price of the
   ordering. It is not an oversight. *)

(** The counts one table walk answers: the partitions its run created, the expired partitions it
    dropped, and the default rows it drained. *)
type counts = {
  created : int;
  dropped : int;
  drained : int;
}

(** The key of the pair advisory lock the walk takes. It carries no meaning beyond being distinct
    from every other advisory lock this installation takes; it is exposed because the test that pins
    the lock's skip takes the blocking form of the same lock. *)
val advisory_lock_key : int32

(** [run_counts config storage] walks [repo_trees] and then [repo_tree_builds] in one connection and
    one transaction, and answers their {!counts} as [Some (trees, builds)]. It answers [None] when
    the pair's walk failed -- logged and swallowed -- or when another runner holds the pair's
    advisory lock -- skipped and logged. A failure rolls both tables back, so no tree row expires
    without its build row; the future still resolves, and only a connection failure escapes as an
    exception. *)
val run_counts : Terrat_config.t -> Terrat_storage.t -> (counts * counts) option Abb.Future.t

(** [run config storage] walks the two tables the way {!run_counts} does and discards the counts:
    the shape the fork-loop driver runs. *)
val run : Terrat_config.t -> Terrat_storage.t -> unit Abb.Future.t

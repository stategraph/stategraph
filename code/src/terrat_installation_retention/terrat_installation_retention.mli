(* The daily installation retention task of one provider: it keeps the schedule of the deletions
   of the uninstalled installations of the provider in [installation_deletions] and, in the
   [Delete] mode of {!Terrat_config.Installation_retention}, deletes the data of the installations
   whose deletion is due.

   A deletion is due {!Terrat_config.Installation_retention.days} days after the uninstall, and no
   sooner than {!Terrat_config.Installation_retention.notice_days} days after the installation went
   on the schedule, so every deletion is on the schedule for that long first.  An installation with
   a hold, or that is no longer uninstalled, is not deleted.  Each deletion is one transaction that
   locks the installation and its schedule row, deletes every row of the installation, and records
   the time and the number of deleted rows of each table on the schedule row. *)

(** The VCS provider of the installations one run acts on. *)
type provider =
  | Github
  | Gitlab

(** What one run did: the installations it put on the schedule and took off it, the installations it
    deleted with the number of deleted rows of each table, and the deletions that failed. *)
type counts = {
  scheduled : int;
  unscheduled : int;
  deleted : (int64 * Yojson.Safe.t) list;
  failed : int;
}

(** The key of the run's advisory lock, taken with a second key of each provider. It is distinct
    from every other advisory lock the server takes. *)
val advisory_lock_key : int32

(** The most installations one run deletes. *)
val max_deletions_per_run : int

(** [run_counts provider config storage] runs the task of [provider] once. It answers [None] when
    the mode is [Off], when another runner holds the run's lock, and when the schedule could not be
    updated. A failure is logged and never raised; a failed deletion rolls back and is due again on
    the next run. *)
val run_counts : provider -> Terrat_config.t -> Terrat_storage.t -> counts option Abb.Future.t

(** [run provider config storage] runs the task of [provider] once and discards the counts: the
    shape the daily loop runs. *)
val run : provider -> Terrat_config.t -> Terrat_storage.t -> unit Abb.Future.t

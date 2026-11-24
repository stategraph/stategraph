(* The daily tenant retention task: it keeps the schedule of the deletions of closed tenants in
   [tenant_deletions] and, in the [`Delete] mode of {!Sgs_config.tenant_retention_mode}, deletes
   the data of the tenants whose deletion is due.

   A deletion is due {!Sgs_config.tenant_retention_days} days after the tenant was closed, and no
   sooner than {!Sgs_config.tenant_retention_notice_days} days after the tenant went on the
   schedule.  A tenant with a hold, or that is no longer closed, is not deleted.  Each deletion is
   one transaction that locks the tenant and its schedule row, deletes every row of the tenant,
   deletes or blanks the members that belong to no tenant any more, and records the time and the
   number of deleted rows of each table on the schedule row. *)

type settings = {
  mode : [ `Off | `Schedule | `Delete ];
  days : int;
  notice_days : int;
}

val settings_of_config : Sgs_config.t -> settings

(** What one run did: the tenants it put on the schedule and took off it, the tenants it deleted
    with the number of deleted rows of each table, and the deletions that failed. *)
type counts = {
  scheduled : int;
  unscheduled : int;
  deleted : (Uuidm.t * Yojson.Safe.t) list;
  failed : int;
}

(** The scheduler kind of the task. *)
val kind : string

(** The key of the run's advisory lock. *)
val advisory_lock_key : int32

(** The most tenants one run deletes. *)
val max_deletions_per_run : int

(** [run_counts settings storage] runs the task once. [None]: the mode is [`Off], another runner
    holds the run's lock, or the schedule could not be updated. A failure is logged and never
    raised; a failed deletion rolls back and is due again on the next run. *)
val run_counts : settings -> Sgs_storage.t -> counts option Abb.Future.t

(** The scheduled kind: [run_counts] with the settings of the config, counts discarded. *)
val run : Sgs_config.t -> Sgs_storage.t -> Pgsql_io.t -> Yojson.Safe.t -> unit Abb.Future.t

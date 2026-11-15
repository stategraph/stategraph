(** The partition DDL of the repo-tree tables, shared between the migration that seeds them and the
    daily retention task that maintains them. The one naming rule ([day_partition_name]) and the one
    day-label rule ({i sql/retention_horizon_days.sql}, read with [Mql_sql.read]) live here, so
    neither side carries a second expression of them: the label comes from SQL, because it must
    agree with the day bounds the same query computes, and [YYYY]/[DDD] are the calendar year and
    the zero-padded day of the year, the same alignment as [date_trunc('day')] under the
    transaction's UTC setting.

    The dynamic statements are MQL trees written with [Mql_sql.write], the route mql_sql.mli
    prescribes where the shape of a statement comes from data: a name the catalog or the day math
    gives goes in as an identifier, a bound goes in as a string literal, and the writer renders and
    validates both. Nothing is spliced into text by hand. *)

(** [day_partition_name ~parent ~label] is the name of the partition of [parent] that covers the day
    [label] names, e.g. [repo_trees_d2026d315]. *)
val day_partition_name : parent:string -> label:string -> string

(** [ensure_horizon_partitions db ~parent] creates, with [if not exists], the partition of [parent]
    that covers the current day and the one that covers the next, as {!day_partition_name} names
    them from the day labels of {i sql/retention_horizon_days.sql}. The statements must run inside
    the transaction whose guards {!set_transaction_guards} set: the bounds are read under the
    transaction's UTC setting. Returns how many partitions it created. *)
val ensure_horizon_partitions :
  Pgsql_io.t ->
  parent:string ->
  (int, [> Pgsql_io.err | `Mql_err of Mql.Ast.err ]) result Abb.Future.t

(** [horizon_days db] answers the [(day_start, day_end, label)] of the current day and the next, as
    {i sql/retention_horizon_days.sql} computes them. *)
val horizon_days :
  Pgsql_io.t -> ((string * string * string) list, [> Pgsql_io.err ]) result Abb.Future.t

(** [set_transaction_guards db ~lock_timeout] issues the transaction's [set local] guards, first
    thing: [timezone = 'UTC'], under which the day bounds and labels render, and
    [lock_timeout = lock_timeout], the cap under which the DDL waits on a conflicting holder -- a
    bound, so a walk cannot hang forever, but loose enough that a normal deploy or a concurrent run
    does not fail on a short conflict. The value is the operator's [DB_LOCK_TIMEOUT]
    ([Terrat_config.db_lock_timeout]), which the pool also sets on the session at connect;
    [set local] is transaction-scoped and last-writer-wins, so this statement is what makes the knob
    apply to the walk and to the migration, and a value of [0] disables the cap, as PostgreSQL's own
    default does. The [timezone] statement is bound at module level -- [Mql_sql.set] raises
    [Sql_err] on an illegal name, and raising at load time fails the program at startup instead of
    mid-walk -- and that rationale covers the name [lock_timeout] equally: the name is a constant in
    this module, and only the value varies. *)
val set_transaction_guards :
  Pgsql_io.t ->
  lock_timeout:string ->
  (unit, [> Pgsql_io.err | `Mql_err of Mql.Ast.err ]) result Abb.Future.t

(** [exec_tree db tree] writes the tree with [Mql_sql.write] -- [write_exn] raises, and a raise in a
    run-time walk would end the scheduler -- then executes it. A write failure is a defect of the
    writer, not of the data: it fails the statement, whose transaction rolls back whole. *)
val exec_tree :
  Pgsql_io.t -> Mql_ast.t -> (unit, [> Pgsql_io.err | `Mql_err of Mql.Ast.err ]) result Abb.Future.t

(** [lock_parent parent] builds [LOCK TABLE parent IN EXCLUSIVE MODE], the lock a walk takes first
    thing, before it drops, creates, or drains anything. The mode is the point of the builder:
    EXCLUSIVE conflicts with [ROW EXCLUSIVE], so no store can insert into the parent or any of its
    children while the walk holds it, and it does not conflict with [ACCESS SHARE], so reads keep
    running. The lock recurses to the children, and PostgreSQL holds it to the end of the
    transaction. *)
val lock_parent : string -> Mql_ast.t

(** [stage_default_rows ~parent ~tmp ~from_bound ~to_bound] builds the session-temp copy of the
    default partition's rows of one day. The rows of one day, staged in a session-temp copy of the
    default partition: PostgreSQL refuses to create a partition whose range the default still holds
    rows for, so the rows leave the default before the day's partition is created, and the copy
    keeps them safe meanwhile. The copy carries no constraint of its own, so the insert into the new
    partition -- which carries the parent's primary key -- is where the rows land for good. *)
val stage_default_rows :
  parent:string -> tmp:string -> from_bound:string -> to_bound:string -> Mql_ast.t

(** [delete_default_rows ~parent ~from_bound ~to_bound] builds the [DELETE] that empties the default
    partition of the rows of one day. *)
val delete_default_rows : parent:string -> from_bound:string -> to_bound:string -> Mql_ast.t

(** [create_day_partition ?if_not_exists ~parent ~from_bound ~to_bound n] builds
    [CREATE [IF NOT EXISTS] TABLE n PARTITION OF parent FOR VALUES FROM ('from_bound') TO
     ('to_bound')]. [if_not_exists] defaults to false; the retention walk passes true, because it
    decides which days are uncovered from a snapshot of the catalog a moment earlier, and a
    concurrent run that creates the same day first would otherwise roll the whole table walk back.
*)
val create_day_partition :
  ?if_not_exists:bool ->
  parent:string ->
  from_bound:string ->
  to_bound:string ->
  string ->
  Mql_ast.t

(** [insert_staged ~target ~tmp] builds the [INSERT INTO target SELECT * FROM tmp] that re-houses
    the staged rows. *)
val insert_staged : target:string -> tmp:string -> Mql_ast.t

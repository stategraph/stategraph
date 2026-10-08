let src = Logs.Src.create "migrations"

module Logs = (val Logs.src_log src : Logs.LOG)

module Migrate = struct
  type tx = Pgsql_io.t

  type 'a t = {
    config : Sgs_config.t;
    storage : Pgsql_pool.t;
    tx : 'a;
  }

  type err =
    [ Pgsql_io.err
    | Pgsql_pool.err
    ]

  let create_migrations_table_sql =
    Pgsql_io.Typed_sql.(
      sql
      /^ "create table if not exists migrations (date timestamp default now(), name varchar(256) \
          primary key)")

  let add_migration_sql =
    Pgsql_io.Typed_sql.(sql /^ "insert into migrations (name) values($name)" /% Var.varchar "name")

  (* Get all the migrations but also lock the table so that no other migrations
     may happen at the same time. *)
  let get_migrations_sql =
    Pgsql_io.Typed_sql.(
      sql // Ret.varchar /^ "select name from migrations order by date asc for update")

  let tx { config; storage; tx = _ } f =
    let open Abb.Future.Infix_monad in
    Pgsql_pool.with_conn storage ~f:(fun db ->
        let open Abbs_fc.Infix_result_monad in
        (* Ensure we do not get timed out on a long operation *)
        let idle_tx_sql = Pgsql_io.Typed_sql.(sql /^ "set idle_in_transaction_session_timeout=0") in
        Pgsql_io.Prepared_stmt.execute db idle_tx_sql
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        Pgsql_io.tx db ~f:(fun () ->
            (* Handling errors here as well is to make the type checker happy
               because it gets confused as to what [f] can return and what [tx]
               can return *)
            f { config; storage; tx = db }
            >>= function
            | Ok _ as r -> Abb.Future.return r
            | Error ((`Migration_err #err | `Consistency_err _) as err) -> Abbs_fc.return_err err))
    >>= function
    | Ok _ as r -> Abb.Future.return r
    | Error (#err as err) -> Abbs_fc.return_err (`Migration_err err)
    | Error ((`Migration_err #err | `Consistency_err _) as err) -> Abbs_fc.return_err err

  let get_migrations { config = _; storage = _; tx = db } =
    let open Abbs_fc.Infix_result_monad in
    Pgsql_io.Prepared_stmt.execute db create_migrations_table_sql
    >>= fun () -> Pgsql_io.Prepared_stmt.fetch db get_migrations_sql ~f:CCFun.id

  let add_migration { config = _; storage = _; tx = db } name =
    Pgsql_io.Prepared_stmt.execute db add_migration_sql name

  let start_migration _ name =
    Logs.info (fun m -> m "Performing migration for %s" name);
    Abb.Future.return ()

  let complete_migration _ name =
    Logs.info (fun m -> m "Completed migration for %s" name);
    Abb.Future.return ()

  let list_migrations _ ms =
    Logs.info (fun m -> m "Migrations to perform");
    CCList.iter (fun name -> Logs.info (fun m -> m "%s" name)) ms;
    Abb.Future.return ()
end

module Mig = Data_mig.Make (Migrate)

let run_sql ?(mode = `Tx) sql { Migrate.config = _; storage; tx = db } =
  let conn ~f =
    let open Abbs_fc.Infix_result_monad in
    match mode with
    | `Tx -> f db >>| fun () -> `Sync
    | `Notx -> Pgsql_pool.with_conn storage ~f >>| fun () -> `Sync
    | `Async -> Abbs_fc.return_ok (`Async (fun _ -> Pgsql_pool.with_conn storage ~f))
  in
  (* Deliberately not [Pgsql_io.split_statements]: migrations normalize with
     [clean_string] rather than [trim], so a chunk that is nothing but comments
     is dropped here.  Under the shared trim-based split it would survive and
     then execute as empty SQL. *)
  let stmts =
    sql
    |> CCString.split ~by:";\n\n"
    |> CCList.map Pgsql_io.clean_string
    |> CCList.filter CCFun.(CCString.trim %> CCString.is_empty %> not)
  in
  conn ~f:(fun db ->
      Abbs_fc.List_result.iter
        ~f:(fun stmt ->
          let open Abbs_fc.Infix_result_monad in
          let open Pgsql_io in
          Logs.info (fun m -> m "Performing SQL operation: %s" stmt);
          (* Ensure we do not get timed out on a long operation *)
          let idle_tx_sql = Typed_sql.(sql /^ "set idle_in_transaction_session_timeout=0") in
          Prepared_stmt.execute db idle_tx_sql
          >>= fun () ->
          let stmt_sql = Typed_sql.(sql /^ Pgsql_io.clean_string stmt) in
          Prepared_stmt.execute db stmt_sql)
        stmts)

let migrations =
  [
    ("initial-tables", run_sql [%blob "./migrations/2025-10-25-add-initial-tables.sql"]);
    ("add-user-tables", run_sql [%blob "./migrations/2025-12-08-add-user-tables.sql"]);
    ("add-transactions", run_sql [%blob "./migrations/2025-12-09-add-transactions.sql"]);
    ("add-raw-state", run_sql [%blob "./migrations/2025-12-12-add-raw-state-table.sql"]);
    ("add-oauth2-sessions", run_sql [%blob "./migrations/2026-01-17-add-oauth2-sessions-table.sql"]);
    ( "add-users2-auth-columns",
      run_sql [%blob "./migrations/2026-01-17-add-users2-auth-columns.sql"] );
    ("add-users-avatar-url", run_sql [%blob "./migrations/2026-01-18-add-users-avatar-url.sql"]);
    ( "drop-resources-provider-not-null",
      run_sql [%blob "./migrations/2026-01-20-drop-resources-provider-not-null.sql"] );
    ("add-system-settings", run_sql [%blob "./migrations/2026-01-21-add-system-settings.sql"]);
    ( "add-password-authentication",
      run_sql [%blob "./migrations/2026-01-23-add-password-authentication.sql"] );
    ("add-user-admin-column", run_sql [%blob "./migrations/2026-01-24-add-user-admin-column.sql"]);
    ("add-user-deleted-state", run_sql [%blob "./migrations/2026-01-24-add-user-deleted-state.sql"]);
    ( "add-mode-to-resources-primary-key",
      run_sql [%blob "./migrations/2026-01-27-add-mode-to-primary-key-resources.sql"] );
    ( "add-transaction-log-idx",
      run_sql [%blob "./migrations/2026-01-27-add-transaction-log-idx.sql"] );
    ( "add-states-deleted-columns",
      run_sql [%blob "./migrations/2026-02-06-add-states-deleted-columns.sql"] );
    ("add-gap-analysis-jobs", run_sql [%blob "./migrations/2026-02-09-add-gap-analysis-jobs.sql"]);
    ("add-hcl", run_sql [%blob "./migrations/2026-02-04-add-hcl.sql"]);
    ("add-revisions", run_sql [%blob "./migrations/2026-02-08-add-revisions.sql"]);
    ("add-tasks", run_sql [%blob "./migrations/2026-02-14-add-tasks.sql"]);
    ("add-task-results", run_sql [%blob "./migrations/2026-02-15-add-tasks-results.sql"]);
    ( "add-transaction-previews",
      run_sql [%blob "./migrations/2026-02-15-add-transaction-previews.sql"] );
    ("add-remote-state-ref", run_sql [%blob "./migrations/2026-02-17-add-ref-state-to-hcl-refs.sql"]);
    ( "drop-sync-hcl-refs-trigger",
      run_sql [%blob "./migrations/2026-02-18-drop-sync-hcl-refs-trigger.sql"] );
    ( "add-hcl-remote-state-id",
      run_sql [%blob "./migrations/2026-02-18-add-hcl-remote-state-id.sql"] );
    ( "add-transaction-log-unique-indices",
      run_sql [%blob "./migrations/2026-02-20-add-transaction-log-unique-indices.sql"] );
    ( "add-upsert-tx-logs-function",
      run_sql [%blob "./migrations/2026-02-20-add-upsert-tx-logs-function.sql"] );
    ( "add-reifier-performance-indexes",
      run_sql [%blob "./migrations/2026-02-20-add-reifier-performance-indexes.sql"] );
    ( "add-transaction-subgraphs",
      run_sql [%blob "./migrations/2026-02-22-add-transaction-subgraphs.sql"] );
    ( "add-hcl-refs-cone-index",
      run_sql [%blob "./migrations/2026-02-22-add-hcl-refs-cone-index.sql"] );
    ( "add-hcl-subgraph-function",
      run_sql [%blob "./migrations/2026-02-22-add-hcl-subgraph-function.sql"] );
    ( "drop-hcl-subgraph-function",
      run_sql [%blob "./migrations/2026-02-22-drop-hcl-subgraph-function.sql"] );
    ( "add-previewing-committing-states",
      run_sql [%blob "./migrations/2026-02-23-add-previewing-committing-states.sql"] );
    ("add-outputs-address", run_sql [%blob "./migrations/2026-02-23-add-outputs-address.sql"]);
    ("drop-raw-states-table", run_sql [%blob "./migrations/2026-02-24-drop-raw-states-table.sql"]);
    ( "alter-instances-index-key-to-jsonb",
      run_sql [%blob "./migrations/2026-02-24-alter-instances-index-key-to-jsonb.sql"] );
    ( "add-hcl-module-input-refs",
      run_sql [%blob "./migrations/2026-03-03-add-hcl-module-input-refs.sql"] );
    ( "fix-data-source-addresses",
      run_sql [%blob "./migrations/2026-03-10-fix-data-source-addresses.sql"] );
    ("add-tfvar", run_sql [%blob "./migrations/2026-03-13-add-tfvar.sql"]);
    ( "add-tfvar-tx-log-upsert",
      run_sql [%blob "./migrations/2026-03-16-add-tfvar-tx-log-upsert.sql"] );
    ( "drop-upsert-tx-logs-function",
      run_sql [%blob "./migrations/2026-03-23-drop-upsert-tx-logs-function.sql"] );
    ("add-fq-address", run_sql [%blob "./migrations/2026-03-28-add-fq-address.sql"]);
    ("rename-module-path", run_sql [%blob "./migrations/2026-03-28-rename-module-path.sql"]);
    ("rename-hcl-address", run_sql [%blob "./migrations/2026-03-28-rename-hcl-address.sql"]);
    ("add-hcl-module-inputs", run_sql [%blob "./migrations/2026-03-30-add-hcl-module-inputs.sql"]);
    ("tfvar-node-type", run_sql [%blob "./migrations/2026-04-01-tfvar-node-type.sql"]);
    ("add-task-results-idx", run_sql [%blob "./migrations/2026-04-02-add-task-results-idx.sql"]);
    ("add-hcl-module-source", run_sql [%blob "./migrations/2026-04-03-add-hcl-module-source.sql"]);
    ("add-files", run_sql [%blob "./migrations/2026-04-02-add-files.sql"]);
    ( "add-files-module-address",
      run_sql [%blob "./migrations/2026-04-16-add-files-module-address.sql"] );
    ( "backfill-files-module-address",
      run_sql [%blob "./migrations/2026-04-16-backfill-files-module-address.sql"] );
    (* Refactor ids *)
    ("add-files-id", run_sql [%blob "./migrations/2026-04-20-add-files-id.sql"]);
    (* Raw refs for local-module-output bridging *)
    ("add-hcl-refs-raw-refs", run_sql [%blob "./migrations/2026-04-20-add-hcl-refs-raw-refs.sql"]);
    (* CREATE INDEX CONCURRENTLY must run outside the migration transaction. *)
    ( "add-instances-fq-resource-address-idx",
      run_sql
        ~mode:`Async
        [%blob "./migrations/2026-04-23-add-instances-fq-resource-address-idx.sql"] );
    (* Move [files] PK from (state_id, filepath) to (state_id, id) so that two
       module instances sharing a filepath don't collapse. *)
    ("files-pk-on-id", run_sql [%blob "./migrations/2026-04-24-files-pk-on-id.sql"]);
    (* Drop the transaction_logs filepath-based unique index for file rows;
       node_id is now the uniqueness key. *)
    ( "drop-tx-logs-file-filepath-idx",
      run_sql [%blob "./migrations/2026-04-24-drop-tx-logs-file-filepath-idx.sql"] );
    (* Partial index that powers the per-file module_source lookup in
       select_reifier_subgraph_page.sql. CREATE INDEX CONCURRENTLY must run
       outside the migration transaction. *)
    ( "add-hcl-state-id-module-address-idx",
      run_sql ~mode:`Async [%blob "./migrations/2026-04-28-add-hcl-state-id-module-address-idx.sql"]
    );
    (* Expression index on resources for the index-stripped fq_address used by
       insert_reifier_state_subgraph.sql to match HCL template addresses
       (which lack the [key] index suffix) without a per-row regexp_replace.
       NOTE: superseded by 2026-04-29 migration below, which drops this index
       and replaces it with a plain (state_id, fq_address) index on a new
       HCL-shaped fq_address column. The blob is kept to preserve migration
       history for systems that already applied it. *)
    ( "add-resources-state-id-module-address-idx",
      run_sql
        ~mode:`Async
        [%blob "./migrations/2026-04-28-add-resources-state-id-module-address-idx.sql"] );
    (* Re-shape resources/instances address columns so the HCL-template form
       lives on its own fq_address column and can be joined to hcl.fq_address
       with plain equality. Promotes the existing fq_address (full, with
       module-path indices) to be the primary [address], drops legacy short
       columns, and backfills the new fq_address by stripping '[...]' from
       the existing addresses. *)
    ( "restructure-state-address-columns",
      run_sql [%blob "./migrations/2026-04-29-restructure-state-address-columns.sql"] );
    (* Concurrent btree index on (state_id, fq_address) for both resources
       and instances; powers the index-free state<->HCL equality join. *)
    ( "add-state-fq-address-idx",
      run_sql ~mode:`Async [%blob "./migrations/2026-04-29-add-state-fq-address-idx.sql"] );
    (* Add a generic JSONB params column on transactions for per-transaction
       execution parameters (e.g. skip_refresh -> -refresh=false on terraform
       plan).  Default '{}' keeps existing rows compatible. *)
    ("add-transaction-params", run_sql [%blob "./migrations/2026-04-30-add-transaction-params.sql"]);
    (* module_address: nullable -> NOT NULL with '' as the root-module
       sentinel.  Lets joins use plain = (mergeable / hashable) instead of
       IS NOT DISTINCT FROM, which fell out of the join key as a post-join
       filter and caused a 21s row blow-up in the cone iteration. *)
    ( "module-address-not-null",
      run_sql [%blob "./migrations/2026-04-30-module-address-not-null.sql"] );
    (* Partial concurrent index on hcl_refs(state_id, id) WHERE ref_state_id
       IS NULL — supports same_committed_hcl_refs in the cone CTE, which
       previously seq-scanned + disk-sorted the entire table. *)
    ( "add-hcl-refs-same-state-idx",
      run_sql ~mode:`Async [%blob "./migrations/2026-04-30-add-hcl-refs-same-state-idx.sql"] );
    (* Capture the addresses named by every node's depends_on attribute as a
       separate column on hcl.  These are intentionally not part of [refs]
       (so cone/blast does not pull depends_on targets into the subgraph),
       but the reifier needs them at reify time to rewrite each node's
       depends_on to retain only entries whose target ended up in the
       subgraph by other means. *)
    ( "add-hcl-depends-on-addresses",
      run_sql [%blob "./migrations/2026-04-30-add-hcl-depends-on-addresses.sql"] );
    (* [transaction_subgraphs.boundary_inline]: per-row JSON map carrying the
       slice of boundary state the row needs to inline as literals into its
       HCL.  Null when no substitution applies.  The mark and sweep makes no depth
       cut, so it has no boundary to substitute and [sql/subgraph2/write.sql] never
       fills this column; the per-row rewriter reads null and no-ops. *)
    ( "add-transaction-subgraphs-boundary-inline",
      run_sql [%blob "./migrations/2026-04-30-add-transaction-subgraphs-boundary-inline.sql"] );
    (* Single-migration create+populate+swap that lands hcl_refs in the
       structured-edges shape (new PK, structured columns, no raw_refs).
       Backfill re-parses each hcl row's AST through the same
       [edges_of_references] helper apply_tx uses live, so migrated rows
       match what new code would have written.  See {!Sgs_migrations_ex_685}. *)
    ( "hcl-refs-structured-edges",
      fun { Migrate.config = _; storage = _; tx = db } -> Sgs_migrations_ex_685.run db );
    (* Sgs_migrations_ex_685's create+populate+swap rebuilds hcl_refs via
       [drop table ... cascade] + rename, which re-installs only the PK, the
       FK, and hcl_refs_state_ref_idx.  Three partial ref_state_id indexes
       were dropped with the old table; this restores them as a new
       migration.  CREATE INDEX CONCURRENTLY must run outside the migration
       transaction. *)
    ( "restore-hcl-refs-indexes",
      run_sql ~mode:`Async [%blob "./migrations/2026-05-19-restore-hcl-refs-indexes.sql"] );
    (* Append-only cost snapshots: every cost computation writes a new
       [cost_snapshots] row plus one [cost_snapshot_resources] row per
       resource.  Columns [kind]/[tx_id]/[source] are populated only by
       [kind='current']/[source='estimate'] in Phase 1; [kind='planned'] +
       [tx_id] become live with the preview-time cost delta in Phase 3, and
       additional [source] values reserve room for v2 reconciliation against
       real cloud bills.  [tenant_id]/[tags]/[cloud_resource_id] are
       denormalized at write time so the Phase 2 tenant rollups and tag
       groupings need no backfill. *)
    ("add-cost-snapshots", run_sql [%blob "./migrations/2026-05-19-add-cost-snapshots.sql"]);
    (* Distributed scheduler: schedules table read by Sgs_service_scheduler / Dist_scheduler. *)
    ("add-schedules", run_sql [%blob "./migrations/2026-05-29-add-schedules.sql"]);
    (* Actual cloud spend in FOCUS format (FinOps Open Cost & Usage Spec),
       landed by the out-of-band DuckDB ETL in [code/src/focus_etl]; the OCaml
       app only ever reads this table.  tenant_id / provider are denormalized
       onto every row so providers/tenants coexist and rollups group by them
       without a join; the ETL's idempotent trailing-window DELETE+INSERT is
       keyed on source_id (added just below by [add-focus-billing-source-id]) so
       one source's reload never disturbs another's.  Promoted FOCUS columns
       (periods, the four cost measures, service/resource/region/account
       dimensions, [tags]) are what downstream actual-vs-estimated features
       filter/group/SUM on; [focus_raw] keeps the whole original row so a new
       FOCUS column needs no migration. *)
    ("add-focus-billing", run_sql [%blob "./migrations/2026-06-06-add-focus-billing.sql"]);
    (* Per-tenant FOCUS billing sources (DB-driven config replacing the env-var
       path) and source_id on focus_billing, which becomes the per-source reload
       key so a tenant can run many sources (incl. several of one provider)
       without their windows clobbering each other.  Sources table first --
       focus_billing.source_id references it. *)
    ( "add-focus-billing-sources",
      run_sql [%blob "./migrations/2026-06-06-add-focus-billing-sources.sql"] );
    ( "add-focus-billing-source-id",
      run_sql [%blob "./migrations/2026-06-06-add-focus-billing-source-id.sql"] );
    (* Singleton schedule that drives the scheduler-based FOCUS sync (kind
       handled by Sgs_focus_sync_dispatch); seeded once here. *)
    ( "add-focus-sync-schedule",
      run_sql [%blob "./migrations/2026-06-06-add-focus-sync-schedule.sql"] );
    (* Cost attribution (#868): two derived tables rebuilt by
       Sgs_focus_attribution after every FOCUS sync.  [resource_cloud_ids] is
       the managed-resource -> cloud-identifier index (independent of the
       pricing pipeline, which only records ids for resources it priced);
       [focus_billing_attribution] classifies every focus_billing line as
       attributed / unmanaged / unallocated, its ON DELETE CASCADE riding the
       ETL's trailing-window reload.  matcher_version on both makes better
       matching a recompute, never a migration. *)
    ( "add-focus-billing-attribution",
      run_sql [%blob "./migrations/2026-06-11-add-focus-billing-attribution.sql"] );
    (* Phase 1 security schema: [security_scans] scan envelope +
       [security_scan_findings] per-finding rows, plus source-location
       columns on [resources] for L1 line translation.  Driven by
       [Sgs_security_job] / [Sgs_security_pipeline] / [Sgs_security_store]. *)
    ("add-security-schema", run_sql [%blob "./migrations/2026-06-09-add-security-schema.sql"]);
    (* Durable workflow engine tables backing a future Postgres Dwork.S store. *)
    ("add-dwork-tables", run_sql [%blob "./migrations/2026-06-05-add-dwork-tables.sql"]);
    (* System-wide default capabilities granted to users, stored in
       system_settings under the key 'default_user_caps'.  Users span multiple
       tenants, so this is a global setting rather than a per-tenant column.
       JSONB object keyed by capability name; default enables
       access-token-create, access-token-refresh, commit, and preview. *)
    ( "add-default-user-caps-setting",
      run_sql [%blob "./migrations/2026-06-11-add-default-user-caps-setting.sql"] );
    (* Per-user capabilities (JSONB object keyed by capability name).  Backfills
       the 'admin' capability onto every is_admin user, and likewise onto the
       access tokens of admin users. *)
    ("add-users-capabilities", run_sql [%blob "./migrations/2026-06-11-add-users-capabilities.sql"]);
    (* Drop the now-redundant users.is_admin column.  Admin privileges live in
       the per-user [capabilities] JSONB ('admin' capability), backfilled by
       add-users-capabilities above. *)
    ("drop-user-admin-column", run_sql [%blob "./migrations/2026-06-16-drop-user-admin-column.sql"]);
    ( "add-transaction-subgraph-gc-schedule",
      run_sql
        ~mode:`Async
        [%blob "./migrations/2026-06-16-add-transaction-subgraph-gc-schedule.sql"] );
    (* Full (tenant_id, created_at desc) index for the tenant transaction
       listing (select_tx_page.sql).  The existing tenant/created_at index is
       partial (open transactions only), so the all-states listing seq-scanned +
       sorted.  transaction_logs needs no new index: tx_id lookups already ride
       the leading column of transaction_logs_tx_id_action_object_type_idx.
       CREATE INDEX CONCURRENTLY must run outside the migration transaction. *)
    ( "add-transactions-tenant-created-at-idx",
      run_sql
        ~mode:`Async
        [%blob "./migrations/2026-06-28-add-transactions-tenant-created-at-idx.sql"] );
    (* Serves the per-state actuals read (#830) without scanning the tenant's
       whole bill; partial because only attributed rows carry a state_id.
       CREATE INDEX CONCURRENTLY must run outside the migration transaction. *)
    ( "add-focus-attribution-state-idx",
      run_sql ~mode:`Async [%blob "./migrations/2026-06-12-add-focus-attribution-state-idx.sql"] );
    (* Revert the transaction_subgraph GC: keep every transaction's
       transaction_subgraphs rows indefinitely (they back the run screen and
       security).  Removes the seeded 'transaction_subgraph_gc' schedule and the
       partial open-transactions index that only served the GC's conflict probe.
       DROP INDEX CONCURRENTLY must run outside the migration transaction. *)
    ( "remove-transaction-subgraph-gc",
      run_sql ~mode:`Async [%blob "./migrations/2026-06-30-remove-transaction-subgraph-gc.sql"] );
    (* Add the 'previewed' transaction state, sitting between 'previewing' and
       'committing' in the lifecycle open -> previewing -> previewed ->
       committing -> committed.  Like the other non-terminal states its rows keep
       completed_at NULL. *)
    ("add-previewed-state", run_sql [%blob "./migrations/2026-07-05-add-previewed-state.sql"]);
    (* Terminal state for an apply (commit) that ran and failed, distinct from the generic
       'failed' produced by a preview/plan failure. Reached only from 'committing'. *)
    ( "add-failed-committed-state",
      run_sql [%blob "./migrations/2026-07-05-add-failed-committed-state.sql"] );
    (* Schema for the per-tx (plan-time) security impact: the lifecycle-FK indexes
       (first_seen_scan_id, resolved_scan_id) on security_scan_findings the
       planned-scan abort/GC cleanup probes. *)
    ( "add-security-tx-impact-schema",
      run_sql ~mode:`Async [%blob "./migrations/2026-06-22-add-security-tx-impact-schema.sql"] );
    (* Tracks HCL entries tainted by a failed-committed apply: they must plan as changed until a
       successful commit clears them. *)
    ("add-hcl-tainted", run_sql [%blob "./migrations/2026-07-05-add-hcl-tainted.sql"]);
    (* Add a generated [module_] column to outputs (mirroring resources.module_)
       so the remote-module state-subgraph join can equi-join outputs by module
       path instead of an O(remote_modules x outputs) prefix-LIKE cartesian. *)
    ("add-outputs-module", run_sql [%blob "./migrations/2026-07-04-add-outputs-module.sql"]);
    (* Per-HCL-row [${path.*}]-anchored attribute metadata (attr/kind/suffix), detected at
       tx-log time and consumed by reification to rewrite persisted path values. *)
    ("add-hcl-path-attrs", run_sql [%blob "./migrations/2026-07-09-add-hcl-path-attrs.sql"]);
    (* Per-tx read cache for the reified subgraph page reader: materializes the
       select_reifier_subgraph_page.sql enrichment once at generation so bundle
       downloads become a (tx_id, cursor_id) range scan instead of re-running 7
       CTEs over the whole tx's transaction_logs on every page. Populated by
       Sgs_bundler.generate_subgraph; GC'd on tx terminal states and hard-delete. *)
    ( "add-transaction-subgraph-nodes",
      run_sql [%blob "./migrations/2026-07-14-add-transaction-subgraph-nodes.sql"] );
    (* The reified canon placement (md5-dir + basename) of an escaping file read, on the files table
       so reification from committed state (the post-apply re-plan) can locate the staged bytes. *)
    ("add-files-placement", run_sql [%blob "./migrations/2026-07-17-add-files-placement.sql"]);
    (* A preview's plan has no inherent size bound, so storing it as one jsonb value hits
       PostgreSQL's 1GB per-value ceiling on a large enough config. Mirrors the (task_id, idx) shape
       already used by task_results so a preview can be split across rows. *)
    ( "add-transaction-previews-idx",
      run_sql [%blob "./migrations/2026-07-18-add-transaction-previews-idx.sql"] );
    (* A preview's plan arrives from the actuator already base64-encoded, so the stored JSON used to
       encode it a second time. Dropping that layer changes the stored shape, and base64-of-base64
       is itself valid base64, so a stale row cannot be told from a current one by inspection --
       left in place it would decode to base64 text where the CLI expects plan bytes and hand a
       corrupt plan to tofu. Previews are re-derivable, so discard them and let the read miss:
       [Sg_tx_preview_db.fetch] returns Not_found and the user re-runs the plan. *)
    ( "clear-stale-transaction-previews",
      run_sql [%blob "./migrations/2026-07-19-clear-stale-transaction-previews.sql"] );
    ("add-hcl-hints", run_sql [%blob "./migrations/2026-07-22-add-hcl-hints.sql"]);
    (* The placement columns named a staging bucket the reified read located by having tofu recompute
       [md5(canon)] at plan time. The reifier emits the bundle path as a literal now, and
       [Sg_bundle_paths.classify] derives it on both the staging and the read side, so there is
       nothing left to store. *)
    ("drop-files-placement", run_sql [%blob "./migrations/2026-07-29-drop-files-placement.sql"]);
    (* The 'admin' capability became a tenant-scoped object, so the stored booleans are rewritten
       into the new shape; existing admins keep the access they had. *)
    ("scope-admin-capability", run_sql [%blob "./migrations/2026-07-29-scope-admin-capability.sql"]);
    (* The state hash id is per-(tx, state), not per-state, so it cannot be joined at read time. The
       page reader was rebuilding the whole-tx mangler on every page to answer it per row; carry it
       on the row instead. *)
    ( "add-subgraph-node-state-hash-id",
      run_sql [%blob "./migrations/2026-07-29-add-subgraph-node-state-hash-id.sql"] );
    (* A file's bundle destination can depend on the canonical path expression carried by the HCL row
       that reads it, which the page reader could only see when the two shared a page. Resolve it
       once at generation and store it on the file row. *)
    ( "add-subgraph-file-targets",
      run_sql [%blob "./migrations/2026-07-29-add-subgraph-file-targets.sql"] );
    (* Stategraph's own schema version for a state's HCL-derived data. Representation changes that
       are computed from the original config (hcl.file_refs, path_attrs, hints) cannot be back-filled
       by SQL, so the migration for them is a re-import; this records which representation a state's
       data is at so a client can tell it is behind. Defaults to 0 against a
       [Sg_state_schema_version.version] of 1, so every existing state reads as behind. *)
    ( "add-states-schema-version",
      run_sql [%blob "./migrations/2026-07-30-add-states-schema-version.sql"] );
    (* The client's state schema version, recorded on the transaction that carried its entries, so an
       import-shaped apply can stamp it onto the states it rewrites. *)
    ( "add-transactions-schema-version",
      run_sql [%blob "./migrations/2026-07-30-add-transactions-schema-version.sql"] );
    (* RFD 1377: the transaction-log action for a tfvar that must never be committed, never seed the
       subgraph, and be masked in MQL. *)
    ("add-tfvar-ephemeral", run_sql [%blob "./migrations/2026-08-10-add-tfvar-ephemeral.sql"]);
    (* The #1409 tenant-administration schema, as one migration: the tenant_users join timestamp the
       cursor-paginated members list orders by, the tenants.name floor the rename endpoint needs, the
       emailed-invitation tables (state owned here so accepting is one transaction with the membership
       insert), and the access_tokens.kind that makes browser sign-ins revocable login sessions. *)
    ( "add-tenant-administration",
      run_sql [%blob "./migrations/2026-07-30-add-tenant-administration.sql"] );
    (* A [for_each] instance key was rendered into the stored address without the quotes tofu writes
       it with, so an instance sat at [foo[a]] rather than [foo["a"]] -- an address Terraform cannot
       parse, and one that will not match the [previous_address] a move is reported under. The
       renderer is fixed alongside this; the migration rewrites the rows it already wrote. *)
    ( "quote-foreach-index-keys",
      run_sql [%blob "./migrations/2026-08-11-quote-foreach-index-keys.sql"] );
    (* Terrateam VCS installation -> tenant mapping: the anchor for tenant-scoping MQL reads of
       terrateam tables over the FDW bridge. *)
    ( "add-tenant-vcs-installations",
      run_sql [%blob "./migrations/2026-08-09-add-tenant-vcs-installations.sql"] );
    (* A collected file's on-disk permission bits. [archive_file] hashes each zip member's mode along
       with its bytes, so staging every file at one mode moves the archive's hash off what tofu
       computes over the same tree. Defaults to 0o600 -- what the actuator stages today -- so an
       existing row keeps its current behavior until the schema-version re-import supplies the real
       mode. *)
    ("add-files-mode", run_sql [%blob "./migrations/2026-08-11-add-files-mode.sql"]);
    (* hcl_refs' key did not include [ref_state_id], so a consumer reading two remote states that
       export the same output name in one expression wrote two rows that differed only in that
       column and [insert_remote_refs]' [on conflict do nothing] dropped the second.  Replaces the
       primary key with a NULLS NOT DISTINCT unique index over the same columns plus
       [ref_state_id].  CREATE INDEX CONCURRENTLY must run outside the migration transaction. *)
    ( "hcl-refs-unique-with-ref-state",
      run_sql ~mode:`Async [%blob "./migrations/2026-08-14-hcl-refs-unique-with-ref-state.sql"] );
    (* base_capabilities seeds itself from the current capabilities column, so it must run AFTER
       scope-admin-capability has rewritten the admin booleans into their tenant-scoped object shape
       -- otherwise base would capture a boolean admin that no longer deserializes into
       Sgs_session_caps_admin.t option. Keep these two entries adjacent and in this order, after
       scope-admin-capability. *)
    ( "add-users-base-capabilities",
      run_sql [%blob "./migrations/2026-07-01-add-users-base-capabilities.sql"] );
    ("add-caps-group-rules", run_sql [%blob "./migrations/2026-07-01-add-caps-group-rules.sql"]);
    (* Alters the table [add-caps-group-rules] created, so it must run after it. *)
    ( "tenant-scope-caps-group-rules",
      run_sql [%blob "./migrations/2026-08-26-tenant-scope-caps-group-rules.sql"] );
    (* Run-detail (tx detail) storage: per-resource plan operations persisted at preview-finalize
       (the run-detail plan tree and the tx list/detail plan summaries), and the tx -> apply-task
       link the Apply tab resolves the captured apply stdout through. *)
    ("add-tx-detail", run_sql [%blob "./migrations/2026-08-10-add-tx-detail.sql"]);
    (* Tells the session JWT signing key apart from the pre-RS256 HMAC secrets that
       share the table. The RSA row is written by the server on first boot, not
       here: postgres cannot generate an RSA key. *)
    ( "add-encryption-key-type",
      run_sql [%blob "./migrations/2026-09-04-add-encryption-key-type.sql"] );
    (* RFD 584: the [refresh] action and object_type ids for the log entry a plan appends when the
       configuration has not changed, so a data source whose result moved still opens a
       transaction. *)
    ("add-refresh-tx-log", run_sql [%blob "./migrations/2026-08-15-add-refresh-tx-log.sql"]);
    (* RFD 2172: whether the walk must seed a block whatever the change is -- a [terraform_data]
       whose [triggers_replace] is [timestamp()] and its kin.  The rule was the client's; the
       column is where the engine's answer lands, and the walk filters on it. *)
    ( "add-hcl-unconditional-seed",
      run_sql [%blob "./migrations/2026-09-11-add-hcl-unconditional-seed.sql"] );
    (* The capability columns in the decision-tree shape, the backfill that fills them from the
       columns they replace, and the constraint that says every row has one. Keep the three adjacent
       and in this order: each needs what the one before it did, and the backfill reads
       [base_capabilities], so they must also run after [add-users-base-capabilities]. *)
    ("add-capability-trie", run_sql [%blob "./migrations/2026-09-17-add-capability-trie.sql"]);
    ( "backfill-capability-trie",
      fun { Migrate.config = _; storage = _; tx = db } -> Sgs_migrations_ex_capability_trie.run db
    );
    ( "capability-trie-not-null",
      run_sql [%blob "./migrations/2026-09-17-capability-trie-not-null.sql"] );
    (* [misses] on [schedules]: how many times a task has triggered with nobody registered to run
       it. The dispatcher records a miss on every trigger, re-runs the task on its next schedule,
       and deletes the row at three. *)
    ("schedule-misses", run_sql [%blob "./migrations/2026-10-04-schedule-misses.sql"]);
  ]

let run config storage = Mig.run { Migrate.config; storage; tx = () } migrations

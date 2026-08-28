module Migrate = struct
  type tx = Pgsql_io.t

  type 'a t = {
    config : Terrat_config.t;
    storage : Terrat_storage.t;
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
        let open Abbs_future_combinators.Infix_result_monad in
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
            | Error ((`Migration_err #err | `Consistency_err) as err) ->
                Abbs_future_combinators.return_err err))
    >>= function
    | Ok _ as r -> Abb.Future.return r
    | Error (#err as err) -> Abbs_future_combinators.return_err (`Migration_err err)
    | Error ((`Migration_err #err | `Consistency_err) as err) ->
        Abbs_future_combinators.return_err err

  let get_migrations { config = _; storage = _; tx = db } =
    let open Abbs_future_combinators.Infix_result_monad in
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

let run_sql ?(mode = `Tx) sql_contents { Migrate.config = _; storage; tx = db } =
  let conn ~f =
    let open Abbs_future_combinators.Infix_result_monad in
    match mode with
    | `Tx -> f db >>| fun () -> `Sync
    | `Notx -> Pgsql_pool.with_conn storage ~f >>| fun () -> `Sync
    | `Async ->
        Abbs_future_combinators.return_ok (`Async (fun _ -> Pgsql_pool.with_conn storage ~f))
  in
  let stmts =
    sql_contents
    |> CCString.split ~by:";\n\n"
    |> CCList.filter CCFun.(CCString.trim %> CCString.is_empty %> not)
  in
  conn ~f:(fun db ->
      Abbs_future_combinators.List_result.iter
        ~f:(fun stmt ->
          let open Abbs_future_combinators.Infix_result_monad in
          let open Pgsql_io in
          Logs.info (fun m -> m "Performing SQL operation: %s" stmt);
          (* Ensure we do not get timed out on a long operation *)
          let idle_tx_sql = Typed_sql.(sql /^ "set idle_in_transaction_session_timeout=0") in
          Prepared_stmt.execute db idle_tx_sql
          >>= fun () ->
          let stmt_sql = Typed_sql.(sql /^ Pgsql_io.clean_string stmt) in
          Prepared_stmt.execute db stmt_sql)
        stmts)

let add_encryption_key { Migrate.config = _; storage = _; tx = db } =
  let open Abbs_future_combinators.Infix_result_monad in
  let key = Mirage_crypto_rng.generate 64 in
  let insert_encryption_key =
    Pgsql_io.Typed_sql.(
      sql
      /^ "insert into encryption_keys (rank, data) values(0, decode($data, 'base64'))"
      /% Var.(ud (text "data") Base64.encode_exn))
  in
  Pgsql_io.Prepared_stmt.execute db insert_encryption_key key >>| fun () -> `Sync

let add_gitlab_token_from_config { Migrate.config; storage = _; tx = db } =
  let open Abbs_future_combinators.Infix_result_monad in
  let module Gc = Terrat_config.Gitlab in
  let add_gitlab_token_from_config () =
    Pgsql_io.Typed_sql.(
      sql
      /^ "update gitlab_installations set access_token = $access_token_from_terrat_config"
      /% Var.text "access_token_from_terrat_config")
  in
  match Terrat_config.gitlab config with
  | Some gc ->
      let access_token = Gc.access_token gc in
      Pgsql_io.Prepared_stmt.execute db (add_gitlab_token_from_config ()) access_token
      >>| fun () -> `Sync
  | None -> Abbs_future_combinators.return_ok `Sync

let migrations =
  [
    ("initial-tables", run_sql [%blob "migrations/2021-12-03-initial-tables.sql"]);
    ("add-github-installation", run_sql [%blob "migrations/2021-12-29-add-github-installation.sql"]);
    ("add-github-unlock", run_sql [%blob "migrations/2022-04-19-add-github-unlock.sql"]);
    ("add-github-merged-sha", run_sql [%blob "migrations/2022-04-26-add-merged-sha.sql"]);
    ("add-github-merged_at", run_sql [%blob "migrations/2022-04-26-add-merged_at.sql"]);
    ("drop-plan-text", run_sql [%blob "migrations/2022-05-01-remove-plan-text.sql"]);
    ("add-unsafe-apply", run_sql [%blob "migrations/2022-09-01-add-unsafe-apply.sql"]);
    ("add-access-denied", run_sql [%blob "migrations/2022-10-29-add-access-denied.sql"]);
    ("add-drift", run_sql [%blob "migrations/2023-01-30-add-drift-tables.sql"]);
    ("add-drift-unlock", run_sql [%blob "migrations/2023-02-14-add-drift-unlock.sql"]);
    ("add-encryption-keys-table", run_sql [%blob "migrations/2023-02-22-add-encryption-keys.sql"]);
    ("add-encryption-key", add_encryption_key);
    ( "add-github-account-status",
      run_sql [%blob "migrations/2023-05-15-add-github-account-status.sql"] );
    ("add-lock-policy", run_sql [%blob "migrations/2023-05-17-add-lock-policy.sql"]);
    ("add-lock-policy-none", run_sql [%blob "migrations/2023-05-20-add-lock-policy-none.sql"]);
    ( "remove-github-repo-constraint",
      run_sql [%blob "migrations/2023-08-02-remove-github-repo-constraint.sql"] );
    ( "add-base-sha-to-github-dirspaces-pkey",
      run_sql [%blob "migrations/2023-11-09-add-base-sha-to-github-dirspaces-pkey.sql"] );
    ("refactor-users", run_sql [%blob "migrations/2023-09-25-refactor-users.sql"]);
    ("refactor-user-sessions", run_sql [%blob "migrations/2023-09-25-refactor-user-sessions.sql"]);
    ( "refactor-user-sessions-user-agent",
      run_sql [%blob "migrations/2023-09-25-refactor-user-sessions-user-agent.sql"] );
    ("remove-github-users-id", run_sql [%blob "migrations/2023-09-25-remove-github-users-id.sql"]);
    ( "make-user-session-token-autogen",
      run_sql [%blob "migrations/2023-09-26-make-user-session-token-autogen.sql"] );
    ("add-pull-request-title", run_sql [%blob "migrations/2023-10-10-add-pull-request-title.sql"]);
    ( "add-user-track-on-work-manifest",
      run_sql [%blob "migrations/2023-11-15-add-user-track-on-work-manifest.sql"] );
    ( "add-user-track-on-pull-request",
      run_sql [%blob "migrations/2023-11-15-add-user-track-on-pull-request.sql"] );
    ( "add-user-installations-table",
      run_sql [%blob "migrations/2023-11-18-add-user-installations-table.sql"] );
    ("add-tasks-table", run_sql [%blob "migrations/2023-12-18-add-tasks-table.sql"]);
    ( "add-json-dirspaces-to-work-manifests",
      run_sql [%blob "migrations/2024-01-02-add-json-dirspaces-to-work-manifests.sql"] );
    ( "add-work-manifest-run-kind",
      run_sql [%blob "migrations/2024-02-02-add-work-manifest-run-kind.sql"] );
    ("add-github-code-index-table", run_sql [%blob "migrations/2024-02-05-add-code-index-table.sql"]);
    ( "add-index-work-manifests",
      run_sql [%blob "migrations/2024-02-07-add-index-work-manifest-table.sql"] );
    ( "add-code-index-created_at",
      run_sql [%blob "migrations/2024-02-14-add-code-index-created_at.sql"] );
    ( "add-drift-schedule-updated_at",
      run_sql [%blob "migrations/2024-03-02-add-drift-schedule-updated_at.sql"] );
    ("add-drift-tag-query", run_sql [%blob "migrations/2024-03-06-add-drift-tag-query.sql"]);
    ("add-repo-setup-flag", run_sql [%blob "migrations/2024-03-28-add-repo-setup-flag.sql"]);
    ( "add-work-manifest-environment",
      run_sql [%blob "migrations/2024-04-22-add-work-manifest-environment.sql"] );
    ("add-work-manifest-steps", run_sql [%blob "migrations/2024-08-02-add-work-manifest-steps.sql"]);
    ("add-flow-states", run_sql [%blob "migrations/2024-08-11-add-flow-states.sql"]);
    ("add-config-builder", run_sql [%blob "migrations/2024-09-15-add-config-builder-tables.sql"]);
    ("add-step-output-table", run_sql [%blob "migrations/2024-10-11-add-step-output-table.sql"]);
    ( "remake-step-output-table",
      run_sql [%blob "migrations/2024-11-22-remake-step-output-table.sql"] );
    ( "add-has_changes-to-plans",
      run_sql [%blob "migrations/2024-12-07-add-has_changes-to-plans.sql"] );
    ("add-trial-columns", run_sql [%blob "migrations/2025-01-14-add-trial-columns.sql"]);
    ( "add-multiple-drift-schedules",
      run_sql [%blob "migrations/2025-02-15-add-multiple-drift-schedules.sql"] );
    ("add-gatekeeping", run_sql [%blob "migrations/2025-03-30-add-gatekeeping.sql"]);
    ("add-tiers", run_sql [%blob "migrations/2025-04-05-add-tiers.sql"]);
    ("add-users2-tables", run_sql [%blob "migrations/2025-04-07-refactor-user-tables.sql"]);
    ("add-tree-builder", run_sql [%blob "migrations/2025-04-11-add-tree-builder.sql"]);
    ( "refactor-rename-core-tables",
      run_sql [%blob "migrations/2025-04-21-refactor-rename-core-tables.sql"] );
    ( "refactor-remove-core-table-views",
      run_sql [%blob "migrations/2025-04-21-refactor-delete-core-table-views.sql"] );
    ( "add-work-manifest-runs-on",
      run_sql [%blob "migrations/2025-04-29-add-work-manifest-runs-on.sql"] );
    ( "refactor-prep-github-vcs-mapping",
      run_sql [%blob "migrations/2025-04-28-refactor-prep-for-github-vcs-mapping.sql"] );
    ( "refactor-fill-in-missing-github-maps",
      run_sql [%blob "migrations/2025-05-01-refactor-fill-in-missing-github-maps.sql"] );
    ("add-repo-tree-id-column", run_sql [%blob "migrations/2025-05-13-add-repo-tree-id-column.sql"]);
    ( "refactor-fill-in-missing-core-ids",
      fun { Migrate.config; storage; tx = _ } ->
        Abbs_future_combinators.return_ok
          (`Async (fun _ -> Terrat_migrations_ex_150.fill_in_all (config, storage))) );
    ( "refactor-remove-null-constraints-on-core-tables",
      run_sql [%blob "migrations/2025-05-19-refactor-remove-null-constraints.sql"] );
    ( "refactor-add-pkey-indexes",
      run_sql ~mode:`Async [%blob "migrations/2025-05-19-refactor-add-pkey-indexes.sql"] );
    ( "refactor-add-core-table-constraints",
      run_sql [%blob "migrations/2025-05-21-refactor-add-core-table-constraints.sql"] );
    ( "refactor-swap-primary-keys",
      run_sql [%blob "migrations/2025-05-01-refactor-swap-primary-keys.sql"] );
    ( "refactor-drop-legacy-github-columns",
      run_sql [%blob "migrations/2025-05-02-refactor-remove-old-columns.sql"] );
    ("fix-slow-applied-dirspace-query", run_sql [%blob "migrations/2025-05-25-fix-slow-queries.sql"]);
    ("add-gitlab-user-tables", run_sql [%blob "migrations/2025-06-09-add-gitlab-user-tables.sql"]);
    ( "add-gitlab-installations",
      run_sql [%blob "migrations/2025-06-16-add-gitlab-installations.sql"] );
    ( "add-pull-request-complete-column",
      run_sql [%blob "migrations/2025-06-30-add-pull-request-complete-column.sql"] );
    ( "add-pull-request-query-indices",
      run_sql ~mode:`Async [%blob "migrations/2025-07-01-add-pull-request-query-indices.sql"] );
    ( "refactor-github-dirspace-locking-phase-1",
      run_sql [%blob "migrations/2025-07-07-refactor-github-dirspace-locking-phase-1.sql"] );
    ( "refactor-github-dirspace-locking-phase-2",
      run_sql [%blob "migrations/2025-07-07-refactor-github-dirspace-locking-phase-2.sql"] );
    ( "refactor-github-dirspace-locking-phase-3.1",
      fun { Migrate.config; storage; tx = _ } ->
        Abbs_future_combinators.return_ok
          (`Async (fun _ -> Terrat_migrations_ex_568.run_github (config, storage))) );
    ( "refactor-gihtub-dirspace-locking-phase-3.2",
      run_sql [%blob "migrations/2025-07-09-refactor-github-dirspace-locking-phase-3.sql"] );
    ( "refactor-gitlab-dirspace-locking-phase-1",
      run_sql [%blob "migrations/2025-07-14-refactor-gitlab-dirspace-locking-phase-1.sql"] );
    ( "refactor-gitlab-dirspace-locking-phase-2",
      fun { Migrate.config; storage; tx = _ } ->
        Abbs_future_combinators.return_ok
          (`Async (fun _ -> Terrat_migrations_ex_568.run_gitlab (config, storage))) );
    ( "refactor-gitlab-dirspace-locking-phase-3",
      run_sql [%blob "migrations/2025-07-14-refactor-gitlab-dirspace-locking-phase-3.sql"] );
    ( "fix-make-gitlab-tables-closer-to-github",
      run_sql [%blob "migrations/2025-07-15-fix-make-gitlab-tables-match-github-closer.sql"] );
    ( "refactor-manage-github-maps-via-triggers",
      run_sql [%blob "migrations/2025-07-22-refactor-manage-github-maps-via-triggers.sql"] );
    ( "fix-gitlab-installation-state",
      run_sql [%blob "migrations/2025-07-21-fix-gitlab-installation-state.sql"] );
    ("add-github-emails-table", run_sql [%blob "migrations/2025-08-19-add-emails-table.sql"]);
    ("add-comment-tracking", run_sql [%blob "migrations/2025-08-20-add-comment-tracking.sql"]);
    ( "fix-missing-repository-mappings",
      run_sql [%blob "migrations/2025-08-21-fix-missing-repository-mappings.sql"] );
    ( "refactor-gates-primary-key",
      run_sql [%blob "migrations/2025-09-04-refactor-gates-primary-key.sql"] );
    ("add-primary-email-field", run_sql [%blob "migrations/2025-09-09-add-primary-email-field.sql"]);
    ("fix-drift-unlock-abort-wm", run_sql [%blob "migrations/2025-09-09-fix-drift-unlock.sql"]);
    ("fix-unlocked-prs", run_sql [%blob "migrations/2025-09-23-fix-unlocked-prs.sql"]);
    ( "add-repo-created_at-index",
      run_sql ~mode:`Async [%blob "migrations/2025-09-23-add-repo-created_at-index.sql"] );
    ("add-kv-store", run_sql [%blob "migrations/2025-09-17-add-kv-store.sql"]);
    ("add-access-token-table", run_sql [%blob "migrations/2025-09-24-add-access-token-table.sql"]);
    ( "refactor-gitlab-access-tokens",
      run_sql [%blob "migrations/2025-10-06-refactor-gitlab-tokens.sql"] );
    ("add-gitlab-token-from-config", add_gitlab_token_from_config);
    ("add-stacks", run_sql [%blob "migrations/2025-10-22-add-stacks.sql"]);
    ("add-plans-cleanup-idx", run_sql [%blob "migrations/2025-11-04-add-plans-cleanup-idx.sql"]);
    ("add-kv-store-caps", run_sql [%blob "migrations/2025-11-05-add-kv-store-caps.sql"]);
    ("refactor-work-manifests", run_sql [%blob "migrations/2025-07-24-refactor-work-manifests.sql"]);
    ("add-builder-tables", run_sql [%blob "migrations/2025-07-24-add-builder-tables.sql"]);
    ("add-drift-branch", run_sql [%blob "migrations/2026-01-08-add-drift-branch.sql"]);
    ( "delete-existing-repo-tree-cache",
      run_sql [%blob "migrations/2026-03-19-delete-repo-tree-cache.sql"] );
    ( "extend-repo-configs-with-history",
      run_sql [%blob "migrations/2026-07-05-extend-repo-configs-with-history.sql"] );
    ("add-tasks-user-id", run_sql [%blob "migrations/2026-07-23-add-tasks-user-id.sql"]);
    ("add-repo-tree-builds", run_sql [%blob "migrations/2026-07-21-add-repo-tree-builds.sql"]);
    ( "add-pull-request-sha-indices",
      run_sql ~mode:`Async [%blob "migrations/2026-08-21-add-pull-request-sha-indices.sql"] );
  ]

let run config storage = Mig.run { Migrate.config; storage; tx = () } migrations

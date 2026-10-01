-- Tenant-scoped CTEs over the terrateam foreign tables (#1442 Phase 2).
--
-- Spliced into select_mql_page.sql at {{terrateam_ctes}} when orchestration
-- is enabled; never present otherwise (the foreign tables only exist when the
-- FDW reconcile has run). Same invariant as the base file: every terrateam
-- table in the MQL schema resolves HERE to a CTE whose rows are reachable
-- only from the caller's tenants. The anchor joins tenant_vcs_installations
-- (who owns which installation) against the scoped [tenants] CTE from the
-- base file; every other CTE chains to the anchor through its provider's
-- installation/repository/pull-request/work-manifest path, so scoping is
-- transitive. That chain is enforced by exactly one test:
-- code/src/sgs_test/sgs_test_mql_terrateam_scoping.ml, which seeds two
-- tenants and asserts each CTE returns only its caller's rows. The checks in
-- code/tests/sgs_mql pin CTE names and projections, nothing more -- a CTE
-- whose where clause were deleted passes every one of them.
--
-- Projections list exactly the catalog columns (code/tests/sgs_mql pins
-- them to the schema fragment), so a catalog change that misses this file
-- fails CI instead of 500ing at query time.
--
-- The helper CTEs (tenant_installation_core_ids, *_installation_ids) are
-- LEFT plain -- materialised -- on purpose, like the base file's anchors: they
-- are small per-tenant id sets referenced by many sibling CTEs, and
-- materialising them computes each once instead of re-shipping the same FDW
-- scan per referent. The per-table CTEs are `not materialized` so predicates
-- push down into the foreign scan (#1070).
--
-- PERFORMANCE (#2469): postgres_fdw ships a WHERE clause only when it is built
-- from constants, parameters and shippable expressions. A semi-join against a
-- local relation -- a materialised CTE included -- is not one, so the remote
-- scan returns the whole table and the filter, sort and limit run here. The
-- anchors therefore read the helper CTEs through `= any(array(select ...))`:
-- an uncorrelated ARRAY subquery is an InitPlan, and postgres_fdw ships its
-- value as a remote parameter. Every CTE below the anchors reaches them
-- through foreign tables only, so postgres_fdw ships those semi-joins as well
-- (PostgreSQL 17+).
--
-- #2469: A table that a work manifest keys (work_manifest_dirspaceflows,
-- work_manifest_results, drift_work_manifests, workflow_step_outputs, plans)
-- has one scan only. It is scoped through terrateam.work_manifests, the base
-- table of the *_work_manifests views, which has no provider. The scope is the
-- repository core ids of the tenant, from the *_repositories_map CTEs. One
-- UNION ALL arm per provider makes an Append. postgres_fdw cannot send a join
-- with an Append to the remote server, thus a join of github_work_manifests
-- and workflow_step_outputs read all step rows of the tenant, payload
-- included. The other shared tables keep one UNION ALL arm per provider,
-- because a semi-join over an Append is never shipped.
--
-- These changes are necessary only because the foreign data wrapper
-- abstraction is leaky. The same SQL on local tables does not need them.
tenant_installation_core_ids as (
  select
    tvi.provider as provider,
    tvi.installation_core_id as installation_core_id
  from tenant_vcs_installations as tvi
  inner join tenants as t
    on t.id = tvi.tenant_id
),
github_installation_ids as (
  select m.installation_id as installation_id
  from terrateam.github_installations_map as m
  where m.core_id = any(array(select installation_core_id from tenant_installation_core_ids where provider = 'github'))
),
gitlab_installation_ids as (
  select m.installation_id as installation_id
  from terrateam.gitlab_installations_map as m
  where m.core_id = any(array(select installation_core_id from tenant_installation_core_ids where provider = 'gitlab'))
),
github_installations_map as not materialized (
  select
    gim.installation_id as installation_id,
    gim.core_id as core_id
  from terrateam.github_installations_map as gim
  where gim.core_id = any(array(select installation_core_id from tenant_installation_core_ids where provider = 'github'))
),
gitlab_installations_map as not materialized (
  select
    gim.installation_id as installation_id,
    gim.core_id as core_id
  from terrateam.gitlab_installations_map as gim
  where gim.core_id = any(array(select installation_core_id from tenant_installation_core_ids where provider = 'gitlab'))
),
github_installations as not materialized (
  select
    gi.created_at as created_at,
    gi.id as id,
    gi.login as login,
    gi.org as org,
    gi.state as state,
    gi.target_type as target_type,
    gi.updated_at as updated_at,
    gi.account_status as account_status,
    gi.trial_ends_at as trial_ends_at,
    gi.tier as tier,
    gi.last_suspended_by as last_suspended_by,
    gi.last_suspended_at as last_suspended_at,
    gi.last_unsuspended_by as last_unsuspended_by,
    gi.last_unsuspended_at as last_unsuspended_at,
    gi.installed_by as installed_by,
    gi.uninstalled_by as uninstalled_by,
    gi.uninstalled_at as uninstalled_at
  from terrateam.github_installations as gi
  where gi.id = any(array(select installation_id from github_installation_ids))
),
gitlab_installations as not materialized (
  select
    gi.account_status as account_status,
    gi.created_at as created_at,
    gi.id as id,
    gi.name as name,
    gi.state as state,
    gi.tier as tier,
    gi.trial_ends_at as trial_ends_at
  from terrateam.gitlab_installations as gi
  where gi.id = any(array(select installation_id from gitlab_installation_ids))
),
github_installation_repositories as not materialized (
  select
    gir.id as id,
    gir.installation_id as installation_id,
    gir.name as name,
    gir.owner as owner,
    gir.updated_at as updated_at,
    gir.setup as setup
  from terrateam.github_installation_repositories as gir
  where gir.installation_id = any(array(select installation_id from github_installation_ids))
),
gitlab_installation_repositories as not materialized (
  select
    gir.created_at as created_at,
    gir.id as id,
    gir.installation_id as installation_id,
    gir.name as name,
    gir.owner as owner,
    gir.updated_at as updated_at,
    gir.setup as setup
  from terrateam.gitlab_installation_repositories as gir
  where gir.installation_id = any(array(select installation_id from gitlab_installation_ids))
),
github_repositories_map as not materialized (
  select
    grm.repository_id as repository_id,
    grm.core_id as core_id
  from terrateam.github_repositories_map as grm
  where grm.repository_id in (select id from github_installation_repositories)
),
gitlab_repositories_map as not materialized (
  select
    grm.repository_id as repository_id,
    grm.core_id as core_id
  from terrateam.gitlab_repositories_map as grm
  where grm.repository_id in (select id from gitlab_installation_repositories)
),
github_pull_requests as not materialized (
  select
    gpr.base_branch as base_branch,
    gpr.base_sha as base_sha,
    gpr.branch as branch,
    gpr.pull_number as pull_number,
    gpr.repository as repository,
    gpr.sha as sha,
    gpr.state as state,
    gpr.merged_sha as merged_sha,
    gpr.merged_at as merged_at,
    gpr.title as title,
    gpr.username as username,
    gpr.created_at as created_at
  from terrateam.github_pull_requests as gpr
  where gpr.repository in (select id from github_installation_repositories)
),
gitlab_pull_requests as not materialized (
  select
    gpr.base_branch as base_branch,
    gpr.base_sha as base_sha,
    gpr.branch as branch,
    gpr.merged_at as merged_at,
    gpr.merged_sha as merged_sha,
    gpr.pull_number as pull_number,
    gpr.repository as repository,
    gpr.sha as sha,
    gpr.state as state,
    gpr.title as title,
    gpr.username as username
  from terrateam.gitlab_pull_requests as gpr
  where gpr.repository in (select id from gitlab_installation_repositories)
),
github_pull_requests_map as not materialized (
  select
    gprm.repository_id as repository_id,
    gprm.pull_number as pull_number,
    gprm.core_id as core_id
  from terrateam.github_pull_requests_map as gprm
  where gprm.repository_id in (select id from github_installation_repositories)
),
gitlab_pull_requests_map as not materialized (
  select
    gprm.repository_id as repository_id,
    gprm.pull_number as pull_number,
    gprm.core_id as core_id
  from terrateam.gitlab_pull_requests_map as gprm
  where gprm.repository_id in (select id from gitlab_installation_repositories)
),
-- The two *_latest_unlocks relations are remote VIEWS, not base tables: a
-- max(unlocked_at) group by (repository, pull_number) over the unlock
-- history. So each is unique on (repository, pull_number) -- a grain the
-- scoping test's plain-table mirror cannot enforce, and one a consumer
-- left-joining to discard work manifests older than the last unlock relies on.
github_pull_request_latest_unlocks as not materialized (
  select
    gpu.repository as repository,
    gpu.pull_number as pull_number,
    gpu.unlocked_at as unlocked_at
  from terrateam.github_pull_request_latest_unlocks as gpu
  where gpu.repository in (select id from github_installation_repositories)
),
gitlab_pull_request_latest_unlocks as not materialized (
  select
    gpu.repository as repository,
    gpu.pull_number as pull_number,
    gpu.unlocked_at as unlocked_at
  from terrateam.gitlab_pull_request_latest_unlocks as gpu
  where gpu.repository in (select id from gitlab_installation_repositories)
),
github_change_dirspaces as not materialized (
  select
    gcd.base_sha as base_sha,
    gcd.path as path,
    gcd.repository as repository,
    gcd.sha as sha,
    gcd.workspace as workspace,
    gcd.lock_policy as lock_policy,
    gcd.branch_target as branch_target
  from terrateam.github_change_dirspaces as gcd
  where gcd.repository in (select id from github_installation_repositories)
),
gitlab_change_dirspaces as not materialized (
  select
    gcd.base_sha as base_sha,
    gcd.path as path,
    gcd.repository as repository,
    gcd.sha as sha,
    gcd.workspace as workspace,
    gcd.lock_policy as lock_policy,
    gcd.branch_target as branch_target
  from terrateam.gitlab_change_dirspaces as gcd
  where gcd.repository in (select id from gitlab_installation_repositories)
),
github_work_manifests as not materialized (
  select
    gwm.base_sha as base_sha,
    gwm.completed_at as completed_at,
    gwm.created_at as created_at,
    gwm.id as id,
    gwm.pull_number as pull_number,
    gwm.repository as repository,
    gwm.run_id as run_id,
    gwm.run_type as run_type,
    gwm.sha as sha,
    gwm.state as state,
    gwm.tag_query as tag_query,
    gwm.username as username,
    gwm.dirspaces as dirspaces,
    gwm.run_kind as run_kind,
    gwm.environment as environment,
    gwm.runs_on as runs_on,
    gwm.installation_id as installation_id,
    gwm.repo_owner as repo_owner,
    gwm.repo_name as repo_name,
    gwm.branch as branch
  from terrateam.github_work_manifests as gwm
  where gwm.installation_id = any(array(select installation_id from github_installation_ids))
),
gitlab_work_manifests as not materialized (
  select
    gwm.base_sha as base_sha,
    gwm.completed_at as completed_at,
    gwm.created_at as created_at,
    gwm.id as id,
    gwm.pull_number as pull_number,
    gwm.repository as repository,
    gwm.run_id as run_id,
    gwm.run_type as run_type,
    gwm.sha as sha,
    gwm.state as state,
    gwm.tag_query as tag_query,
    gwm.username as username,
    gwm.dirspaces as dirspaces,
    gwm.run_kind as run_kind,
    gwm.environment as environment,
    gwm.runs_on as runs_on,
    gwm.installation_id as installation_id,
    gwm.repo_owner as repo_owner,
    gwm.repo_name as repo_name,
    gwm.branch as branch
  from terrateam.gitlab_work_manifests as gwm
  where gwm.installation_id = any(array(select installation_id from gitlab_installation_ids))
),
work_manifest_dirspaceflows as not materialized (
  select
    wmd.path as path,
    wmd.work_manifest as work_manifest,
    wmd.workflow_idx as workflow_idx,
    wmd.workspace as workspace
  from terrateam.work_manifest_dirspaceflows as wmd
  where wmd.work_manifest in (
    select wm.id from terrateam.work_manifests as wm
    where wm.repo = any(array(select core_id from github_repositories_map union all select core_id from gitlab_repositories_map))
  )
),
work_manifest_results as not materialized (
  select
    wmr.path as path,
    wmr.success as success,
    wmr.work_manifest as work_manifest,
    wmr.workspace as workspace
  from terrateam.work_manifest_results as wmr
  where wmr.work_manifest in (
    select wm.id from terrateam.work_manifests as wm
    where wm.repo = any(array(select core_id from github_repositories_map union all select core_id from gitlab_repositories_map))
  )
),
drift_work_manifests as not materialized (
  select
    dwm.branch as branch,
    dwm.work_manifest as work_manifest
  from terrateam.drift_work_manifests as dwm
  where dwm.work_manifest in (
    select wm.id from terrateam.work_manifests as wm
    where wm.repo = any(array(select core_id from github_repositories_map union all select core_id from gitlab_repositories_map))
  )
),
workflow_step_outputs as not materialized (
  select
    wso.created_at as created_at,
    wso.idx as idx,
    wso.ignore_errors as ignore_errors,
    wso.payload as payload,
    wso.scope as scope,
    wso.step as step,
    wso.success as success,
    wso.work_manifest as work_manifest
  from terrateam.workflow_step_outputs as wso
  where wso.work_manifest in (
    select wm.id from terrateam.work_manifests as wm
    where wm.repo = any(array(select core_id from github_repositories_map union all select core_id from gitlab_repositories_map))
  )
),
plans as not materialized (
  select
    p.path as path,
    p.work_manifest as work_manifest,
    p.workspace as workspace,
    p.has_changes as has_changes,
    p.created_at as created_at
  from terrateam.plans as p
  where p.work_manifest in (
    select wm.id from terrateam.work_manifests as wm
    where wm.repo = any(array(select core_id from github_repositories_map union all select core_id from gitlab_repositories_map))
  )
),
dirspace_pull_request_locks as not materialized (
  select
    dprl.branch_target as branch_target,
    dprl.path as path,
    dprl.pull_request as pull_request,
    dprl.workspace as workspace
  from terrateam.dirspace_pull_request_locks as dprl
  where dprl.pull_request in (select core_id from github_pull_requests_map)
  union all
  select
    dprl.branch_target as branch_target,
    dprl.path as path,
    dprl.pull_request as pull_request,
    dprl.workspace as workspace
  from terrateam.dirspace_pull_request_locks as dprl
  where dprl.pull_request in (select core_id from gitlab_pull_requests_map)
),
gates as not materialized (
  select
    g.created_at as created_at,
    g.dir as dir,
    g.gate as gate,
    g.sha as sha,
    g.workspace as workspace,
    g.pull_request as pull_request,
    g.name as name,
    g.token as token
  from terrateam.gates as g
  where g.pull_request in (select core_id from github_pull_requests_map)
  union all
  select
    g.created_at as created_at,
    g.dir as dir,
    g.gate as gate,
    g.sha as sha,
    g.workspace as workspace,
    g.pull_request as pull_request,
    g.name as name,
    g.token as token
  from terrateam.gates as g
  where g.pull_request in (select core_id from gitlab_pull_requests_map)
),
gate_approvals as not materialized (
  select
    ga.approver as approver,
    ga.created_at as created_at,
    ga.sha as sha,
    ga.pull_request as pull_request,
    ga.token as token
  from terrateam.gate_approvals as ga
  where ga.pull_request in (select core_id from github_pull_requests_map)
  union all
  select
    ga.approver as approver,
    ga.created_at as created_at,
    ga.sha as sha,
    ga.pull_request as pull_request,
    ga.token as token
  from terrateam.gate_approvals as ga
  where ga.pull_request in (select core_id from gitlab_pull_requests_map)
),
-- [stacks] is the config-derived hierarchy and apply order ONLY. The engine
-- writes every [state] field in it as the constant 'no_changes' (see
-- Terrat_vcs_stacks.store: "we store as no_changes in the database because
-- when we query it is when we will fill in the details") and computes live
-- state at read time from the work manifests. A consumer that reads
-- stacks -> 'stacks' -> n -> 'state' gets that placeholder, not a state.
pull_request_stacks as not materialized (
  select
    prs.pull_request as pull_request,
    prs.stacks as stacks
  from terrateam.pull_request_stacks as prs
  where prs.pull_request in (select core_id from github_pull_requests_map)
  union all
  select
    prs.pull_request as pull_request,
    prs.stacks as stacks
  from terrateam.pull_request_stacks as prs
  where prs.pull_request in (select core_id from gitlab_pull_requests_map)
),
repo_configs as not materialized (
  select
    rc.sha as sha,
    rc.created_at as created_at,
    rc.data as data,
    rc.installation as installation,
    rc.kind as kind,
    rc.repo as repo,
    rc.branch as branch
  from terrateam.repo_configs as rc
  -- Through the provider-qualified map CTEs, NOT tenant_installation_core_ids
  -- alone: the mapping's primary key is (provider, installation_core_id), so
  -- the same core id claimed under two providers would land in two tenants,
  -- and a provider-blind anchor would leak the other tenant's rows.
  where rc.installation in (select core_id from github_installations_map)
  union all
  select
    rc.sha as sha,
    rc.created_at as created_at,
    rc.data as data,
    rc.installation as installation,
    rc.kind as kind,
    rc.repo as repo,
    rc.branch as branch
  from terrateam.repo_configs as rc
  where rc.installation in (select core_id from gitlab_installations_map)
),
drift_schedules as not materialized (
  select
    ds.reconcile as reconcile,
    ds.schedule as schedule,
    ds.updated_at as updated_at,
    ds.tag_query as tag_query,
    ds.name as name,
    ds.repo as repo,
    ds.branch as branch,
    ds.last_tried_at as last_tried_at
  from terrateam.drift_schedules as ds
  where ds.repo in (select core_id from github_repositories_map)
  union all
  select
    ds.reconcile as reconcile,
    ds.schedule as schedule,
    ds.updated_at as updated_at,
    ds.tag_query as tag_query,
    ds.name as name,
    ds.repo as repo,
    ds.branch as branch,
    ds.last_tried_at as last_tried_at
  from terrateam.drift_schedules as ds
  where ds.repo in (select core_id from gitlab_repositories_map)
)

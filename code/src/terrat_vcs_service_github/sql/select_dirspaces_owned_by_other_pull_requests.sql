-- The dirspaces of our pull request that another pull request blocks, with that pull request.
--
-- A lock blocks, as it always has, unless the dirspace applies in parallel: it is one of
-- $parallel_dirs/$parallel_workspaces (the edition allows it and its workflow runs the Stategraph
-- engine, under the configuration of this evaluation) and the owner is not merged.  Such a lock
-- gives way to the rule below.
--
-- Stategraph refuses a commit that overlaps a transaction committed since its plan, where "since" is
-- the moment the plan's transaction opened (select_tx_conflicts.sql).  It cannot see the other
-- danger: a plan whose transaction opened AFTER another pull request's apply committed finds that
-- apply in the state and, our branch lacking its code, reverts it.  So on a parallel dirspace, a
-- running or successful eligible apply of another unmerged pull request, since its latest unlock,
-- blocks us unless our latest completed plan of the dirspace (the plan the apply uses, see
-- select_recent_plan.sql) opened its transaction before that apply committed: Stategraph then
-- settles any overlap.  A failed apply blocks no one.
--
-- The runner reports both moments in the 'tx' key of the stategraph/plan and stategraph/apply step
-- payloads, the {"id", "state", "created_at", "completed_at"} of the Stategraph transaction.
-- Without them (an older runner, a plan with no changes) the work manifests stand in: a plan
-- completes at or after its transaction opened, and an apply is dispatched before it commits, so
-- the answer stays safe.
with
our_pr as (
    select repository, pull_number, base_branch
    from github_pull_requests
    where repository = $repository and pull_number = $pull_number
),
dirspaces as (
    select dir, workspace from unnest($dirs, $workspaces) as v(dir, workspace)
),
parallel_dirspaces as (
    select dir, workspace from unnest($parallel_dirs, $parallel_workspaces) as v(dir, workspace)
),
locks as (
    select
        dsprl.path as path,
        dsprl.workspace as workspace,
        dsprl.pull_number as pull_number
    from github_dirspace_pull_request_locks as dsprl
    inner join dirspaces
        on dirspaces.dir = dsprl.path and dirspaces.workspace = dsprl.workspace
    inner join our_pr
        on our_pr.repository = dsprl.repository
    inner join github_pull_requests as gpr
        on gpr.repository = dsprl.repository and gpr.pull_number = dsprl.pull_number
    where dsprl.pull_number <> our_pr.pull_number
          and (dsprl.branch_target = 'all'
               or (dsprl.branch_target = 'dest_branch' and our_pr.base_branch = gpr.base_branch))
          and not (gpr.merged_at is null
                   and exists (select 1
                               from parallel_dirspaces as pds
                               where pds.dir = dsprl.path and pds.workspace = dsprl.workspace))
),
our_plans as (
    select distinct on (pds.dir, pds.workspace)
        pds.dir as dir,
        pds.workspace as workspace,
        coalesce((plan_step.payload->'tx'->>'created_at')::timestamptz, gwm.completed_at) as planned_at
    from parallel_dirspaces as pds
    inner join work_manifest_results as wmr
        on wmr.path = pds.dir and wmr.workspace = pds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmr.work_manifest
    inner join our_pr
        on our_pr.repository = gwm.repository and our_pr.pull_number = gwm.pull_number
    left join workflow_step_outputs as plan_step
        on plan_step.work_manifest = gwm.id
           and plan_step.step = 'stategraph/plan'
           and plan_step.scope->>'type' = 'dirspace'
           and plan_step.scope->>'dir' = pds.dir
           and plan_step.scope->>'workspace' = pds.workspace
    where gwm.run_type in ('autoplan', 'plan') and gwm.completed_at is not null
    order by pds.dir, pds.workspace, gwm.created_at desc
),
applies as (
    select
        pds.dir as path,
        pds.workspace as workspace,
        gwm.pull_number as pull_number
    from parallel_dirspaces as pds
    inner join work_manifest_dirspaceflows as wmds
        on wmds.path = pds.dir and wmds.workspace = pds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmds.work_manifest
    inner join work_manifests as core
        on core.id = gwm.id
    inner join our_pr
        on our_pr.repository = gwm.repository
    inner join github_pull_requests as gpr
        on gpr.repository = gwm.repository and gpr.pull_number = gwm.pull_number
    left join github_change_dirspaces as gcds
        on gcds.repository = gwm.repository
           and gcds.base_sha = gwm.base_sha
           and gcds.sha = gwm.sha
           and gcds.path = pds.dir
           and gcds.workspace = pds.workspace
    left join github_pull_request_latest_unlocks as unlocks
        on unlocks.repository = gwm.repository and unlocks.pull_number = gwm.pull_number
    left join work_manifest_results as wmr
        on wmr.work_manifest = gwm.id and wmr.path = pds.dir and wmr.workspace = pds.workspace
    left join workflow_step_outputs as apply_step
        on apply_step.work_manifest = gwm.id
           and apply_step.step = 'stategraph/apply'
           and apply_step.scope->>'type' = 'dirspace'
           and apply_step.scope->>'dir' = pds.dir
           and apply_step.scope->>'workspace' = pds.workspace
    left join our_plans
        on our_plans.dir = pds.dir and our_plans.workspace = pds.workspace
    where gwm.pull_number <> our_pr.pull_number
          and gwm.run_type in ('autoapply', 'apply', 'unsafe-apply')
          and gpr.merged_at is null
          and (coalesce(gcds.branch_target, 'all') = 'all'
               or our_pr.base_branch = gpr.base_branch)
          and (unlocks.unlocked_at is null or unlocks.unlocked_at < gwm.created_at)
          and (gwm.state = 'running' or (gwm.state = 'completed' and wmr.success))
-- A running apply has no result yet, so its dispatch time bounds from below when
-- it could have committed.  A work manifest dispatched before the column
-- existed falls back to its creation, which is earlier still.
          and (our_plans.planned_at is null
               or our_plans.planned_at >= coalesce((apply_step.payload->'tx'->>'completed_at')::timestamptz,
                                                   core.dispatched_at,
                                                   gwm.created_at))
)
select
    blockers.path as path,
    blockers.workspace as workspace,
    gpr.base_branch as base_branch,
    gpr.branch as branch_name,
    gpr.base_sha as bash_hash,
    gpr.sha as hash,
    gpr.merged_sha as merged_hash,
    gpr.merged_at as merged_at,
    gpr.pull_number as id,
    gpr.state as state,
    gpr.title as title,
    gpr.username as username
from (select * from locks union select * from applies) as blockers
inner join our_pr
    on true
inner join github_pull_requests as gpr
    on gpr.repository = our_pr.repository and gpr.pull_number = blockers.pull_number

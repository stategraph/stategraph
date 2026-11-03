-- For each dirspace of our pull request that applies in parallel, the Stategraph transaction of our
-- latest completed plan beside the transaction of each apply of another pull request on the dirspace
-- that Stategraph may refuse our plan for: an apply queued or running, or one that completed and
-- succeeded, of a pull request not merged, since that pull request's latest unlock, and on the same
-- base branch where the dirspace locks per base branch.  A dirspace with no such apply gives one row
-- with the apply columns null, so that the plan's transaction is known for every dirspace.
--
-- The runner reports a transaction in the 'tx' key of the stategraph/plan and stategraph/apply step
-- payloads.  The transaction of a completed apply is the one its apply step reported.  A queued or
-- running apply has no result yet, so its transaction is that of its pull request's latest completed
-- plan of the dirspace, the plan the apply commits (select_recent_plan.sql).  Our own transaction is
-- that of our latest completed plan of the dirspace, the plan our apply would commit.
--
-- Whether a transaction stands against ours is Stategraph's answer, asked with the two ids and the
-- installation the repository belongs to.  A plan without a reported transaction gives no row, and an
-- apply without one is left out: Stategraph then decides at commit, as it always has.
with
our_pr as (
    select repository, pull_number, base_branch
    from github_pull_requests
    where repository = $repository and pull_number = $pull_number
),
dirspaces as (
    select dir, workspace from unnest($dirs, $workspaces) as v(dir, workspace)
),
installation as (
    select gim.core_id
    from github_installation_repositories as gir
    inner join github_installations_map as gim
        on gim.installation_id = gir.installation_id
    where gir.id = $repository
),
-- The latest completed plan of each pull request on each dirspace, with the transaction it
-- reported, null when it reported none.
plans as (
    select distinct on (gwm.pull_number, ds.dir, ds.workspace)
        gwm.pull_number,
        ds.dir,
        ds.workspace,
        plan_step.payload->'tx'->>'id' as tx
    from dirspaces as ds
    inner join work_manifest_results as wmr
        on wmr.path = ds.dir and wmr.workspace = ds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmr.work_manifest
    left join workflow_step_outputs as plan_step
        on plan_step.work_manifest = gwm.id
           and plan_step.step = 'stategraph/plan'
           and plan_step.scope->>'type' = 'dirspace'
           and plan_step.scope->>'dir' = ds.dir
           and plan_step.scope->>'workspace' = ds.workspace
    where gwm.repository = $repository
          and gwm.pull_number is not null
          and gwm.run_type in ('autoplan', 'plan')
          and gwm.completed_at is not null
    order by gwm.pull_number, ds.dir, ds.workspace, gwm.created_at desc
),
applies as (
    select
        ds.dir,
        ds.workspace,
        gwm.pull_number,
        gwm.state = 'completed' as applied,
        coalesce(apply_step.payload->'tx'->>'id', plans.tx) as tx
    from dirspaces as ds
    inner join work_manifest_dirspaceflows as wmds
        on wmds.path = ds.dir and wmds.workspace = ds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmds.work_manifest
    inner join our_pr
        on our_pr.repository = gwm.repository
    inner join github_pull_requests as gpr
        on gpr.repository = gwm.repository and gpr.pull_number = gwm.pull_number
    left join github_change_dirspaces as gcds
        on gcds.repository = gwm.repository
           and gcds.base_sha = gwm.base_sha
           and gcds.sha = gwm.sha
           and gcds.path = ds.dir
           and gcds.workspace = ds.workspace
    left join github_pull_request_latest_unlocks as unlocks
        on unlocks.repository = gwm.repository and unlocks.pull_number = gwm.pull_number
    left join work_manifest_results as wmr
        on wmr.work_manifest = gwm.id and wmr.path = ds.dir and wmr.workspace = ds.workspace
    left join workflow_step_outputs as apply_step
        on apply_step.work_manifest = gwm.id
           and apply_step.step = 'stategraph/apply'
           and apply_step.scope->>'type' = 'dirspace'
           and apply_step.scope->>'dir' = ds.dir
           and apply_step.scope->>'workspace' = ds.workspace
    left join plans
        on plans.pull_number = gwm.pull_number
           and plans.dir = ds.dir
           and plans.workspace = ds.workspace
    where gwm.pull_number <> our_pr.pull_number
          and gwm.run_type in ('autoapply', 'apply', 'unsafe-apply')
          and gpr.merged_at is null
          and (coalesce(gcds.branch_target, 'all') = 'all'
               or our_pr.base_branch = gpr.base_branch)
          and (unlocks.unlocked_at is null or unlocks.unlocked_at < gwm.created_at)
          and (gwm.state in ('queued', 'running') or (gwm.state = 'completed' and wmr.success))
)
select
    ds.dir,
    ds.workspace,
    installation.core_id,
    our_plan.tx,
    applies.pull_number,
    applies.tx,
    applies.applied
from dirspaces as ds
inner join installation
    on true
inner join plans as our_plan
    on our_plan.pull_number = $pull_number
       and our_plan.dir = ds.dir
       and our_plan.workspace = ds.workspace
left join applies
    on applies.dir = ds.dir and applies.workspace = ds.workspace and applies.tx is not null
where our_plan.tx is not null
order by ds.dir, ds.workspace, applies.pull_number

-- For each dirspace of our pull request that applies in parallel, the Stategraph transaction of our
-- latest completed plan beside the transaction of each apply of another pull request on the dirspace
-- that Stategraph may refuse our plan for: an apply queued or running, or one that completed and
-- succeeded, of a pull request not merged, since that pull request's latest unlock, and on the same
-- base branch where the dirspace locks per base branch.  A dirspace with no such apply gives one row
-- with the apply columns null, so that the plan's transaction is known for every dirspace.
--
-- A transaction is read out of the stored plan that opened it, by the caller
-- (Terrat_vcs_provider2.Stategraph_plan): the statement answers the plans, base64 as
-- select_recent_plan.sql serves them.  The plan of an apply is the latest completed plan of its pull
-- request on the dirspace at the time the apply was made, the plan the apply commits
-- (select_recent_plan.sql); a Stategraph plan stays stored after its apply for this reason.  Our own
-- plan is our latest completed plan of the dirspace, the plan our apply would commit.
--
-- Whether a transaction stands against ours is Stategraph's answer, asked with the two ids and the
-- installation the repository belongs to.  A dirspace whose plan is gone gives no row, and an apply
-- whose plan is gone is left out: Stategraph then decides at commit, as it always has.
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
-- The completed plans of the repository's pull requests on the dirspaces, with their stored file.
plans as (
    select
        gwm.pull_number,
        ds.dir,
        ds.workspace,
        gwm.created_at,
        encode(p.data, 'base64') as plan
    from dirspaces as ds
    inner join work_manifest_results as wmr
        on wmr.path = ds.dir and wmr.workspace = ds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmr.work_manifest
    inner join plans as p
        on p.work_manifest = gwm.id and p.path = ds.dir and p.workspace = ds.workspace
    where gwm.repository = $repository
          and gwm.pull_number is not null
          and gwm.run_type in ('autoplan', 'plan')
          and gwm.completed_at is not null
          and p.data is not null
),
our_plans as (
    select distinct on (dir, workspace)
        dir,
        workspace,
        plan
    from plans
    where pull_number = $pull_number
    order by dir, workspace, created_at desc
),
applies as (
    select
        ds.dir,
        ds.workspace,
        gwm.pull_number,
        gwm.id as work_manifest,
        gwm.state = 'completed' as applied,
        applied_plan.plan
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
    left join lateral (
        select plans.plan
        from plans
        where plans.pull_number = gwm.pull_number
              and plans.dir = ds.dir
              and plans.workspace = ds.workspace
              and plans.created_at <= gwm.created_at
        order by plans.created_at desc
        limit 1
    ) as applied_plan on true
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
    our_plans.plan,
    applies.pull_number,
    applies.work_manifest,
    applies.plan,
    applies.applied
from dirspaces as ds
inner join installation
    on true
inner join our_plans
    on our_plans.dir = ds.dir and our_plans.workspace = ds.workspace
left join applies
    on applies.dir = ds.dir and applies.workspace = ds.workspace and applies.plan is not null
order by ds.dir, ds.workspace, applies.pull_number

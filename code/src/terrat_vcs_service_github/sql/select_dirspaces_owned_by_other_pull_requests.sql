-- The dirspaces of our pull request that another pull request blocks, with that pull request.
--
-- A lock blocks, as it always has, unless the dirspace applies in parallel: it is one of
-- $parallel_dirs/$parallel_workspaces (the edition allows it, its workflow runs the Stategraph
-- engine, under the configuration of this evaluation, and the orchestration reaches Stategraph)
-- and the owner is not merged.  Stategraph then settles the dirspace between the pull requests, by
-- resource: it refuses a commit that overlaps a transaction committed since the plan opened, and
-- one that overlaps a held commit, the commit of an apply whose pull request is not merged
-- (#3179), whenever the plan opened.  The orchestration asks it before it starts an apply
-- (select_parallel_apply_transactions.sql).  A merged owner still locks: a plan made before the
-- merge lags the base branch.
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
-- Distinct: a dirspace given twice is answered once.
locks as (
    select distinct
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
)
select
    locks.path as path,
    locks.workspace as workspace,
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
from locks
inner join our_pr
    on true
inner join github_pull_requests as gpr
    on gpr.repository = our_pr.repository and gpr.pull_number = locks.pull_number

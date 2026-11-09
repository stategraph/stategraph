with
dirspaces as (
    select path, workspace from unnest($dirs, $workspaces) as v(path, workspace)
),
parallel_dirspaces as (
    select path, workspace from unnest($parallel_dirs, $parallel_workspaces) as v(path, workspace)
),
-- The moments the orchestration read from Stategraph, where it reaches it: when the transaction
-- of our latest plan of a dirspace opened, and when the transaction an apply commits completed,
-- by the apply's work manifest.  The runs bound a moment that is absent: a plan completes at or
-- after its transaction opened, and an apply is dispatched before it commits.
planned as (
    select path, workspace, at
    from unnest($planned_dirs, $planned_workspaces, $planned_at) as v(path, workspace, at)
),
committed as (
    select work_manifest, at
    from unnest($committed_work_manifests, $committed_at) as v(work_manifest, at)
),
-- The requested dirspaces whose plan work manifest of this pull request is
-- still queued or running.  The completed-run ranking below reads
-- work_manifest_results only, and a plan that has not finished has no row
-- there, so this is the join that reaches one.  Scoped to this pull request so
-- that a plan of another pull request on the same dirspace keeps its own
-- reason.
in_progress_plans as (
    select distinct ds.path, ds.workspace
    from dirspaces as ds
    inner join work_manifest_dirspaceflows as wmdf
        on wmdf.path = ds.path and wmdf.workspace = ds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmdf.work_manifest
-- An unlocked plan is one that a push superseded: it is still queued or running, but its answer
-- is for a commit the pull request has left, thus it does not stand for the dirspace.  This is
-- the same predicate the plan selection uses, so the apply gate and the plan selection agree on
-- what counts as in progress.
    left join github_pull_request_latest_unlocks as unlocks
        on unlocks.repository = gwm.repository and unlocks.pull_number = gwm.pull_number
    where gwm.repository = $repository
          and gwm.pull_number = $pull_number
          and gwm.run_type in ('autoplan', 'plan')
          and gwm.state in ('queued', 'running')
          and (unlocks.unlocked_at is null or unlocks.unlocked_at < gwm.created_at)
),
-- The requested dirspaces that this pull request has a completed plan run for.
-- The ranking below is over every pull request, so a dirspace that another pull
-- request ran and this one never did is reported as never planned here, not as
-- superseded: there is no plan of this pull request to supersede.  The scoping
-- is the one [our_plans] uses, over every requested dirspace rather than the
-- parallel ones.  A failed plan is still a plan of this pull request -- the
-- predicate reads completed_at and not success -- so a dirspace whose plan
-- failed, and whose directory another pull request applied afterwards, is
-- reported as superseded, not as last run failed.  A parallel dirspace answers
-- differently on purpose: the moment guard can hold the other pull request's
-- apply out of the ranking, the newest run left is this pull request's failed
-- plan, and the reason is last run failed.
our_runs as (
    select distinct ds.path, ds.workspace
    from dirspaces as ds
    inner join work_manifest_results as wmr
        on wmr.path = ds.path and wmr.workspace = ds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmr.work_manifest
    where gwm.repository = $repository
          and gwm.pull_number = $pull_number
          and gwm.run_type in ('autoplan', 'plan')
          and gwm.completed_at is not null
),
-- When the Stategraph transaction of our latest completed plan of a parallel
-- dirspace opened or, without the moment, when that plan completed: the
-- transaction opened during the run, so the run bounds the moment from above.
our_plans as (
    select distinct on (pds.path, pds.workspace)
        pds.path,
        pds.workspace,
        coalesce(planned.at, gwm.completed_at) as planned_at
    from parallel_dirspaces as pds
    inner join work_manifest_results as wmr
        on wmr.path = pds.path and wmr.workspace = pds.workspace
    inner join github_work_manifests as gwm
        on gwm.id = wmr.work_manifest
    left join planned
        on planned.path = pds.path and planned.workspace = pds.workspace
    where gwm.repository = $repository
          and gwm.pull_number = $pull_number
          and gwm.run_type in ('autoplan', 'plan')
          and gwm.completed_at is not null
    order by pds.path, pds.workspace, gwm.created_at desc
),
latest_pull_request_merged_sha as (
    select
        merged_sha
    from github_pull_requests as gpr
    where merged_at is not null and repository = $repository
    order by merged_at desc
    limit 1
),
latest_dirspace_work_manifests as (
    select distinct on (gwm.repository, wmr.path, wmr.workspace)
        gwm.id,
        gwm.pull_number,
        wmr.path,
        wmr.workspace,
        wmr.success,
-- Whether this row is a run of this pull request at the refs the pull request
-- has now.  A run of this pull request at older refs is still a run of this
-- pull request, so it takes part in the ranking below and only this flag says
-- that its refs moved.  Holding such a row out of the ranking instead, which is
-- what this query did before, let any other pull request that ever touched the
-- dirspace outrank it, and a moved ref was then reported as that pull request
-- superseding the plan.
        (gpr.pull_number is not null
         and gpr.pull_number = $pull_number
         and gwm.base_sha = $base_ref
         and gwm.base_sha = gpr.base_sha
         and (
-- If the PR is not merged then we expect the branch ref to match the ref in the PR
              (gpr.merged_at is null
               and gpr.sha = $branch_ref
               and gwm.sha = gpr.sha)
-- If this pr is merged, then we expect the branch ref to match the latest pull request merged sha.
              or
              (gpr.merged_at is not null
               and (gwm.sha = lprms.merged_sha
                    or (gwm.sha = gpr.sha and gpr.merged_sha = lprms.merged_sha)))
         )) as refs_match
    from dirspaces as ds
    inner join work_manifest_results as wmr
        on wmr.path = ds.path and wmr.workspace = ds.workspace
    inner join github_work_manifests as gwm
        on wmr.work_manifest = gwm.id
-- The view does not carry the dispatch time, thus it comes from work_manifests.
    inner join work_manifests as core
        on core.id = gwm.id
    left join committed
        on committed.work_manifest = gwm.id
    left join github_pull_requests as gpr
        on gpr.repository = gwm.repository and gpr.pull_number = gwm.pull_number
    left join latest_pull_request_merged_sha as lprms
        on true
    where gwm.repository = $repository
-- Consider work manifests that belong to this pull request, are some kind of
-- apply, or belong to a pull request that has been merged.
          and (gwm.pull_number is not distinct from $pull_number
               or gwm.run_type in ('autoapply', 'apply')
               or gpr.merged_at is not null)
-- On a parallel dirspace, another pull request's eligible apply that committed
-- its Stategraph transaction after our latest plan's transaction opened does
-- not invalidate that plan: Stategraph checks the two for an overlap when the
-- plan is applied.  The moments come from Stategraph, read by the orchestration
-- where it reaches it; without them the runs stand in: our transaction opened
-- before our plan's run completed, and the apply committed after its run was
-- dispatched (or, for a run dispatched before the column existed, after it was
-- created).  An apply that may have committed before our transaction opened
-- invalidates the plan, as it always has.  A merged pull request invalidates it
-- regardless: the plan then lags behind the base branch.
          and not (gwm.pull_number is distinct from $pull_number
                   and gpr.merged_at is null
                   and gwm.run_type in ('autoapply', 'apply')
                   and exists (select 1
                               from our_plans
                               where our_plans.path = wmr.path
                                     and our_plans.workspace = wmr.workspace
                                     and coalesce(committed.at, core.dispatched_at, gwm.created_at)
                                         > our_plans.planned_at))
-- A work manifest affects the base branch when it runs or, for a merged pull
-- request, when it is merged.  Rank by whichever happened later so that an
-- overlapping dirspace applied or merged by another pull request after this
-- plan was created supersedes it.
    order by gwm.repository, wmr.path, wmr.workspace,
             greatest(gwm.created_at, gpr.merged_at) desc, gwm.created_at desc
)
select
    ds.path,
    ds.workspace,
-- The arms below are the arms of the where clause, in the same order, so the
-- reason reported is the one that actually excluded the row.  A plan work
-- manifest of this pull request that is still queued or running outranks every
-- completed-run reason: the answer to the user is to wait, not to plan again.
-- The two arms of the other-pull-request test split it: a plan of this pull
-- request is superseded only when this pull request has a run of the dirspace
-- for the other run to outrank, and a dirspace this pull request never ran is
-- never planned.  The last arm is a successful run of this pull request whose
-- refs moved: a plan exists, but not for the commit the pull request points at
-- now.  That is the only arm the intra-PR hash rule can clear, and the caller
-- is what applies it.  The two split arms share the one
-- [pull_number is distinct from $pull_number] arm of the where clause, because
-- both ask the same question of the row, whether the newest run is of another
-- pull request, and differ only in whether this pull request ran the dirspace.
    case
        when ipp.path is not null then 'plan_in_progress'
        when ldswm.id is null then 'never_planned'
        when ldswm.pull_number is distinct from $pull_number
             and our_runs.path is not null then 'invalidated'
        when ldswm.pull_number is distinct from $pull_number then 'never_planned'
        when not ldswm.success then 'last_run_failed'
        else 'never_planned'
    end,
-- The pull request that superseded the plan, and nothing for the other
-- reasons: the caller names it only in the [invalidated] text.  The
-- [ipp.path is null] guard keeps the number out of a row the reason case reads
-- as plan_in_progress: the where clause is a disjunction, so such a row can
-- satisfy this arm too.
    case
        when ipp.path is null
             and ldswm.pull_number is distinct from $pull_number
             and our_runs.path is not null then ldswm.pull_number
    end
from dirspaces as ds
left join latest_dirspace_work_manifests as ldswm
    on ldswm.path = ds.path
       and ldswm.workspace = ds.workspace
left join in_progress_plans as ipp
    on ipp.path = ds.path
       and ipp.workspace = ds.workspace
left join our_runs
    on our_runs.path = ds.path
       and our_runs.workspace = ds.workspace
left join plans
    on plans.work_manifest = ldswm.id
       and plans.path = ds.path
       and plans.workspace = ds.workspace
where ipp.path is not null
      or ldswm.id is null
      or ldswm.pull_number is distinct from $pull_number
      or not ldswm.success
      or not ldswm.refs_match

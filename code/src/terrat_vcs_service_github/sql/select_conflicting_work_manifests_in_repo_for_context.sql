with
context as (
  select
    jc.id,
    grm.repository_id as repo,
    gprm.pull_number as pull_number,
    coalesce(gpr.branch, jc.params->>'branch') as branch,
    coalesce(gpr.base_branch, jc.params->>'dest_branch') as dest_branch,
    bh.hash as branch_hash,
    dbh.hash as dest_branch_hash,
    gpr.merged_sha
  from job_contexts as jc
  inner join github_repositories_map as grm
    on grm.core_id = jc.repo
  left join github_pull_requests_map as gprm
    on gprm.core_id = (jc.params->>'pull_request')::uuid
  left join github_pull_requests as gpr
    on gpr.repository = gprm.repository_id and gpr.pull_number = gprm.pull_number
  inner join branch_commit_hashes as bh
    on bh.repo = jc.repo and bh.branch = coalesce(gpr.branch, jc.params->>'branch')
  inner join branch_commit_hashes as dbh
    on dbh.repo = jc.repo and dbh.branch = coalesce(gpr.base_branch, jc.params->>'dest_branch', jc.params->>'branch')
  where jc.id = $context_id
),
dirspaces as (
    select dir, workspace from unnest($dirs, $workspaces) as v(dir, workspace)
),
parallel_dirspaces as (
    select dir, workspace from unnest($parallel_dirs, $parallel_workspaces) as v(dir, workspace)
),
wm as (
   select
     gwm.*
   from github_work_manifests as gwm
   inner join context as c
     on c.repo = gwm.repository
   left join github_pull_request_latest_unlocks as latest_unlocks
        on latest_unlocks.repository = gwm.repository and latest_unlocks.pull_number = gwm.pull_number
   left join github_drift_latest_unlocks as latest_drift_unlocks
        on latest_drift_unlocks.repository = gwm.repository
   where gwm.state in ('queued', 'running')
         and (latest_unlocks.unlocked_at is null or latest_unlocks.unlocked_at < gwm.created_at)
         and (latest_drift_unlocks.unlocked_at is null or latest_drift_unlocks.unlocked_at < gwm.created_at)
),
work_manifests_for_dirspace as (
    select
        gwm.id,
-- Consider a work manifest as maybe stale if it was dispatched but has not
-- called home within the start timeout, or if it has been in flight for over an
-- hour.  A work manifest that is still queued is not stale, it may legitimately
-- be waiting on other work against its dirspaces.  A null dispatch time is a
-- work manifest of before the column existed, and it is not stale (RFD 2826).
        ((gwm.state = 'running'
          and gwm.run_id is null
          and (now() - core.dispatched_at > make_interval(secs => $start_timeout)))
         or (now() - gwm.created_at > interval '1 hour')) as maybe_stale,
        bool_or(
          not coalesce(
            parallel_dirspaces.dir is not null
            and gwm.pull_number is distinct from c.pull_number,
            false
          )
        ) as blocks_apply
    from dirspaces
    inner join work_manifest_dirspaceflows as gwmdsfs
        on dirspaces.dir = gwmdsfs.path and dirspaces.workspace = gwmdsfs.workspace
    inner join wm as gwm
        on gwmdsfs.work_manifest = gwm.id
-- The views do not carry the dispatch time, thus it comes from work_manifests.
    inner join work_manifests as core
        on core.id = gwm.id
    inner join context as c
      on c.repo = gwm.repository
    left join parallel_dirspaces
      on parallel_dirspaces.dir = gwmdsfs.path
         and parallel_dirspaces.workspace = gwmdsfs.workspace
    group by gwm.id, gwm.state, gwm.run_id, gwm.created_at, core.dispatched_at, gwm.pull_number, c.pull_number
)
select
    gwm.id,
    work_manifests_for_dirspace.maybe_stale
from wm as gwm
inner join context as c
  on c.repo = gwm.repository
inner join work_manifests_for_dirspace
    on work_manifests_for_dirspace.id = gwm.id
left join github_pull_request_latest_unlocks as latest_unlocks
    on latest_unlocks.repository = gwm.repository and latest_unlocks.pull_number = gwm.pull_number
left join drift_work_manifests as gdwm
    on gdwm.work_manifest = gwm.id
left join github_drift_latest_unlocks as latest_drift_unlocks
    on latest_drift_unlocks.repository = gwm.repository
where gwm.state in ('queued', 'running')
-- Don't consider index runs conflicting, they don't change the underlying infra
      and gwm.run_kind <> 'index'
-- Our own work is not a conflict with ourselves.  The abort above deliberately
-- spares this job's work manifests, so without this we would report our own
-- superseded work back to the user as a conflicting or stale operation.
      and not exists (select 1
                      from job_work_manifests as jwm
                      where jwm.work_manifest = gwm.id and jwm.job_id = $job_id)
      and ((gwm.pull_number is not null
            and (latest_unlocks.unlocked_at is null or latest_unlocks.unlocked_at < gwm.created_at))
           or (gdwm.work_manifest is not null
               and (latest_drift_unlocks.unlocked_at is null or latest_drift_unlocks.unlocked_at < gwm.created_at)))
-- A plan is never in conflict, it is queued behind whatever is already running
-- or queued against its dirspaces.  An apply is in conflict with another apply
-- against those dirspaces, because a second apply is not queued behind the
-- first.  Either is in conflict with work that looks stale, because stale work
-- blocks the queue until it is unlocked.
       and (work_manifests_for_dirspace.maybe_stale
            or ($run_type in ('autoapply', 'apply', 'unsafe-apply')
                and gwm.run_type in ('autoapply', 'apply', 'unsafe-apply')
                and work_manifests_for_dirspace.blocks_apply))
order by gwm.created_at

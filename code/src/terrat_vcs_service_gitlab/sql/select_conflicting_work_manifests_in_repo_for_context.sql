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
  inner join gitlab_repositories_map as grm
    on grm.core_id = jc.repo
  left join gitlab_pull_requests_map as gprm
    on gprm.core_id = (jc.params->>'pull_request')::uuid
  left join gitlab_pull_requests as gpr
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
wm as (
   select
     gwm.*
   from gitlab_work_manifests as gwm
   inner join context as c
     on c.repo = gwm.repository
   left join gitlab_pull_request_latest_unlocks as latest_unlocks
        on latest_unlocks.repository = gwm.repository and latest_unlocks.pull_number = gwm.pull_number
   left join gitlab_drift_latest_unlocks as latest_drift_unlocks
        on latest_drift_unlocks.repository = gwm.repository
   where gwm.state in ('queued', 'running')
         and (latest_unlocks.unlocked_at is null or latest_unlocks.unlocked_at < gwm.created_at)
         and (latest_drift_unlocks.unlocked_at is null or latest_drift_unlocks.unlocked_at < gwm.created_at)
),
work_manifests_for_dirspace as (
    select
        gwm.id,
-- Consider a work manifest as maybe stale if it was dispatched but has not
-- started after a minute, or if it has been in flight for over an hour.  A work
-- manifest that is still queued is not stale, it may legitimately be waiting on
-- other work against its dirspaces.
        ((gwm.state = 'running'
          and gwm.run_id is null
          and (now() - gwm.created_at > interval '1 minutes'))
         or (now() - gwm.created_at > interval '1 hour')) as maybe_stale
    from dirspaces
    inner join work_manifest_dirspaceflows as gwmdsfs
        on dirspaces.dir = gwmdsfs.path and dirspaces.workspace = gwmdsfs.workspace
    inner join wm as gwm
        on gwmdsfs.work_manifest = gwm.id
    inner join context as c
      on c.repo = gwm.repository
    group by gwm.id, gwm.state, gwm.run_id, gwm.created_at
)
select
    gwm.id,
    work_manifests_for_dirspace.maybe_stale
from wm as gwm
inner join context as c
  on c.repo = gwm.repository
inner join work_manifests_for_dirspace
    on work_manifests_for_dirspace.id = gwm.id
left join gitlab_pull_request_latest_unlocks as latest_unlocks
    on latest_unlocks.repository = gwm.repository and latest_unlocks.pull_number = gwm.pull_number
left join drift_work_manifests as gdwm
    on gdwm.work_manifest = gwm.id
left join gitlab_drift_latest_unlocks as latest_drift_unlocks
    on latest_drift_unlocks.repository = gwm.repository
where gwm.state in ('queued', 'running')
-- Don't consider index runs conflicting, they don't change the underlying infra
      and gwm.run_kind <> 'index'
      and ((gwm.pull_number is not null
            and (latest_unlocks.unlocked_at is null or latest_unlocks.unlocked_at < gwm.created_at))
           or (gdwm.work_manifest is not null
               and (latest_drift_unlocks.unlocked_at is null or latest_drift_unlocks.unlocked_at < gwm.created_at)))
-- A plan is never in conflict, it is queued behind whatever is already running
-- or queued against its dirspaces.  An apply is in conflict with another apply
-- against those dirspaces, because a second apply is not queued behind the
-- first.  Either is in conflict with work that looks stale, because stale work
-- blocks the queue until it is unlocked.
      and (($run_type in ('autoapply', 'apply', 'unsafe-apply')
            and gwm.run_type in ('autoapply', 'apply', 'unsafe-apply'))
           or work_manifests_for_dirspace.maybe_stale)
order by gwm.created_at

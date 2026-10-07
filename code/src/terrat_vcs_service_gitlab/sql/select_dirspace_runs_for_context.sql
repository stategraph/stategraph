-- The most recent successful run of each named dirspace of the context, once for a plan and once
-- for an apply, with the sha of the run and the time of its work manifest.  Also whether the most
-- recent plan and the most recent apply failed: a push makes a new head with no checks, and the
-- check of a failed run is written again on the new head (RFD 2356).
-- A failed apply is not the state of the dirspace when a successful plan is newer than it: the
-- newest plan set the check of the dirspace, not the stale apply (Whatnot 5321).
--
-- Unlike select_dirspace_applies_for_context.sql, this does not test the sha of the work manifest
-- against the sha of the branch.  Whether a run still counts is a question about the hashes of
-- the files of that dirspace, and the caller answers it, thus this query gives the sha of the run
-- and lets the caller decide.  The time is what puts the runs of the layers in order.  The heads
-- at the start and at the result of a run are the pairs of commits that moved while it operated
-- (RFD 2356); the views do not carry them, thus they come from work_manifests.
with
context as (
  select
    jc.id,
    grm.repository_id as repo,
    gprm.pull_number as pull_number
  from job_contexts as jc
  inner join gitlab_repositories_map as grm
    on grm.core_id = jc.repo
  left join gitlab_pull_requests_map as gprm
    on gprm.core_id = (jc.params->>'pull_request')::uuid
  where jc.id = $context_id
),
jobs as (
  select jobs.*
  from jobs
  inner join context as jc
    on jc.id = jobs.context_id
),
wm as (
  select
      wm.id as id,
      wm.sha as sha,
      wm.created_at as created_at,
      refs.start_sha as start_sha,
      refs.result_sha as result_sha,
      refs.start_dest_sha as start_dest_sha,
      refs.result_dest_sha as result_dest_sha,
      (case
         when wm.run_type in ('autoapply', 'apply', 'unsafe-apply') then 'apply'
         when wm.run_type in ('autoplan', 'plan') then 'plan'
         else wm.run_type
       end) as run_type
  from gitlab_work_manifests as wm
  inner join work_manifests as refs
    on refs.id = wm.id
  inner join context as c
    on c.repo = wm.repository
  inner join job_work_manifests as jwm
    on jwm.work_manifest = wm.id
  inner join jobs
    on jwm.job_id = jobs.id
  left join gitlab_pull_request_latest_unlocks as unlocks
    on unlocks.repository = wm.repository and unlocks.pull_number = wm.pull_number
  left join gitlab_drift_latest_unlocks as drift_unlocks
    on drift_unlocks.repository = wm.repository
  where (c.pull_number is not distinct from wm.pull_number)
        and ((jobs.params->'kind' is null
              and (unlocks.unlocked_at is null or unlocks.unlocked_at < wm.created_at))
             or (jobs.params->'kind'->>'type' = 'drift'
                 and (drift_unlocks.unlocked_at is null or drift_unlocks.unlocked_at < wm.created_at)))
),
dirspaces as (
    select path, workspace from unnest($dirs, $workspaces) as v(path, workspace)
),
-- A plan which found no changes has nothing to apply, thus the caller needs to know whether the
-- plan found changes.  A run with no plan row counts as a run with changes, which keeps the
-- dirspace unapplied.
runs as (
  select
      wmr.path as path,
      wmr.workspace as workspace,
      wm.run_type as run_type,
      wm.sha as sha,
      wm.created_at as created_at,
      wm.start_sha as start_sha,
      wm.result_sha as result_sha,
      wm.start_dest_sha as start_dest_sha,
      wm.result_dest_sha as result_dest_sha,
      coalesce(plans.has_changes, true) as has_changes,
      wmr.success as success,
      row_number() over (partition by wmr.path, wmr.workspace, wm.run_type, wmr.success
                         order by wm.created_at desc) as rn,
      row_number() over (partition by wmr.path, wmr.workspace, wm.run_type
                         order by wm.created_at desc) as newest
  from wm
  inner join work_manifest_results as wmr
    on wmr.work_manifest = wm.id
  inner join dirspaces as ds
    on ds.path = wmr.path and ds.workspace = wmr.workspace
  left join plans
    on plans.work_manifest = wm.id and plans.path = wmr.path and plans.workspace = wmr.workspace
)
select
  ds.path,
  ds.workspace,
  last_plan.sha,
  to_char(last_plan.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  last_plan.has_changes,
  last_plan.start_sha,
  last_plan.result_sha,
  last_plan.start_dest_sha,
  last_plan.result_dest_sha,
  last_apply.sha,
  to_char(last_apply.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  last_apply.start_sha,
  last_apply.result_sha,
  last_apply.start_dest_sha,
  last_apply.result_dest_sha,
  newest_plan.success is false,
  -- A failed apply is not the state of the dirspace when a successful plan is newer than it:
  -- then the newest plan set the check of the dirspace (Whatnot 5321).
  newest_apply.success is false
    and not coalesce(
      newest_plan.success and newest_plan.created_at > newest_apply.created_at,
      false)
from dirspaces as ds
left join runs as last_plan
  on last_plan.path = ds.path
     and last_plan.workspace = ds.workspace
     and last_plan.run_type = 'plan'
     and last_plan.success
     and last_plan.rn = 1
left join runs as last_apply
  on last_apply.path = ds.path
     and last_apply.workspace = ds.workspace
     and last_apply.run_type = 'apply'
     and last_apply.success
     and last_apply.rn = 1
left join runs as newest_plan
  on newest_plan.path = ds.path
     and newest_plan.workspace = ds.workspace
     and newest_plan.run_type = 'plan'
     and newest_plan.newest = 1
left join runs as newest_apply
  on newest_apply.path = ds.path
     and newest_apply.workspace = ds.workspace
     and newest_apply.run_type = 'apply'
     and newest_apply.newest = 1

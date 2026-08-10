-- This CTE selects only the dirspaces which 
-- changed in the current work manifest
-- provided by Terrateam's server.
with currently_changed_dirspaces as (
  select
    cd.path as dir,
    cd.workspace
  from change_dirspaces cd
  inner join work_manifests wm on (
        wm.sha = cd.sha
    and wm.base_sha = cd.base_sha
    and wm.repo = cd.repo
  )
  where wm.id = $work_manifest
),
-- The pull request the current work manifest belongs to.  Output is only ever
-- carried forward within a single pull request, so applies from anywhere else
-- are irrelevant.
current_pull_request as (
  select
    gwm.repository as repository,
    gwm.pull_number as pull_number
  from github_work_manifests gwm
  where gwm.id = $work_manifest and gwm.pull_number is not null
),
-- The most recent successful apply for each dirspace in this pull request.
-- Applies from before the pull request was last unlocked do not count, matching
-- how the rest of the system treats an unlock as resetting applied state.
applied_dirspaces as (
  select
    gwmr.path as dir,
    gwmr.workspace as workspace,
    max(gwm.created_at) as applied_at
  from github_work_manifests gwm
  inner join current_pull_request cpr on (
        cpr.repository = gwm.repository
    and cpr.pull_number = gwm.pull_number
  )
  inner join work_manifest_results gwmr on gwmr.work_manifest = gwm.id
  left join github_pull_request_latest_unlocks unlocks on (
        unlocks.repository = gwm.repository
    and unlocks.pull_number = gwm.pull_number
  )
  where gwm.run_type in ('apply', 'autoapply', 'unsafe-apply')
        and gwm.completed_at is not null
        and gwmr.success
        and (unlocks.unlocked_at is null or unlocks.unlocked_at < gwm.created_at)
  group by gwmr.path, gwmr.workspace
)
select
    wm.id,
    gwmc.dir,
    gwmc.workspace,
    wm.run_type,
    -- True when this output was produced before the dirspace was applied, which
    -- makes it a historical record rather than a description of pending work.
    -- Comparing against the apply time (rather than just asking "was it ever
    -- applied") keeps a re-plan made after an apply from being marked stale.
    coalesce(ad.applied_at > wm.created_at, false) as applied,
    wso.ignore_errors,
    wso.payload,
    wso.scope,
    wso.success,
    wso.step
from github_work_manifest_comments gwmc
-- Do not confuse this with the work manifests
-- targeted by the CTE, these ones are from
-- previous runs that may still be relevant to be
-- posted in a comment.
inner join work_manifests wm on gwmc.work_manifest = wm.id
inner join workflow_step_outputs wso on (
        wso.work_manifest = wm.id 
    and wso.scope->>'type' = 'dirspace'
    and gwmc.dir = wso.scope->>'dir' 
    and gwmc.workspace = wso.scope->>'workspace'
)
inner join currently_changed_dirspaces ccd on (
        gwmc.dir = ccd.dir
    and gwmc.workspace = ccd.workspace
)
left join applied_dirspaces ad on (
        gwmc.dir = ad.dir
    and gwmc.workspace = ad.workspace
)
where
    gwmc.comment_id = $comment_id
order by wso.idx

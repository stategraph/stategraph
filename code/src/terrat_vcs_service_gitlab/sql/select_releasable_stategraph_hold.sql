-- The pull request of the apply work manifest, by core id, when its hold may go: the pull request
-- merged, so the base branch carries the change, or it was closed without merging, so nobody is to
-- bring the change in, or it was unlocked after the apply was made, so its runs no longer count (the
-- rule of select_parallel_apply_transactions.sql).  No row for a work manifest of no pull request,
-- or whose pull request is open and not unlocked since.
select gprm.core_id
from gitlab_work_manifests as gwm
inner join gitlab_pull_requests_map as gprm
    on gprm.repository_id = gwm.repository and gprm.pull_number = gwm.pull_number
inner join gitlab_pull_requests as gpr
    on gpr.repository = gwm.repository and gpr.pull_number = gwm.pull_number
left join gitlab_pull_request_latest_unlocks as unlocks
    on unlocks.repository = gwm.repository and unlocks.pull_number = gwm.pull_number
where gwm.id = $work_manifest
      and (gpr.state in ('closed', 'merged')
           or unlocks.unlocked_at > gwm.created_at)

-- A work manifest that is running and older than the stale timeout of its repository has stopped.
-- It holds the directories and workspaces of its operation, and the work behind it waits with no
-- end.  The conflict check of an operation that waits aborts such a run when it never called home
-- (RFD 2826), but a run that called home once and then stopped is reachable only from a clock,
-- and this sweep is that clock.
--
-- The clock is [dispatched_at], the time the run started, and [created_at] is its fallback:
-- [dispatched_at] is null only for a run of a server that does not write it, and such a run has no
-- start time of its own.  The wait in the queue is thus not part of the age, which is the same
-- rule as the start check, so a run that waited a day for a runner is not stale the moment it
-- starts.  [work_manifests] keeps no last-seen column, thus the state of the run decides and not
-- [run_id]: a run that never polled and a run that polled once and then stopped read the same
-- here.
--
-- The threshold is the stale timeout of the repository itself, read from the derived config of
-- the run's (repo, branch, sha).  The sweep is one statement for every repository, and the
-- derived rows are the only per-repository copy of a config that the database keeps.  The join
-- carries [installation] because the unique index of the derived rows starts with it, thus the
-- statement reads at most one row without a scan; [repo_configs] holds the core installation, so
-- the map of the view turns the installation id of the row into it.  A run whose config row is
-- gone falls back to the default of one day, so a row that is missing never drops a run from the
-- sweep.
--
-- The server writes this key, and the writer emits a JSON number for it.  The
-- repository config schema rejects a value outside the range, so a row the
-- server wrote always casts.
--
-- The batch is bounded, as in delete_old_repo_trees.sql: a sweep that cannot keep up leaves the
-- rest to the run of the next hour.
with
stale_work_manifests as (
    select gwm.id
    from gitlab_work_manifests as gwm
-- The view carries no core repo, thus it comes from work_manifests.
    inner join work_manifests as core
        on core.id = gwm.id
    left join gitlab_installations_map as gim
        on gim.installation_id = gwm.installation_id
    left join repo_configs as rc
        on rc.kind = 'derived'
        and rc.installation = gim.core_id
        and rc.repo = core.repo
        and rc.branch = gwm.branch
        and rc.sha = gwm.sha
    where gwm.state = 'running'
          and now() - coalesce(core.dispatched_at, gwm.created_at)
              > make_interval(secs => coalesce((rc.data -> 'work_manifests' ->> 'stale_timeout_sec')::double precision, 86400))
    limit 100
),
aborted_work_manifests as (
    update work_manifests
    set state = 'aborted', completed_at = now()
    from stale_work_manifests
    where work_manifests.id = stale_work_manifests.id
    returning work_manifests.id
)
select id from aborted_work_manifests

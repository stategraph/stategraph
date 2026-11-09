-- Migrate a legacy default-branch sentinel row: copy (repo, '', name) to (repo, branch, name)
-- and delete the sentinel row, in one statement so no crash can leave either a lost schedule
-- or a half-migrated pair. An existing explicit-name row wins: ON CONFLICT DO NOTHING keeps
-- a fresh push's fields over the legacy row's, and the sentinel row is deleted either way.
-- last_tried_at is copied so the migrated row does not re-fire the slot that just ran.
with
new_row as (
    insert into drift_schedules
      (schedule, reconcile, restart_on_change, tag_query, updated_at, name, window_start, window_end, branch, last_tried_at, repo)
    select
        ds.schedule,
        ds.reconcile,
        ds.restart_on_change,
        ds.tag_query,
        ds.updated_at,
        ds.name,
        ds.window_start,
        ds.window_end,
        $branch,
        ds.last_tried_at,
        ds.repo
    from drift_schedules as ds
    inner join gitlab_repositories_map as grm
        on grm.core_id = ds.repo
    where grm.repository_id = $repo
          and ds.name = $name
          and ds.branch = ''
    on conflict on constraint drift_schedules_pkey
    do nothing
)
delete from drift_schedules
using gitlab_repositories_map as grm
where grm.core_id = drift_schedules.repo
      and grm.repository_id = $repo
      and drift_schedules.name = $name
      and drift_schedules.branch = ''

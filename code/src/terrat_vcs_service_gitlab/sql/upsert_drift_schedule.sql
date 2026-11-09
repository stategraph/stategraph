insert into drift_schedules as gds
  (schedule, reconcile, restart_on_change, tag_query, updated_at, name, window_start, window_end, branch, repo)
select
        $schedule,
        $reconcile,
        $restart_on_change,
        $tag_query,
        now(),
        $name,
        $window_start,
        $window_end,
        $branch,
        grm.core_id
from gitlab_repositories_map as grm
where grm.repository_id = $repo
on conflict on constraint drift_schedules_pkey
do update set
  (schedule,
   reconcile,
   restart_on_change,
   tag_query,
   updated_at,
   name,
   window_start,
   window_end) =
     (excluded.schedule,
      excluded.reconcile,
      excluded.restart_on_change,
      excluded.tag_query,
      excluded.updated_at,
      excluded.name,
      excluded.window_start,
      excluded.window_end)
where
  (gds.schedule, gds.reconcile, gds.restart_on_change, gds.tag_query, gds.name, gds.window_start, gds.window_end) <> (excluded.schedule, excluded.reconcile, excluded.restart_on_change, excluded.tag_query, excluded.name, excluded.window_start, excluded.window_end)

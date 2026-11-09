-- Pick the next drift schedule that needs to fire, marking it as tried.
--
-- Eligibility model: fire at most once per slot, where a slot is one occurrence of the schedule
-- period (hour/day/week/month) anchored at the window's open time.
--
--   slot_offset = window_start's time-of-day, or 0 when no window
--   shifted(t) = t - slot_offset
--   eligible   = date_trunc(unit, shifted(last_tried)) < date_trunc(unit, shifted(now))
--
-- The shift moves the bucket boundary from midnight to window-open, so a wrap window like
-- 23:30-04:00 stays inside one slot.
--
-- Examples for schedule = daily (unit = 'day'):
--
--   window 09:00-12:00, slot_offset = 09:00
--     last_tried           now                  shifted(last) shifted(now) result
--     -------------------- -------------------- ------------- ------------ ------
--     Mon 09:01            Mon 11:55            Mon 00:01     Mon 02:55    skip (same day)
--     Mon 09:01            Tue 09:01            Mon 00:01     Tue 00:01    fire (new day)
--
--   wrap window 23:30-04:00, slot_offset = 23:30
--     last_tried           now                  shifted(last) shifted(now) result
--     -------------------- -------------------- ------------- ------------ ------
--     Mon 23:35            Tue 00:30            Mon 00:05     Mon 01:00    skip (same day)
--     Mon 23:35            Tue 23:35            Mon 00:05     Tue 00:05    fire (new day)
--
--   no window, slot_offset = 0
--     last_tried           now                  shifted(last) shifted(now) result
--     -------------------- -------------------- ------------- ------------ ------
--     Mon 23:00            Tue 00:05            Mon 23:00     Tue 00:05    fire (new day)
--
-- Examples for schedule = hourly (unit = 'hour'):
--
--   no window, slot_offset = 0
--     last_tried           now                  shifted(last) shifted(now) result
--     -------------------- -------------------- ------------- ------------ -------
--     Mon 09:30            Mon 09:55            Mon 09:30     Mon 09:55    skip (same hour)
--     Mon 09:30            Mon 10:00            Mon 09:30     Mon 10:00    fire (new hour)
--
--   window 09:00-12:00, slot_offset = 09:00
--     last_tried           now                  shifted(last) shifted(now) result
--     -------------------- -------------------- ------------- ------------ -------
--     Mon 09:01            Mon 09:45            Mon 00:01     Mon 00:45    skip (same hour)
--     Mon 09:01            Mon 10:01            Mon 00:01     Mon 01:01    fire (new hour)
--     Mon 10:01            Mon 11:01            Mon 01:01     Mon 02:01    fire (new hour)
--
--   wrap window 23:30-04:00, slot_offset = 23:30
--     last_tried           now                  shifted(last) shifted(now) result
--     -------------------- -------------------- ------------- ------------ -------
--     Mon 23:35            Tue 00:35            Mon 00:05     Mon 01:05    fire (new hour)
--     Tue 00:35            Tue 01:35            Mon 01:05     Mon 02:05    fire (new hour)
with
ds as (
    select
        ds.name,
        grm.repository_id as repository,
        (case ds.schedule
         when 'hourly' then 'hour'
         when 'daily' then 'day'
         when 'weekly' then 'week'
         when 'monthly' then 'month'
         end) as schedule_unit,
         nullif(branch, '') as branch,
         ds.reconcile,
         ds.restart_on_change,
         ds.tag_query,
         ds.updated_at,
         (current_date + ds.window_start at time zone current_setting('timezone')) as window_start,
         (current_date + ds.window_end at time zone current_setting('timezone')) as window_end,
         coalesce((ds.window_start at time zone current_setting('timezone'))::time::interval,
                  interval '0') as slot_offset,
         ds.repo as repo_core_id
    from drift_schedules as ds
    inner join gitlab_repositories_map as grm
        on grm.core_id = ds.repo
    where schedule in ('hourly', 'daily', 'weekly', 'monthly')
),
drift_schedule_windows as (
    select
        repository,
        name,
        coalesce(branch, '') as branch,
        window_start,
        window_end
    from ds
    where window_start is not null and window_end is not null
),
chosen_drift_schedule as (
    select
        ds.name as drift_name,
        gir.installation_id as installation_id,
        gir.id as repository,
        gir.owner as owner,
        gir.name as name,
        ds.branch,
        ds.reconcile,
        ds.restart_on_change,
        ds.tag_query,
        dsw.window_start,
        dsw.window_end,
        ds.repo_core_id
    from ds
    inner join drift_schedules
        on drift_schedules.repo = ds.repo_core_id and drift_schedules.name = ds.name
        and drift_schedules.branch = coalesce(ds.branch, '')
    inner join gitlab_installation_repositories as gir
        on gir.id = ds.repository
    inner join gitlab_installations as gi
        on gi.id = gir.installation_id
    left join drift_schedule_windows as dsw
        on (dsw.repository, dsw.name) = (ds.repository, ds.name)
        and dsw.branch = coalesce(ds.branch, '')
    where (dsw.window_start is null
           or (dsw.window_start <= dsw.window_end
               and dsw.window_start <= current_timestamp
               and current_timestamp < dsw.window_end)
           or (dsw.window_start > dsw.window_end
               and (dsw.window_start <= current_timestamp
                    or current_timestamp < dsw.window_end)))
          and gi.state = 'installed'
          and (drift_schedules.last_tried_at is null
               or drift_schedules.last_tried_at < drift_schedules.updated_at
               or date_trunc(ds.schedule_unit, drift_schedules.last_tried_at - ds.slot_offset)
                  < date_trunc(ds.schedule_unit, current_timestamp - ds.slot_offset))
    limit 1
    for update of drift_schedules skip locked
),
updated_last_tried as (
    update drift_schedules as ds
      set last_tried_at = now()
    from chosen_drift_schedule as cds
    where cds.repo_core_id = ds.repo
          and (cds.branch is null and ds.branch = '' or ds.branch = cds.branch)
          and ds.name = cds.drift_name
    returning cds.*
)
select
    drift_name,
    installation_id,
    repository,
    owner,
    name,
    reconcile,
    restart_on_change,
    tag_query,
    window_start,
    window_end,
    branch
from updated_last_tried

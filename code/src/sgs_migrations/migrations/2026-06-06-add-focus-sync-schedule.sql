-- Seed the singleton FOCUS sync schedule.  Sgs_service_scheduler fires kind
-- 'focus_billing_sync' on this cadence and Sgs_focus_sync_dispatch fans out to
-- every enabled focus_billing_sources row.  Daily is plenty: FOCUS restates the
-- open month and each sync is an idempotent trailing-window reload, so exact
-- cadence is not load-bearing.
insert into schedules (schedule, kind)
  select 'daily', 'focus_billing_sync'
  where not exists (select 1 from schedules where kind = 'focus_billing_sync');

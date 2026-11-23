-- The run lock of the daily tenant retention task: one runner at a time changes the schedule.
-- Non-blocking: a runner that finds the lock held skips the run.  Transaction-scoped.
select pg_try_advisory_xact_lock($key, hashtext('tenant_retention'))

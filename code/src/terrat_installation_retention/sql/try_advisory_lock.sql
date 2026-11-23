-- The run lock of the daily installation retention task of one provider: one
-- runner at a time changes the schedule of that provider.  Non-blocking: a
-- runner that finds the lock held skips the run, whose work stays for the next
-- one.  Transaction-scoped, so it releases itself on commit and on rollback.
select pg_try_advisory_xact_lock($key, hashtext('installation_retention:' || $provider))

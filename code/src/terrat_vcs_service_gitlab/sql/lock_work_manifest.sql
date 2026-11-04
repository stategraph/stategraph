-- Reserve the work manifest for the caller: hold its row until the transaction
-- of the caller ends.  For the dispatcher the reservation already happened at
-- the candidate read, select_next_work_manifest.sql, so this hold is a no-op on
-- a row that the caller owns.  For the poll it is the reservation, taken after
-- the hold of the job row (lock_work_manifest_job.sql).  A caller whose answer
-- is 'yes' holds both rows, in the order compute_nodes, jobs, work_manifests
-- that the poll holds.
--
-- The lock skips a row that another transaction already holds instead of
-- waiting for it: the work manifest is being dispatched by that transaction,
-- and this statement answers nothing, which the caller reads as 'busy'.  A row
-- that no transaction holds comes back, and holding it is what turns the
-- caller's later 'yes' into a reservation.
select id
from work_manifests
where id = $work_manifest_id
for update
skip locked

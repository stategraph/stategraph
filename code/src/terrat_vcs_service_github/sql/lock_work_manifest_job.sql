-- Hold the row of the job of a work manifest until the transaction of the caller
-- ends.  The count of the running work manifests of the job that the dispatch
-- query applies is a plain read, so two dispatchers that answer it at the same
-- time can pass the same free slot.  The row lock is the mutex: the contender
-- waits, and its next read counts the work manifest that the winner committed.
--
-- The lock must be its own statement.  One statement that locks the row and
-- counts keeps the snapshot from before the lock, so the count would read the
-- state that the lock was meant to exclude.  The caller re-asks its question
-- after this statement returns (RFD 2903).
--
-- A work manifest with no job row locks no row.  It keeps the old path, which no
-- limit governs.
select id
from jobs
where id = (select job_id
            from job_work_manifests
            where work_manifest = $work_manifest_id)
for update

-- Hold the row of a job without waiting for it, for the dispatcher.  The count
-- of the running work manifests of the job that the dispatch query applies is a
-- plain read, so two dispatchers that answer it at the same time can pass the
-- same free slot.  The row lock is the mutex: the dispatcher that holds it
-- counts the committed work and starts the work manifest, and the contender's
-- [skip locked] answers nothing instead of waiting.
--
-- The claim is the job id itself and not a subquery over
-- job_work_manifests, because the answer must not be ambiguous: an empty
-- answer means the job row is held by another transaction, which the caller
-- reads as 'claim the job's candidates out of this drain'.  A work manifest
-- with no job row never reaches this statement, because the candidate answer
-- carries no job id and the caller takes no claim for it.
--
-- This is the skip-locked twin of lock_work_manifest_job.sql, which stays
-- blocking: the poll holds the row of the compute node first and must wait
-- for the job row it polls for.  The dispatcher holds a reservation on the
-- row of its work manifest and must never wait, or it inverts the order of
-- the poll and the two can deadlock (RFD 2903).
select id
from jobs
where id = $job_id
for update
skip locked

-- The read from a work manifest to its job.  The primary key is
-- (job_id, work_manifest), so it cannot serve this read, and the read then scans
-- the full table.  The count of the running work manifests of each job has the
-- same problem from the other side: without this index the planner hash joins a
-- sequential scan of the whole table, and the cost grows with the history of
-- every job rather than with the runs that are running now.
--
-- The dispatcher uses this read to find the job of the work manifest it picked,
-- so that it can count the running work manifests of that job against the
-- work_manifests.concurrent_runs limit of the repository (RFD 2903), and to hold
-- the row of the job while it counts: the row lock is the mutex that stops two
-- dispatchers from starting two work manifests of the same job past the limit.
--
-- The build is not concurrent, and this migration is not asynchronous, on
-- purpose.  An asynchronous migration is recorded as done before its SQL runs
-- (see [Data_mig.exec]), so a build that fails is never tried again.  A build
-- inside the transaction fails the migration instead, which leaves it
-- unrecorded, so the server boots, runs the migration again, fails again, and
-- exits.  A create unique index over duplicated rows fails identically every
-- time, so the delete below, not the retry, is what keeps a database with a
-- broken past from a boot loop.
--
-- The delete is the first enforcement of "a work manifest carries one job
-- row".  Every write goes through upsert_job_work_manifest.sql, which is
-- idempotent over the pair, and the work manifest ids are always fresh, so a
-- duplicate is not produced by any code path this repository knows; but
-- nothing checked the table before, and a duplicate row is one no reader
-- interprets: select_job_by_work_manifest_id.sql takes the head and discards
-- the rest.  Keep the newest job row of each work manifest, as
-- [2026-02-20-add-transaction-log-unique-indices] does.  While the build runs
-- it blocks writes to job_work_manifests.
delete from job_work_manifests
where (job_id, work_manifest) in (
  select job_id, work_manifest
  from (
    select jwm.job_id, jwm.work_manifest,
           row_number() over (partition by jwm.work_manifest
                              order by jobs.created_at desc, jobs.id desc) as rn
    from job_work_manifests as jwm
    inner join jobs on jobs.id = jwm.job_id) as ranked
  where ranked.rn > 1);

create unique index job_work_manifests_work_manifest_idx
       on job_work_manifests (work_manifest);

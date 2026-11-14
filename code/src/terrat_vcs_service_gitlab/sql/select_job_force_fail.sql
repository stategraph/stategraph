-- The verdict [update_job_force_fail] recorded.  A key that is absent, null or false all answer
-- false: only a true key forces the run to count as failed.
select coalesce((params->>'force_fail')::boolean, false) from jobs where id = $job

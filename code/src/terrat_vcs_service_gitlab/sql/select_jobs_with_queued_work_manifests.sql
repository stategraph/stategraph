-- The running jobs of a context that own a work manifest still queued.  Once
-- the pull request of the context is merged, such a work manifest would run on
-- a branch that is merged, or that is gone.
select distinct
    jobs.id
from jobs
inner join job_work_manifests as jwm
    on jwm.job_id = jobs.id
inner join work_manifests as wm
    on wm.id = jwm.work_manifest
where jobs.context_id = $context_id
      and jobs.state = 'running'
      and wm.state = 'queued'

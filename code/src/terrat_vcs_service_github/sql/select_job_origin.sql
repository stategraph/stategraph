-- The job that started the run the given job is a layer of: the head of its chain of
-- continuations.  A job that continues nothing is its own origin.
with recursive chain(id, continuation_of) as (
  select id, continuation_of from jobs where id = $id
  union all
  select jobs.id, jobs.continuation_of
  from jobs
  inner join chain
    on jobs.id = chain.continuation_of
)
select
    jobs.id,
    jobs.context_id,
    jobs.params,
    jobs.state,
    jobs.initiator,
    to_char(jobs.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    to_char(jobs.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    to_char(jobs.completed_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
from jobs
inner join chain
  on chain.id = jobs.id
where chain.continuation_of is null

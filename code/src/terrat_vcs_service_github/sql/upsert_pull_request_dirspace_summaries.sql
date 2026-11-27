-- Store the state of each named dirspace of the pull request of the context at
-- the head $sha (RFD 2356), and mark the unified summary comment dirty when a
-- state changed, thus the next drain shows it.  Each store is a new decision
-- about the head, thus updated_at moves even when the state stays the same.
-- $work_manifest is the run whose result decided the states, or null.
with
context as (
  select
    grm.repository_id as repository,
    gprm.pull_number as pull_number
  from job_contexts as jc
  inner join github_repositories_map as grm
    on grm.core_id = jc.repo
  inner join github_pull_requests_map as gprm
    on gprm.core_id = (jc.params->>'pull_request')::uuid
  where jc.id = $context_id
),
summaries as (
  select s.path, s.workspace, s.state
  from unnest($dirs, $workspaces, $states) as s(path, workspace, state)
),
changed as (
  select 1
  from summaries as s
  cross join context as c
  left join github_pull_request_dirspace_summaries as old
    on old.repository = c.repository
       and old.pull_number = c.pull_number
       and old.sha = $sha
       and old.path = s.path
       and old.workspace = s.workspace
  where old.state is distinct from s.state
),
stored as (
  insert into github_pull_request_dirspace_summaries
    (repository, pull_number, sha, path, workspace, state, work_manifest)
  select c.repository, c.pull_number, $sha, s.path, s.workspace, s.state, $work_manifest
  from summaries as s
  cross join context as c
  -- One fixed order for every caller: the rows of the conflict resolution are the rows of this
  -- select, and two writers which take the same rows in opposite orders deadlock (40P01).
  order by s.path, s.workspace
  on conflict (repository, pull_number, sha, path, workspace)
  do update set
    state = excluded.state,
    updated_at = current_timestamp,
    work_manifest = excluded.work_manifest
  returning 1
)
update github_unified_comments as guc
set dirty = guc.dirty + 1
from context as c
where guc.repository = c.repository
  and guc.pull_number = c.pull_number
  and exists (select 1 from changed)
  and exists (select 1 from stored)

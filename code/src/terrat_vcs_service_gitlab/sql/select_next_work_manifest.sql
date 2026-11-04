-- The statement is the candidate read of the dispatcher, and it reserves the
-- work manifest it answers: the final select holds the row of the work
-- manifest with [for update skip locked], so an answer is a work manifest no
-- other transaction owns, and the hold lasts until the transaction of the
-- caller ends.  Two dispatchers, on separate servers or on separate threads
-- of one server, cannot read the same row here: the second one's [skip
-- locked] passes the row the first one holds and takes the next candidate in
-- the order instead.
--
-- The reservation does not replace work_manifest_can_run: the rules of this
-- statement were evaluated on the snapshot of the reader, and another
-- dispatcher can have committed work since.  The dispatcher holds the row of
-- the compute node of the candidate, then claims the row of its job without
-- waiting (claim_work_manifest_job.sql), and then asks this statement again
-- about that one work manifest through work_manifest_can_run, whose answer
-- is the authority.  A work manifest the answer declines stays queued.
--
-- A claim that answers nothing means the job row is held by another
-- transaction, which is either dispatching a sibling work manifest of the
-- same job or making the job terminal.  The dispatcher ends its transaction,
-- adds the job to $excluded_jobs, and asks again.  The exclusion removes the
-- candidates of that one job from the answer of this statement only; it
-- never touches the rules, whose view of the queue must stay whole.  A work
-- manifest with no job row takes no claim, and no limit governs it.
with
wms as (
    select
        wm.id as id,
        wm.created_at as created_at,
        wm.base_sha as base_sha,
        wm.sha as sha,
        wm.pull_request as pull_request,
        grm.repository_id as repository,
        wm.repo as repo,
        wm.branch as branch,
        gir.installation_id as installation_id,
        wm.state as state,
        (case wm.run_type
         when 'autoapply' then 'apply'
         when 'apply' then 'apply'
         when 'unsafe-apply' then 'apply'
         when 'autoplan' then 'plan'
         when 'plan' then 'plan'
         end) as unified_run_type,
        (case wm.run_type
         when 'autoapply' then 0
         when 'apply' then 0
         when 'unsafe-apply' then 0
         when 'autoplan' then 1
         when 'plan' then 1
         end) as priority
    from work_manifests as wm
    inner join gitlab_repositories_map as grm
        on grm.core_id = wm.repo
    inner join gitlab_installation_repositories as gir
        on gir.id = grm.repository_id
    left join lateral (
        select pru.unlocked_at
        from pull_request_unlocks as pru
        where pru.pull_request = wm.pull_request
        order by pru.unlocked_at desc
        limit 1
    ) as unlocks on true
    left join lateral (
        select du.unlocked_at
        from drift_unlocks as du
        where du.repo = (select core_id
                         from gitlab_repositories_map
                         where repository_id = grm.repository_id)
        order by du.unlocked_at desc
        limit 1
    ) as drift_unlocks on true
    where wm.state in ('queued', 'running')
          and ((wm.run_kind = 'pr'
                and (unlocks.unlocked_at is null or unlocks.unlocked_at < wm.created_at))
               or (wm.run_kind = 'drift'
                   and (drift_unlocks.unlocked_at is null or drift_unlocks.unlocked_at < wm.created_at))
               or wm.run_kind = 'index')
),
-- Whether a dirspace of a run applies in parallel, see below: the edition
-- allows it ($stategraph_parallel_applies) and the dirspace runs the Stategraph
-- engine, the engine of its workflow or else the default one, read from the
-- derived config of the run's (repo, branch, sha), the per-repository copy of a
-- config that the database keeps (abort_stale_work_manifests.sql).  A run whose
-- config row is gone is not parallel: it waits, as it always has.
dirspaces_for_work_manifests as (
    select
        gwmds.work_manifest,
        gwmds.path,
        gwmds.workspace,
        $stategraph_parallel_applies
        and coalesce(coalesce(rc.data -> 'workflows' -> gwmds.workflow_idx::int -> 'engine' ->> 'name',
                              rc.data -> 'engine' ->> 'name') = 'stategraph',
                     false) as stategraph_parallel_apply
    from work_manifest_dirspaceflows as gwmds
    inner join wms
        on gwmds.work_manifest = wms.id
    inner join work_manifests as wm
        on wm.id = wms.id
    inner join gitlab_repositories_map as grm
        on grm.core_id = wm.repo
    inner join gitlab_installation_repositories as gir
        on gir.id = grm.repository_id
    inner join gitlab_installations_map as gim
        on gim.installation_id = gir.installation_id
    left join repo_configs as rc
        on rc.kind = 'derived'
        and rc.installation = gim.core_id
        and rc.repo = wm.repo
        and rc.branch = wm.branch
        and rc.sha = wm.sha
),
-- The number of work manifests of each job whose state is 'running'.  The limit
-- counts these and nothing else: a work manifest in the state 'queued' does not
-- count, so a job that creates all of its work manifests at once still starts
-- one.
running_work_manifests_per_job as (
    select
        jwm.job_id as job_id,
        count(*) as count
    from job_work_manifests as jwm
    inner join work_manifests as wm
        on wm.id = jwm.work_manifest
    where wm.state = 'running'
    group by jwm.job_id
),
-- A queued work manifest and another one that it may not run beside.  The
-- rules are the ones the dispatcher has always had, written per pair rather
-- than per dirspace so that the exemption below can look at both sides.
--
-- Two runs on the same dirspace may overlap only when both are eligible
-- Stategraph runs (stategraph_parallel_apply) of two different pull requests.
-- Stategraph detects a resource-level overlap atomically when a transaction
-- commits, and a plan taken beside another pull request's apply counts as
-- planned after it (select_dirspaces_owned_by_other_pull_requests.sql).  A
-- drift or index run has no pull request and never overlaps anything.
rejected_work_manifests as (
    select distinct queued.id
    from wms as queued
    inner join dirspaces_for_work_manifests as queued_ds
        on queued_ds.work_manifest = queued.id
    inner join wms as other
        on other.repository = queued.repository
           and other.id <> queued.id
    inner join dirspaces_for_work_manifests as other_ds
        on other_ds.work_manifest = other.id
           and other_ds.path = queued_ds.path
           and other_ds.workspace = queued_ds.workspace
    where queued.state = 'queued'
          and (
              -- An apply waits for plans running against its dirspaces.
              (queued.unified_run_type = 'apply'
               and other.state = 'running'
               and other.unified_run_type = 'plan')
              -- A plan waits for an apply running against its dirspaces.
              or (queued.unified_run_type = 'plan'
                  and other.state = 'running'
                  and other.unified_run_type = 'apply')
              -- A queued apply skips the line: every plan queued against its
              -- dirspaces, those queued before it and those queued after it,
              -- runs only once the apply has completed.  This is what bounds how
              -- long an apply waits, the set of work it is waiting on can only
              -- shrink.
              or (queued.unified_run_type = 'plan'
                  and other.state = 'queued'
                  and other.unified_run_type = 'apply')
              -- An apply waits for an apply running against its dirspaces.
              or (queued.unified_run_type = 'apply'
                  and other.state = 'running'
                  and other.unified_run_type = 'apply')
          )
          and not (
              queued_ds.stategraph_parallel_apply
              and other_ds.stategraph_parallel_apply
              and queued.pull_request is not null
              and other.pull_request is not null
              and queued.pull_request <> other.pull_request
          )
),
-- A work manifest that belongs to a compute node which already runs must not
-- start a second action run.  The node picks it up on its next poll instead.
--
-- The filter belongs here, and not in the final select, so a work manifest
-- the filter declines never reaches the answer: in the final select the same
-- test would return no row at all, and the dispatcher would stop dispatching
-- until the running node finished, instead of moving to the next candidate in
-- the order.
--
-- A work manifest with no compute node is one made before the phase that makes
-- a node with each work manifest.  It keeps the old path.
--
-- Neither join can multiply rows: compute_node_work has a unique index on
-- work_manifest, and compute_nodes joins on its primary key.  Every work
-- manifest therefore still contributes one row, and the ranking of the others
-- does not move.  The joins of the concurrent_runs limit are the same:
-- job_work_manifests has a unique index on work_manifest, the count table has
-- one row for each job, the installations map joins on its primary key, and the
-- derived config row is unique for the (installation, repo, branch, sha) of the
-- run.
--
-- A job that has reached the work_manifests.concurrent_runs limit of its
-- repository holds its next work manifest in the queue.  A work manifest with no
-- job row is one made before the server attached each work manifest to its job,
-- and no limit governs it.  The test of the limit belongs here, with the others,
-- for the same reason the test of the compute node state does: a work manifest
-- the limit declines takes no place in the answer, so the next work manifest in
-- the order becomes the candidate and the dispatcher keeps going.  In the final
-- select the same test would return no row at all, and the dispatcher would
-- stop for that repository.
--
-- The value is the work_manifests.concurrent_runs key of the derived config of
-- the run's (installation, repo, branch, sha), read the way
-- abort_stale_work_manifests.sql reads the stale timeout: the map turns the
-- installation id of the row into the core installation of the config, and a
-- repository whose config row is gone keeps the default.  The derived config
-- drops every key that is equal to its default, so the key is absent for most
-- repositories and coalesce supplies the default of ten, which is
-- [default_concurrent_runs] of [terrat_base_repo_config_v1].  The join to
-- repo_configs is a left join, because branch is nullable and a work manifest of
-- the gitlab provider has no branch: an inner join would drop those work
-- manifests from the dispatcher entirely.
--
-- The server writes this key, and the writer emits a JSON number for it.  The
-- repository config schema rejects a value outside the range, so a row the
-- server wrote always casts.
--
-- $work_manifest_id gives the query a second mode.  When it is null the query
-- answers the dispatcher: which work manifest starts the next action run.  When
-- it is set the query answers the poll of a compute node: may this one work
-- manifest run now.  The two modes share every rule above, which is the point.
-- A rule written twice would drift, and the rules here decide whether two
-- applies can touch one dirspace at the same time.
--
-- The second mode drops one condition of the first: the state of the compute
-- node, because the node that asks is running by definition.  Both modes hold
-- the row of the work manifest they answer; in the second mode the caller
-- already holds that row, so the hold of this statement is a no-op.  The
-- second mode ignores $excluded_jobs: the exclusion is a choice of candidate,
-- never a rule, and the caller that asks about one work manifest passes an
-- empty list.
--
-- The two provider copies of this file are not the same file.  The github copy
-- joins flow_states and binds $new_age; this copy has neither.  That difference
-- came before this rule, and this rule does not change it.  A later change to
-- the shared rules must still reach both copies.
--
-- The limit is read as [double precision] and not as [int].  The writer emits a
-- JSON integer, but a single row that holds a non-canonical numeric form, such
-- as 3.0, would raise on an [int] cast, and the one statement that fails would
-- be the statement every dispatcher of every repository runs.  A float cast
-- accepts any numeric form, which is what abort_stale_work_manifests.sql does
-- with the stale timeout.
-- The ordering and the poll of a compute node must order by the same three
-- keys: priority, then created_at, then id.  The poll is
-- select_compute_node_work.sql, and this statement is the authority for the
-- three keys: a row this statement starts must be the first row the poll of
-- the node serves, or the action run
-- of one work manifest is started with the run id of another.
next_work_manifests as (
    select
        wms.id,
        cn.id as compute_node,
        jwm.job_id as job_id,
        wms.priority,
        wms.created_at
    from wms
    left join rejected_work_manifests as rwm on rwm.id = wms.id
    left join compute_node_work as cnw on cnw.work_manifest = wms.id
    left join compute_nodes as cn on cn.id = cnw.compute_node
    left join job_work_manifests as jwm on jwm.work_manifest = wms.id
    left join running_work_manifests_per_job as rwmpj on rwmpj.job_id = jwm.job_id
    left join gitlab_installations_map as gim
        on gim.installation_id = wms.installation_id
    left join repo_configs as rc
        on rc.kind = 'derived'
        and rc.installation = gim.core_id
        and rc.repo = wms.repo
        and rc.branch = wms.branch
        and rc.sha = wms.sha
    where wms.state = 'queued'
          and rwm.id is null
          and ($work_manifest_id is not null
               or cn.id is null
               or cn.state = 'queued')
          and ($work_manifest_id is null or wms.id = $work_manifest_id)
          and (jwm.job_id is null
               or (jwm.job_id <> all($excluded_jobs)
                   and coalesce(rwmpj.count, 0)
                       < coalesce((rc.data -> 'work_manifests'
                                   ->> 'concurrent_runs')::double precision,
                                  10)))
)
select wm.id, nwm.compute_node, nwm.job_id
from work_manifests as wm
inner join next_work_manifests as nwm on nwm.id = wm.id
where wm.state = 'queued'
order by nwm.priority, nwm.created_at, nwm.id
limit 1
for update of wm skip locked

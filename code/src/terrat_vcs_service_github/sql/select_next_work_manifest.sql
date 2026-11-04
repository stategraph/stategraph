with
wms as (
    select
        wm.id as id,
        wm.created_at as created_at,
        wm.base_sha as base_sha,
        wm.sha as sha,
        wm.pull_request as pull_request,
        grm.repository_id as repository,
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
    inner join github_repositories_map as grm
        on grm.core_id = wm.repo
    inner join github_installation_repositories as gir
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
                         from github_repositories_map
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
    inner join github_repositories_map as grm
        on grm.core_id = wm.repo
    inner join github_installation_repositories as gir
        on gir.id = grm.repository_id
    inner join github_installations_map as gim
        on gim.installation_id = gir.installation_id
    left join repo_configs as rc
        on rc.kind = 'derived'
        and rc.installation = gim.core_id
        and rc.repo = wm.repo
        and rc.branch = wm.branch
        and rc.sha = wm.sha
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
-- The filter belongs here, and not in the final select, because this is where
-- row_number() ranks a repository's queued work manifests and the final select
-- takes rn = 1.  Such a work manifest is still 'queued', so it can rank first.
-- A filter in the final select would then return no row at all, and the
-- dispatcher would stop dispatching for that repository until the running node
-- finished.
--
-- A work manifest with no compute node is one made before the phase that makes
-- a node with each work manifest.  It keeps the old path.
--
-- Neither join can multiply rows: compute_node_work has a unique index on
-- work_manifest, and compute_nodes joins on its primary key.  Every work
-- manifest therefore still contributes one row, and the ranking of the others
-- does not move.
--
-- $work_manifest_id gives the query a second mode.  When it is null the query
-- answers the dispatcher: which work manifest starts the next action run.  When
-- it is set the query answers the poll of a compute node: may this one work
-- manifest run now.  The two modes share every rule above, which is the point.
-- A rule written twice would drift, and the rules here decide whether two
-- applies can touch one dirspace at the same time.
--
-- The second mode drops two conditions of the first, and only those two.  It
-- does not rank, because it asks about one work manifest and not about the next
-- one of a repository.  It does not ask the state of the compute node, because
-- the node that asks is running by definition.
next_work_manifests as (
    select
        wms.id,
        cn.id as compute_node,
        row_number() over (partition by wms.repository order by wms.priority, wms.created_at) as rn
    from wms
    left join rejected_work_manifests as rwm on rwm.id = wms.id
    left join compute_node_work as cnw on cnw.work_manifest = wms.id
    left join compute_nodes as cn on cn.id = cnw.compute_node
    where wms.state = 'queued'
          and rwm.id is null
          and ($work_manifest_id is not null
               or cn.id is null
               or cn.state = 'queued')
          and ($work_manifest_id is null or wms.id = $work_manifest_id)
)
select wm.id, nwm.compute_node from work_manifests as wm
inner join next_work_manifests as nwm on nwm.id = wm.id
left join flow_states
  on flow_states.id = wm.id
where ($work_manifest_id is not null or nwm.rn = 1) and wm.state = 'queued' and ((flow_states.id is null and $new_age) or (flow_states.id is not null and not $new_age))
for update of wm skip locked
limit 1

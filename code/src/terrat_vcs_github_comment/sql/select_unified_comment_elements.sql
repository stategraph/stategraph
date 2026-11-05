-- Recompute the state of every dirspace of the pull request that the given
-- work manifest belongs to, at the pull request's current sha.  The counts are
-- extracted from the plan output summary line when present.
with pr as (
    select
        gpr.repository,
        gpr.pull_number,
        gpr.base_sha,
        gpr.sha,
        gpr.merged_sha,
        gpr.state,
        grm.core_id as repo_core_id
    from github_work_manifests as gwm
    inner join github_pull_requests as gpr
        on gpr.repository = gwm.repository and gpr.pull_number = gwm.pull_number
    inner join github_repositories_map as grm
        on grm.repository_id = gpr.repository
    where gwm.id = $work_manifest
),
-- In the case that the pull request being evaluated here is merged, work
-- manifests run against the sha of the most recently merged pull request, so
-- accept that sha as well.
latest_merged_pull_request as (
    select gpr.repository, gpr.merged_sha
    from github_pull_requests as gpr
    inner join pr on pr.repository = gpr.repository
    where gpr.state = 'merged'
    order by gpr.merged_at desc
    limit 1
),
-- The states that the intra-PR hash rules decided for the head (RFD 2356).  A run
-- on an older commit can still count for the head, and only these rows know it.
summaries as (
    select s.path, s.workspace, s.state, s.updated_at, s.work_manifest
    from github_pull_request_dirspace_summaries as s
    inner join pr
        on pr.repository = s.repository and pr.pull_number = s.pull_number and pr.sha = s.sha
),
-- The dirspaces of a new head are only known once its tree is built, but the
-- states of the dirspaces of the pull request are known before.
current_dirspaces as (
    select cd.path, cd.workspace
    from change_dirspaces as cd
    inner join pr
        on pr.repo_core_id = cd.repo and pr.base_sha = cd.base_sha
    left join latest_merged_pull_request as lmpr
        on lmpr.repository = pr.repository
    where pr.sha = cd.sha
          or pr.merged_sha = cd.sha
          or (pr.state = 'merged' and cd.sha = lmpr.merged_sha)
    union
    select path, workspace
    from summaries
),
-- Every run of the pull request.  [on_head] is a run on the head of the pull
-- request after the latest unlock, which is the only kind of run the state of a
-- dirspace is read from when no stored state decides it.  A run before the
-- unlock does not count, but a stored state still shows its plan: an unlock
-- makes the stored states stale, and the user sees what the runs did.
pr_all_work_manifests as (
    select
        gwm.id,
        gwm.run_type,
        gwm.state,
        gwm.created_at,
        gwm.completed_at,
        (pr.base_sha = gwm.base_sha
         and (pr.sha = gwm.sha
              or pr.merged_sha = gwm.sha
              or (pr.state = 'merged' and gwm.sha = lmpr.merged_sha))
         and (lu.unlocked_at is null or lu.unlocked_at < gwm.created_at)) as on_head
    from github_work_manifests as gwm
    inner join pr
        on pr.repository = gwm.repository
           and pr.pull_number = gwm.pull_number
    left join latest_merged_pull_request as lmpr
        on lmpr.repository = pr.repository
    left join github_pull_request_latest_unlocks as lu
        on lu.repository = gwm.repository and lu.pull_number = gwm.pull_number
    where gwm.run_type in ('plan', 'autoplan', 'apply', 'autoapply', 'unsafe-apply')
),
pr_work_manifests as (
    select id, run_type, state, created_at
    from pr_all_work_manifests
    where on_head
),
run_results as (
    select
        wmr.path,
        wmr.workspace,
        wmr.success,
        wm.id as work_manifest,
        wm.created_at,
        wm.completed_at,
        wm.on_head,
        (wm.run_type in ('apply', 'autoapply', 'unsafe-apply')) as is_apply
    from pr_all_work_manifests as wm
    inner join work_manifest_results as wmr
        on wmr.work_manifest = wm.id
),
-- The newest plan and the newest apply of each dirspace: [on_head] only those
-- on the head, and [any] those on any commit of the pull request.
latest_runs as (
    select
        path,
        workspace,
        success,
        work_manifest,
        created_at,
        completed_at,
        is_apply,
        on_head,
        row_number() over (partition by path, workspace, is_apply
                           order by created_at desc) as rn_any,
        row_number() over (partition by path, workspace, is_apply, on_head
                           order by created_at desc) as rn_on_head,
        row_number() over (partition by path, workspace
                           order by created_at desc) as rn_latest
    from run_results
),
latest_plans as (
    select path, workspace, success, work_manifest, completed_at
    from latest_runs
    where not is_apply and on_head and rn_on_head = 1
),
latest_applies as (
    select path, workspace, success, work_manifest, completed_at
    from latest_runs
    where is_apply and on_head and rn_on_head = 1
),
latest_plans_any as (
    select path, workspace, success, work_manifest
    from latest_runs
    where not is_apply and rn_any = 1
),
latest_applies_any as (
    select path, workspace, success, work_manifest
    from latest_runs
    where is_apply and rn_any = 1
),
-- The newest plan or apply of each dirspace on any commit of the pull request.
latest_any as (
    select path, workspace, work_manifest
    from latest_runs
    where rn_latest = 1
),
-- A dirspace with a work manifest in flight, and whether one of those is an
-- apply: an apply in flight is a different state to the reader than a plan in
-- flight, because the plan it applies is already reported.  Aggregated rather
-- than distinct on both columns, so a dirspace with a queued plan AND a queued
-- apply stays one row and does not duplicate the element it joins to.
active_dirspaces as (
    select
        wmd.path,
        wmd.workspace,
        bool_or(wm.run_type in ('apply', 'autoapply', 'unsafe-apply')) as apply
    from pr_work_manifests as wm
    inner join work_manifest_dirspaceflows as wmd
        on wmd.work_manifest = wm.id
    where wm.state in ('queued', 'running')
    group by wmd.path, wmd.workspace
),
aborted_dirspaces as (
    select distinct wmd.path, wmd.workspace
    from pr_work_manifests as wm
    inner join work_manifest_dirspaceflows as wmd
        on wmd.work_manifest = wm.id
    where wm.state = 'aborted'
      and not exists (select 1
                      from work_manifest_results as wmr
                      where wmr.work_manifest = wm.id)
),
elements as (
    select
        cd.path,
        cd.workspace,
        lp.success as head_plan_success,
        lp.work_manifest as head_plan_work_manifest,
        la.success as head_apply_success,
        la.work_manifest as head_apply_work_manifest,
        lpa.success as any_plan_success,
        lpa.work_manifest as any_plan_work_manifest,
        laa.success as any_apply_success,
        laa.work_manifest as any_apply_work_manifest,
        lra.work_manifest as latest_work_manifest,
        (ad.path is not null) as active,
        coalesce(ad.apply, false) as active_apply,
        (ab.path is not null) as aborted,
        -- A run on the head that completed after the stored state decides the
        -- state instead.  The run whose result stored the state completes after
        -- it, thus it does not count.
        (case
           when coalesce(
                  greatest(
                    case when lp.work_manifest is distinct from s.work_manifest
                      then lp.completed_at end,
                    case when la.work_manifest is distinct from s.work_manifest
                      then la.completed_at end),
                  '-infinity') <= s.updated_at
             then s.state
         end) as summary_state
    from current_dirspaces as cd
    left join latest_plans as lp
        on lp.path = cd.path and lp.workspace = cd.workspace
    left join latest_applies as la
        on la.path = cd.path and la.workspace = cd.workspace
    left join latest_plans_any as lpa
        on lpa.path = cd.path and lpa.workspace = cd.workspace
    left join latest_applies_any as laa
        on laa.path = cd.path and laa.workspace = cd.workspace
    left join latest_any as lra
        on lra.path = cd.path and lra.workspace = cd.workspace
    left join active_dirspaces as ad
        on ad.path = cd.path and ad.workspace = cd.workspace
    left join aborted_dirspaces as ab
        on ab.path = cd.path and ab.workspace = cd.workspace
    left join summaries as s
        on s.path = cd.path and s.workspace = cd.workspace
),
-- The runs whose data the comment shows: the runs on the head, or, when the
-- stored state decides, the newest runs on any commit, which are the runs that
-- state counts.
chosen as (
    select
        e.path,
        e.workspace,
        (case when e.summary_state is null then e.head_plan_success
              else e.any_plan_success end) as plan_success,
        (case when e.summary_state is null then e.head_plan_work_manifest
              else e.any_plan_work_manifest end) as plan_work_manifest,
        (case when e.summary_state is null then e.head_apply_success
              else e.any_apply_success end) as apply_success,
        (case when e.summary_state is null then e.head_apply_work_manifest
              else e.any_apply_work_manifest end) as apply_work_manifest,
        e.latest_work_manifest,
        e.active,
        e.active_apply,
        e.aborted,
        e.summary_state
    from elements as e
)
select
    c.path,
    c.workspace,
    c.plan_success,
    -- The plans row is deleted once an apply fetches the plan, so fall back to
    -- the plan step output which is retained forever.
    coalesce(p.has_changes, (po.payload->>'has_changes')::boolean) as plan_has_changes,
    c.plan_work_manifest,
    -- Exact resource-change counts, computed by the runner from
    -- `terraform show -json`.  No text parsing: when a runner or engine does
    -- not emit them the columns are null (rendered as "-") rather than guessed.
    (po.payload->'resource_summary'->>'created')::bigint as created,
    (po.payload->'resource_summary'->>'updated')::bigint as updated,
    (po.payload->'resource_summary'->>'deleted')::bigint as deleted,
    (po.payload->'resource_summary'->>'replaced')::bigint as replaced,
    (po.payload->'resource_summary'->>'imported')::bigint as imported,
    -- Inline output details: rendered only when the run's summary config enabled them
    -- (output_details.enabled); the renderer's tier/fit machinery bounds the size.
    coalesce(po.payload->>'plan', po.payload->>'text') as plan_output,
    c.apply_success,
    c.apply_work_manifest,
    c.latest_work_manifest,
    c.active,
    c.active_apply,
    c.aborted,
    c.summary_state
from chosen as c
left join plans as p
    on p.work_manifest = c.plan_work_manifest and p.path = c.path and p.workspace = c.workspace
left join lateral (
    select wso.payload
    from workflow_step_outputs as wso
    where wso.work_manifest = c.plan_work_manifest
      and wso.scope->>'type' = 'dirspace'
      and wso.scope->>'dir' = c.path
      and wso.scope->>'workspace' = c.workspace
      and wso.step in ('tf/plan', 'pulumi/plan', 'custom/plan', 'fly/plan', 'stategraph/plan')
    order by wso.idx desc
    limit 1
) as po on true
order by c.path, c.workspace

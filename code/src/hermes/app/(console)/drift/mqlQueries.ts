import { MQL_MAX_LIMIT, asText } from "@/lib/mql/providers";
import { sqlLiteral } from "@/lib/mql/escape";
import type { VcsProvider } from "@/lib/vcs/links";
import { DRIFT_APPLY_RUN_TYPES, DRIFT_PLAN_RUN_TYPES, type DriftRow } from "@/lib/drift/state";

export const DRIFT_CAP = Math.min(1000, MQL_MAX_LIMIT);
/** Schedules listed per provider; the "Schedules" card counts them all. */
export const SCHEDULES_CAP = Math.min(200, MQL_MAX_LIMIT);

export type DriftStepKind = "plan" | "apply";

/**
 * Step name AND run type must agree. An apply workflow may carry a plan op
 * (`[init, plan, apply]` is a common reconcile shape), and its `%/plan` step
 * output is neither a drift check nor may its success stand in for the
 * apply's — the fold keys on run_type, so the rows must be scoped the same way.
 */
function driftStepPredicate(kind: DriftStepKind): string {
  const runTypes = kind === "plan" ? DRIFT_PLAN_RUN_TYPES : DRIFT_APPLY_RUN_TYPES;
  return `wso.step like ${sqlLiteral(`%/${kind}`)} and wm.run_type in (${runTypes.map(sqlLiteral).join(", ")})`;
}

export interface ScheduleRow {
  name: string;
  cron: string;
  reconcile: boolean;
  tagQuery: string;
  lastTried: string;
  provider: VcsProvider;
  owner: string;
  repoName: string;
}

/**
 * Per-dirspace drift step rows: drift-kind work manifests joined to their
 * workflow_step_outputs, scoped to the plan (check) or apply (reconcile)
 * step. `has_changes` is pulled from the plan payload; `success` from the step.
 */
export function driftStepQuery(provider: VcsProvider, kind: DriftStepKind): string {
  return (
    `select wm.id as id, wm.repo_owner as repo_owner, wm.repo_name as repo_name, ` +
    `wm.environment as environment, wm.run_type as run_type, wm.created_at as created_at, ` +
    `(wso.scope ->> 'dir') as dir, (wso.scope ->> 'workspace') as workspace, ` +
    `(wso.payload ->> 'has_changes') as has_changes, wso.success as success ` +
    `from workflow_step_outputs as wso ` +
    `inner join ${provider}_work_manifests as wm on wm.id = wso.work_manifest ` +
    `where wm.run_kind = 'drift' and ${driftStepPredicate(kind)} ` +
    `order by wm.created_at desc limit ${DRIFT_CAP}`
  );
}

const schedulesFrom = (provider: VcsProvider): string =>
  `from drift_schedules as ds ` +
  `inner join ${provider}_repositories_map as rm on rm.core_id = ds.repo ` +
  `inner join ${provider}_installation_repositories as gir on gir.id = rm.repository_id`;

/** Drift schedules for this provider, joined to their repository. */
export function driftSchedulesQuery(provider: VcsProvider): string {
  return (
    `select ds.name as name, ds.schedule as schedule, ds.reconcile as reconcile, ` +
    `ds.tag_query as tag_query, ds.last_tried_at as last_tried_at, ` +
    `gir.owner as owner, gir.name as repo_name ` +
    `${schedulesFrom(provider)} order by ds.name limit ${SCHEDULES_CAP}`
  );
}

/** Schedule count per mode (one row per `reconcile` value), so the card is
 *  exact past SCHEDULES_CAP instead of measuring the listed rows. With an
 *  owner, only that owner's repositories count, as in the filtered list. */
export function driftScheduleCountQuery(provider: VcsProvider, owner?: string): string {
  return (
    `select ds.reconcile as reconcile, count(*) as c ${schedulesFrom(provider)}` +
    (owner ? ` where gir.owner = ${sqlLiteral(owner)}` : "") +
    ` group by ds.reconcile`
  );
}

/**
 * 30-day rollup metric, all at the dirspace grain (one workflow_step_output per
 * dirspace) so the three tiles are comparable. `since` is a caller-computed ISO
 * timestamp. checks = drift plan step-outputs; finds = those that found
 * changes; reconciles = successful drift apply step-outputs.
 */
export function driftMetricQuery(
  provider: VcsProvider,
  kind: "checks" | "finds" | "reconciles",
  since: string,
  owner?: string,
): string {
  const base =
    `from workflow_step_outputs as wso ` +
    `inner join ${provider}_work_manifests as wm on wm.id = wso.work_manifest ` +
    `where wm.run_kind = 'drift' and wm.created_at >= ${sqlLiteral(since)}` +
    (owner ? ` and wm.repo_owner = ${sqlLiteral(owner)}` : "");
  if (kind === "finds") {
    return (
      `select sum(((wso.payload ->> 'has_changes')::bool)::integer) as c ` +
      `${base} and ${driftStepPredicate("plan")}`
    );
  }
  if (kind === "reconciles") {
    return `select count(*) as c ${base} and ${driftStepPredicate("apply")} and wso.success = true`;
  }
  return `select count(*) as c ${base} and ${driftStepPredicate("plan")}`;
}

export interface PlanTarget {
  checkRunId: string;
  dir: string;
  workspace: string;
}

/**
 * The drift plan step output of each target dirspace, in one round trip: a
 * target is (check run, dir, workspace) — a drift run covers many dirspaces
 * under one work manifest, so the manifest alone would pull every dirspace's
 * plan text. The payload comes back whole so `countsFor` can read whichever
 * shape (plan / text / legacy summary) this row carries. Requires at least
 * one target.
 */
export function driftPlanPayloadsQuery(targets: PlanTarget[]): string {
  const one = (t: PlanTarget) =>
    `(wso.work_manifest = ${sqlLiteral(t.checkRunId)} and (wso.scope ->> 'dir') = ${sqlLiteral(t.dir)} ` +
    `and (wso.scope ->> 'workspace') = ${sqlLiteral(t.workspace)})`;
  return (
    `select wso.work_manifest as work_manifest, (wso.scope ->> 'dir') as dir, ` +
    `(wso.scope ->> 'workspace') as workspace, wso.payload as payload ` +
    `from workflow_step_outputs as wso ` +
    `where wso.step like '%/plan' and (${targets.map(one).join(" or ")}) limit ${targets.length}`
  );
}

export function mapDriftRow(provider: VcsProvider, raw: unknown): DriftRow {
  const o = raw as Record<string, unknown>;
  return {
    id: asText(o.id),
    provider,
    repoOwner: asText(o.repo_owner),
    repoName: asText(o.repo_name),
    environment: asText(o.environment),
    runType: asText(o.run_type),
    dir: asText(o.dir),
    workspace: asText(o.workspace),
    hasChanges: asText(o.has_changes) === "true",
    success: o.success === true,
    createdAt: asText(o.created_at),
  };
}

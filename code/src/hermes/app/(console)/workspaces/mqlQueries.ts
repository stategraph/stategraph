import { sqlLiteral } from "@/lib/mql/escape";
import { MQL_MAX_LIMIT, asNumber, asText } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";

export const WS_CAP = Math.min(1000, MQL_MAX_LIMIT);

/**
 * One row per (repo, dir, workspace): run count, last-run time, and the state,
 * run type and result of that last run.
 *
 * `runs` joins dirspaceflows to work manifests once; `latest` groups it, so
 * the count and the latest timestamp are exact past WS_CAP; the final join
 * back on (repo, dir, workspace, created_at = max) recovers the latest run of
 * every dirspace — a flat "order by created_at desc limit N" over raw rows
 * lets a few busy dirspaces crowd every other one out of its hint.
 *
 * The join-back deliberately targets the `runs` CTE, not the tables: these
 * are foreign tables, and a join whose inner side is a foreign scan turns
 * into one remote fetch per outer row as soon as the planner estimates the
 * outer side small (30 s+ on ~1000 dirspaces). Referenced twice, `runs` is
 * materialized, and everything after the first scan stays local. For the same
 * reason the run's dirspace result (`success`, null when no result row) is
 * joined inside `runs`; work_manifest_results is keyed on
 * (work_manifest, path, workspace), so the left join adds no rows and the run
 * count stays exact.
 *
 * `environment` is aggregated with max() rather than grouped on — a dirspace
 * is (repo, dir, workspace); folding environment into the key would split a
 * dirspace whose runs predate adding a per-workflow environment into two
 * rows sharing a React key with partial counts.
 */
export function workspacesQuery(provider: VcsProvider): string {
  return (
    `with runs as (select wm.repo_owner as repo_owner, wm.repo_name as repo_name, ` +
    `wmds.path as dir, wmds.workspace as workspace, wm.environment as environment, ` +
    `wm.created_at as created_at, wm.state as state, wm.run_type as run_type, ` +
    `wmr.success as success ` +
    `from work_manifest_dirspaceflows as wmds ` +
    `inner join ${provider}_work_manifests as wm on wm.id = wmds.work_manifest ` +
    `left join work_manifest_results as wmr on wmr.work_manifest = wmds.work_manifest ` +
    `and wmr.path = wmds.path and wmr.workspace = wmds.workspace), ` +
    `latest as (select repo_owner, repo_name, dir, workspace, max(environment) as environment, ` +
    `max(created_at) as last_run, count(*) as run_count ` +
    `from runs group by repo_owner, repo_name, dir, workspace) ` +
    `select latest.repo_owner as repo_owner, latest.repo_name as repo_name, latest.dir as dir, ` +
    `latest.workspace as workspace, latest.environment as environment, latest.last_run as last_run, ` +
    `latest.run_count as run_count, runs.state as state, runs.run_type as run_type, ` +
    `runs.success as success ` +
    `from latest ` +
    `inner join runs on runs.repo_owner = latest.repo_owner and runs.repo_name = latest.repo_name ` +
    `and runs.dir = latest.dir and runs.workspace = latest.workspace and runs.created_at = latest.last_run ` +
    `order by latest.last_run desc limit ${WS_CAP}`
  );
}

/**
 * Locks, scoped to their repository. dirspace_pull_request_locks carries no repo
 * column, so a bare (path, workspace) lock set marks the same dirspace locked in
 * EVERY repo. Join through the PR map to recover the owning repo.
 */
export function workspaceLocksQuery(provider: VcsProvider): string {
  return (
    `select gir.owner as owner, gir.name as name, l.path as path, l.workspace as workspace ` +
    `from dirspace_pull_request_locks as l ` +
    `inner join ${provider}_pull_requests_map as pm on pm.core_id = l.pull_request ` +
    `inner join ${provider}_installation_repositories as gir on gir.id = pm.repository_id ` +
    `limit ${WS_CAP}`
  );
}

/**
 * Whether one dirspace of one repository is locked — the single-row form of
 * {@link workspaceLocksQuery}, with the same repo scoping: without the join a
 * lock on `path|workspace` in any repository would read as locked here.
 */
export function workspaceLockedQuery(
  provider: VcsProvider,
  owner: string,
  name: string,
  path: string,
  workspace: string,
): string {
  return (
    `select l.path as path from dirspace_pull_request_locks as l ` +
    `inner join ${provider}_pull_requests_map as pm on pm.core_id = l.pull_request ` +
    `inner join ${provider}_installation_repositories as gir on gir.id = pm.repository_id ` +
    `where l.path = ${sqlLiteral(path)} and l.workspace = ${sqlLiteral(workspace)} ` +
    `and gir.owner = ${sqlLiteral(owner)} and gir.name = ${sqlLiteral(name)} limit 1`
  );
}

export interface WsGroupRow {
  repoOwner: string;
  repoName: string;
  dir: string;
  workspace: string;
  environment: string;
  lastRun: string;
  runCount: number;
  /** Lifecycle state and run type of the latest run. */
  state: string;
  runType: string;
  /** The latest run's result for this dirspace; null when it has no result row. */
  success: boolean | null;
}

export function mapWsGroupRow(raw: unknown): WsGroupRow {
  const o = raw as Record<string, unknown>;
  return {
    repoOwner: asText(o.repo_owner),
    repoName: asText(o.repo_name),
    dir: asText(o.dir),
    workspace: asText(o.workspace),
    environment: asText(o.environment),
    lastRun: asText(o.last_run),
    runCount: asNumber(o.run_count),
    state: asText(o.state),
    runType: asText(o.run_type),
    success: typeof o.success === "boolean" ? o.success : null,
  };
}

/** Repo-scoped lock key: owner/name|path|workspace. */
export function lockKey(owner: string, name: string, path: string, workspace: string): string {
  return `${owner}/${name}|${path}|${workspace}`;
}

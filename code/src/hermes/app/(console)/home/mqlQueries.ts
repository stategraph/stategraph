// MQL queries for the home dashboard.
//
// The Tenant Overview is served by TWO MQL queries so the page can paint the
// cheap scalar widgets before the expensive graph analytics finish:
//
//   `homeScalarsQuery`        — plain counts + density input + the single
//                               top-resource-type / largest-module facts.
//                               No `unnest`, no anti-joins; runs in well under
//                               a second and unblocks first paint.
//   `homeGraphAnalyticsQuery` — the whole-estate graph analytics (orphan
//                               detection via anti-joins over
//                               `unnest(dependencies)`, dependency hotspot,
//                               root/leaf counts, provider/resource-type
//                               distributions). Fetched separately so it
//                               streams in after the scalars render.
//
// IMPORTANT: All table references use comma-separated FROM with WHERE instead
// of INNER JOIN. This is required because MQL wraps user queries inside
// `q AS ({{q}})` with outer CTEs for tenant-scoped tables. Comma-separated
// FROM correctly resolves outer CTE references, while INNER JOIN can fail with
// "missing FROM-clause entry" errors.
//
// For anti-join (LEFT JOIN ... WHERE IS NULL) patterns, and for the final
// cross join, we only ever LEFT JOIN against a single CTE.

import type { VcsProvider } from "@/lib/vcs/links";
import { sqlLiteral } from "@/lib/mql/escape";
import { asText } from "@/lib/mql/providers";

function tsCte(stateId?: string): string {
  if (stateId) {
    return `ts as (select id from states where deleted_at is null and id = '${stateId}')`;
  }
  return 'ts as (select id from states where deleted_at is null)';
}

// ---------------------------------------------------------------------------
// Result row types
// ---------------------------------------------------------------------------

export interface OrphanedByStateRow {
  state_name: string;
  c: number;
}

export interface OrphanedTopRow {
  address: string;
  state_name: string;
}

export interface ProviderDistributionRow {
  provider: string;
  c: number;
}

export interface ResourceTypeDistributionRow {
  type: string;
  c: number;
}

/**
 * The single row returned by `homeScalarsQuery` — every widget that needs
 * only cheap counts or a single top-N fact. Drives Control Plane Status and
 * the Hero Metrics strip, which paint before the analytics query returns.
 */
export interface HomeScalarsRow {
  total_states: number;
  total_resources: number;
  total_instances: number;
  total_edges: number;
  total_providers: number;
  total_modules: number;
  top_resource_type: string;
  top_resource_type_count: number;
  largest_module: string;
  largest_module_count: number;
}

/**
 * The single row returned by `homeGraphAnalyticsQuery`. Scalar columns are
 * plain counts/names; the four list columns are JSON arrays produced by
 * `json_agg` and are `null` when the aggregate ran over zero rows.
 */
export interface HomeGraphAnalyticsRow {
  graph_roots: number;
  graph_leaves: number;
  orphaned_count: number;
  most_deployed_module: string;
  most_deployed_module_count: number;
  dependency_hotspot: string;
  dependency_hotspot_count: number;
  orphaned_by_state: OrphanedByStateRow[] | null;
  orphaned_top: OrphanedTopRow[] | null;
  provider_distribution: ProviderDistributionRow[] | null;
  resource_type_distribution: ResourceTypeDistributionRow[] | null;
}

// ---------------------------------------------------------------------------
// Query builders
// ---------------------------------------------------------------------------

/**
 * The cheap half of the home dashboard: counts, density input, and the single
 * top-resource-type / largest-module facts. Returns exactly one row shaped
 * like `HomeScalarsRow`. Deliberately avoids `unnest(dependencies)` and
 * anti-joins so it stays sub-second and can render before the analytics land.
 */
export function homeScalarsQuery(stateId?: string): string {
  return `with
${tsCte(stateId)},
cnt_s as (select count(*) as c from ts),
cnt_r as (select count(*) as c from resources, ts where resources.state_id = ts.id),
cnt_i as (select count(*) as c from instances, ts where instances.state_id = ts.id),
edges as (select coalesce(sum(array_length(dependencies, 1::integer)), 0) as c
  from instances, ts where instances.state_id = ts.id),
dp as (select providers.name from providers, ts
  where providers.state_id = ts.id group by providers.name),
cnt_p as (select count(*) as c from dp),
dm as (select resources.module from resources, ts
  where resources.state_id = ts.id and resources.module is not null
  group by resources.module),
cnt_m as (select count(*) as c from dm),
top_rt as (select resources.type, count(*) as c from resources, ts
  where resources.state_id = ts.id
  group by resources.type order by c desc limit 1),
largest_mod as (select resources.module, count(*) as c from resources, ts
  where resources.state_id = ts.id and resources.module is not null
  group by resources.module order by c desc limit 1)
select
  cnt_s.c as total_states,
  cnt_r.c as total_resources,
  cnt_i.c as total_instances,
  edges.c as total_edges,
  cnt_p.c as total_providers,
  cnt_m.c as total_modules,
  coalesce(top_rt.type, '') as top_resource_type,
  coalesce(top_rt.c, 0) as top_resource_type_count,
  coalesce(largest_mod.module, '') as largest_module,
  coalesce(largest_mod.c, 0) as largest_module_count
from cnt_s, cnt_r, cnt_i, edges, cnt_p, cnt_m
left join top_rt on true
left join largest_mod on true`;
}

/**
 * The expensive half of the home dashboard: whole-estate graph analytics
 * (root/leaf counts, orphan detection, dependency hotspot, most-deployed
 * module, provider/resource-type distributions). Returns exactly one row
 * shaped like `HomeGraphAnalyticsRow`; the four list widgets arrive as JSON
 * arrays. Fetched separately so it streams in after the scalars paint.
 */
export function homeGraphAnalyticsQuery(stateId?: string): string {
  return `with
${tsCte(stateId)},
graph_roots as (select count(*) as c from instances, ts
  where instances.state_id = ts.id
  and array_length(dependencies, 1::integer) is null),
all_deps as (select dep as address from instances, ts, unnest(dependencies) as dep
  where instances.state_id = ts.id group by dep),
inst_ts as (select instances.address from instances, ts where instances.state_id = ts.id),
graph_leaves as (select count(*) as c from inst_ts
  left join all_deps on all_deps.address = inst_ts.address
  where all_deps.address is null),
inst_base as (select instances.address, states.name as state_name
  from instances, ts, states, resources
  where instances.state_id = ts.id
  and states.id = instances.state_id
  and resources.state_id = instances.state_id
  and resources.address = instances.resource_address
  and resources.module is null
  and (array_length(instances.dependencies, 1::integer) is null
    or array_length(instances.dependencies, 1::integer) <= 1)),
orphaned as (select count(*) as c from inst_base
  left join all_deps on all_deps.address = inst_base.address
  where all_deps.address is null),
inst_mod as (select resources.module, instances.address
  from resources, ts, instances
  where resources.state_id = ts.id
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
  and resources.module is not null
  group by resources.module, instances.address),
most_deployed_mod as (select inst_mod.module, count(*) as c from inst_mod
  group by inst_mod.module order by c desc limit 1),
dep_hotspot as (select dep as address, count(*) as c
  from instances, ts, unnest(dependencies) as dep
  where instances.state_id = ts.id
  group by dep order by c desc limit 1),
orphaned_by_state_rows as (select inst_base.state_name, count(*) as c from inst_base
  left join all_deps on all_deps.address = inst_base.address
  where all_deps.address is null
  group by inst_base.state_name order by c desc, inst_base.state_name limit 100),
orphaned_by_state_j as (select json_agg(json_build_object(
  'state_name', orphaned_by_state_rows.state_name,
  'c', orphaned_by_state_rows.c)) as j from orphaned_by_state_rows),
orphaned_top_rows as (select inst_base.address, inst_base.state_name from inst_base
  left join all_deps on all_deps.address = inst_base.address
  where all_deps.address is null
  order by inst_base.state_name, inst_base.address limit 10),
orphaned_top_j as (select json_agg(json_build_object(
  'address', orphaned_top_rows.address,
  'state_name', orphaned_top_rows.state_name)) as j from orphaned_top_rows),
provider_dist_rows as (select providers.name as provider, count(*) as c
  from providers, ts, resources, instances
  where providers.state_id = ts.id
  and resources.state_id = providers.state_id
  and resources.provider = providers.name
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
  group by providers.name order by c desc limit 100),
provider_dist_j as (select json_agg(json_build_object(
  'provider', provider_dist_rows.provider,
  'c', provider_dist_rows.c)) as j from provider_dist_rows),
rt_dist_rows as (select resources.type, count(*) as c
  from resources, ts, instances
  where resources.state_id = ts.id
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
  group by resources.type order by c desc limit 100),
rt_dist_j as (select json_agg(json_build_object(
  'type', rt_dist_rows.type,
  'c', rt_dist_rows.c)) as j from rt_dist_rows)
select
  graph_roots.c as graph_roots,
  graph_leaves.c as graph_leaves,
  orphaned.c as orphaned_count,
  coalesce(most_deployed_mod.module, '') as most_deployed_module,
  coalesce(most_deployed_mod.c, 0) as most_deployed_module_count,
  coalesce(dep_hotspot.address, '') as dependency_hotspot,
  coalesce(dep_hotspot.c, 0) as dependency_hotspot_count,
  orphaned_by_state_j.j as orphaned_by_state,
  orphaned_top_j.j as orphaned_top,
  provider_dist_j.j as provider_distribution,
  rt_dist_j.j as resource_type_distribution
from graph_roots, graph_leaves, orphaned,
  orphaned_by_state_j, orphaned_top_j, provider_dist_j, rt_dist_j
left join most_deployed_mod on true
left join dep_hotspot on true`;
}

// ---------------------------------------------------------------------------
// Transaction metrics (Control Plane Status)
// ---------------------------------------------------------------------------

/**
 * The single row returned by `transactionMetricsQuery`.
 *
 * Computed entirely server-side over the FULL transaction set for the tenant,
 * instead of the old client-side computation over a 100-transaction window.
 */
export interface TransactionMetricsRow {
  active_count: number;
  active_tags: Record<string, unknown> | null;
  last_state: string | null;
  last_completed_at: string | null;
  recent_committed: number;
  recent_aborted: number;
  recent_failed: number;
  recent_total: number;
  impact_distinct: number;
  impact_logs: number;
}

/**
 * Every Control Plane Status card (active transactions, last outcome, recent
 * stability over the `cutoffIso` window, last-change blast radius) in one MQL
 * query, computed over the tenant's whole transaction set. Returns exactly one
 * row shaped like `TransactionMetricsRow`.
 */
export function transactionMetricsQuery(tenantId: string, cutoffIso: string): string {
  const tid = tenantId.replace(/'/g, "''");
  const cutoff = cutoffIso.replace(/'/g, "''");
  return `with
tx as (select transactions.id, transactions.state, transactions.created_at, transactions.completed_at, transactions.tags
  from transactions where transactions.tenant_id = '${tid}'),
active as (select count(*) as c from tx where tx.completed_at is null),
active_latest as (select tx.tags as tags from tx where tx.completed_at is null
  order by tx.created_at desc, tx.id limit 1),
last_outcome as (select tx.state as state, tx.completed_at as completed_at from tx
  where tx.completed_at is not null order by tx.completed_at desc, tx.id limit 1),
recent_committed as (select count(*) as c from tx where tx.created_at >= '${cutoff}' and tx.state = 'committed'),
recent_aborted as (select count(*) as c from tx where tx.created_at >= '${cutoff}' and tx.state = 'aborted'),
recent_failed as (select count(*) as c from tx where tx.created_at >= '${cutoff}' and tx.state = 'failed'),
recent_total as (select count(*) as c from tx where tx.created_at >= '${cutoff}'),
last_committed as (select tx.id as id from tx where tx.state = 'committed' and tx.completed_at is not null
  order by tx.completed_at desc, tx.id limit 1),
impact_logs as (select count(*) as c from transaction_logs, last_committed
  where transaction_logs.tx_id = last_committed.id),
impact_addrs0 as (select coalesce(jsonb_extract_path_text(transaction_logs.data, 'address'),
    jsonb_extract_path_text(transaction_logs.data, 'resource_address')) as addr
  from transaction_logs, last_committed
  where transaction_logs.tx_id = last_committed.id
    and transaction_logs.object_type in ('instance', 'resource')
    and coalesce(jsonb_extract_path_text(transaction_logs.data, 'address'),
      jsonb_extract_path_text(transaction_logs.data, 'resource_address')) is not null
  group by addr),
impact_addrs as (select count(*) as c from impact_addrs0)
select
  active.c as active_count,
  active_latest.tags as active_tags,
  last_outcome.state as last_state,
  last_outcome.completed_at as last_completed_at,
  recent_committed.c as recent_committed,
  recent_aborted.c as recent_aborted,
  recent_failed.c as recent_failed,
  recent_total.c as recent_total,
  impact_addrs.c as impact_distinct,
  impact_logs.c as impact_logs
from active, recent_committed, recent_aborted, recent_failed, recent_total, impact_addrs, impact_logs
left join active_latest on true
left join last_outcome on true`;
}

// ---------------------------------------------------------------------------
// Orchestration activity (home orchestration-first band, #1639). Provider-neutral:
// each is issued per provider and merged client-side.
// ---------------------------------------------------------------------------

export const RECENT_RUNS_CAP = 10;

/** Rows the home band shows. RECENT_RUNS_CAP must stay >= this: the global
 *  newest-N across providers is only guaranteed by each provider's own newest-N
 *  when every provider fetched at least N. */
export const RECENT_RUNS_SHOWN = 6;

/** Newest work-manifest runs, for the home activity band. */
export function recentRunsQuery(provider: VcsProvider): string {
  return (
    `select id, state, run_type, run_kind, created_at, repo_owner, repo_name, pull_number ` +
    `from ${provider}_work_manifests order by created_at desc limit ${RECENT_RUNS_CAP}`
  );
}

/** Minimal probe used by Home routing to keep tenants with orchestration
 *  history on Home even when they have no imported Stategraph state. */

/** A returned row proves activity. An empty, partially failed fanout cannot
 * prove absence, so callers retain the previous onboarding fallback. */
export function resolveWorkManifestPresence(
  rows: readonly unknown[],
  failedProviders: readonly VcsProvider[],
): boolean | null {
  if (rows.length > 0) return true;
  return failedProviders.length > 0 ? null : false;
}

/** Count of open pull requests. */
export function openPullRequestsQuery(provider: VcsProvider): string {
  return `select count(*) as c from ${provider}_pull_requests where state = 'open'`;
}

/** Count of runs since a caller-computed ISO bound (the 24h tile) — a true
 *  count, unlike the display list which is capped. */
export function runsSinceCountQuery(provider: VcsProvider, since: string): string {
  return `select count(*) as c from ${provider}_work_manifests where created_at >= ${sqlLiteral(since)}`;
}

export interface RunRow {
  provider: VcsProvider;
  id: string;
  state: string;
  runType: string;
  runKind: string;
  createdAt: string;
  repo: string;
  pullNumber: string;
}

/** Epoch millis for an MQL timestamp; 0 for anything unparseable, which sorts
 *  such a row to the bottom rather than poisoning the comparison with NaN. */
const ts = (iso: string): number => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : 0;
};

/**
 * Merge each provider's newest-first page into one newest-first list and take
 * the top `shown`. MQL has no cross-table union, so the fan-out is per provider
 * and the global ordering can only be recovered here. Stable: runs with the
 * same timestamp keep the provider order they arrived in.
 */
export function mergeRecentRuns(perProvider: RunRow[][], shown: number): RunRow[] {
  return perProvider
    .flat()
    .sort((a, b) => ts(b.createdAt) - ts(a.createdAt))
    .slice(0, shown);
}

export function mapRunRow(provider: VcsProvider, raw: unknown): RunRow {
  const o = raw as Record<string, unknown>;
  const owner = asText(o.repo_owner);
  const name = asText(o.repo_name);
  return {
    provider,
    id: asText(o.id),
    state: asText(o.state),
    runType: asText(o.run_type),
    runKind: asText(o.run_kind),
    createdAt: asText(o.created_at),
    // "" rather than a bare "/" when the metadata is missing: work manifests
    // older than these columns carry NULL on both sides, and the caller renders
    // an em dash for the empty string the way the Runs table does.
    repo: owner && name ? `${owner}/${name}` : "",
    pullNumber: asText(o.pull_number),
  };
}

/** The `workflow_step_outputs` table is tenant-scoped and not twinned per
 *  provider, so this runs once. A returned row proves a plan ran through the
 *  Stategraph engine. */
export function stategraphEnginePresenceQuery(): string {
  return `select work_manifest from workflow_step_outputs where step = 'stategraph/plan' limit 1`;
}

// ---------------------------------------------------------------------------
// Hosted first-run routing
// ---------------------------------------------------------------------------

export type HostedHomeDestination = "home" | "setup";

export interface HostedHomeFacts {
  stateCount: number;
  hasWorkManifest: boolean;
  /** `null` means the installation list was not available to this session. */
  linkedInstallation: boolean | null;
}

/** Decide the destination only after the caller has applied the existing
 *  authenticated, hosted-mode, single-tenant, and states-loaded guards. */
export function resolveHostedHomeDestination({
  stateCount,
  hasWorkManifest,
  linkedInstallation,
}: HostedHomeFacts): HostedHomeDestination {
  if (stateCount > 0 || hasWorkManifest || linkedInstallation === true) return "home";
  return "setup";
}

// Home Dashboard data loader - Ultimate Infrastructure Overview
// Fetches all required API data and computes Control Plane insights

import {
  executeMQL,
  type StateSummary,
  type Module,
} from '@/lib/api/client';
import {
  computeGraphDensity,
  computeComplexityScore,
  type GraphDensity,
  type DependencyHotspot,
  type GraphStructure,
  type OrphanedCandidates,
  type ComplexityScore,
  type StateRecency,
  type ActiveTransactionsMetric,
  type LastTransactionOutcome,
  type RecentStability,
  type LastChangeImpact,
} from './metrics';
import {
  homeScalarsQuery,
  homeGraphAnalyticsQuery,
  transactionMetricsQuery,
  type HomeScalarsRow,
  type HomeGraphAnalyticsRow,
  type TransactionMetricsRow,
} from './mqlQueries';
import { formatRelativeTime } from '@/lib/utils/time';

// ============================================================================
// TYPES
// ============================================================================

export interface ResourceTypeData {
  type: string;
  instances: number;
}

export interface ProviderDistribution {
  provider: string;
  instances: number;
  percentage: number;
}

export interface HighSignalMetric {
  address: string;
  references: number;
}

/**
 * The cheap half of the dashboard, loaded first so it can paint before the
 * graph analytics finish. Backed by `homeScalarsQuery` plus the transaction
 * fetch. Drives Control Plane Status and the Hero Metrics strip.
 */
export interface HomeScalarsData {
  // Raw API data
  stateSummary: StateSummary;

  // Transaction metrics (Control Plane Status)
  activeTransactions: ActiveTransactionsMetric;
  lastTransactionOutcome: LastTransactionOutcome;
  recentStability: RecentStability;
  lastChangeImpact: LastChangeImpact;

  // Hero metrics (Infrastructure Overview)
  graphDensity: GraphDensity;

  // Cheap single-fact insights
  largestModule: Module | null;
  topResourceType: ResourceTypeData | null;
  complexityScore: ComplexityScore;

  // State metadata (optional)
  stateRecency?: StateRecency;
}

/**
 * The expensive half of the dashboard, loaded separately so it streams in
 * after the scalars paint. Backed by `homeGraphAnalyticsQuery`. Drives the
 * Risk row and the analytics cards in the Control Plane Insights grid.
 */
export interface HomeAnalyticsData {
  resourcesSummary: ResourceTypeData[];
  modules: Module[];

  // Risk metrics
  largestBlastRadius: HighSignalMetric | null;
  dependencyHotspot: DependencyHotspot | null;
  graphStructure: GraphStructure;

  // Composition
  providerDistribution: ProviderDistribution[];

  // Control Plane Insights (graph-derived)
  mostDeployedModule: Module | null;
  orphanedCandidates: OrphanedCandidates;
}

/**
 * The full dashboard payload — the union of the scalar and analytics halves.
 * Components that read across both halves accept this merged shape.
 */
export type HomeOverviewData = HomeScalarsData & HomeAnalyticsData;

// ============================================================================
// TENANT OVERVIEW LOADERS (All States aggregate via MQL)
// ============================================================================
//
// The dashboard is loaded in two independent phases (see #1072). The page
// fires both concurrently and paints each half as it resolves, so the cheap
// scalar widgets are not blocked behind the whole-estate graph analytics.

const num = (v: unknown): number => Number(v ?? 0);

/**
 * Load the cheap scalar half of the dashboard: `homeScalarsQuery` (counts +
 * density input + top-type / largest-module) together with the transaction
 * fetch, run concurrently. This is what unblocks first paint.
 */
export async function loadHomeScalars(tenantId: string, stateId?: string): Promise<HomeScalarsData> {
  // Recent-stability window for the transaction metrics (last 24h).
  const cutoffIso = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const [scalarsResult, metricsResult] = await Promise.all([
    executeMQL(homeScalarsQuery(stateId)),
    executeMQL(transactionMetricsQuery(tenantId, cutoffIso)),
  ]);

  const row = (scalarsResult.data[0] ?? {}) as Partial<HomeScalarsRow>;

  const stateSummary: StateSummary = {
    resources: num(row.total_resources),
    edges: num(row.total_edges),
    modules: num(row.total_modules),
    providers: num(row.total_providers),
    instances: num(row.total_instances),
  };

  // Transaction metrics — computed server-side over the FULL transaction set in
  // one MQL query, replacing the old client-side pass over a 100-tx window.
  const metricsRow = (metricsResult.data[0] ?? {}) as TransactionMetricsRow;
  const { activeTransactions, lastTransactionOutcome, recentStability, lastChangeImpact } =
    buildTransactionMetrics(metricsRow);

  // Hero metrics
  const graphDensity = computeGraphDensity(stateSummary);

  const largestModule: Module | null =
    row.largest_module
      ? { name: row.largest_module, resource_count: num(row.largest_module_count), instance_count: 0 }
      : null;

  const topResourceType: ResourceTypeData | null =
    row.top_resource_type
      ? { type: row.top_resource_type, instances: num(row.top_resource_type_count) }
      : null;

  const complexityScore = computeComplexityScore(stateSummary);

  return {
    stateSummary,
    activeTransactions,
    lastTransactionOutcome,
    recentStability,
    lastChangeImpact,
    graphDensity,
    largestModule,
    topResourceType,
    complexityScore,
  };
}

/**
 * Load the expensive graph-analytics half of the dashboard from
 * `homeGraphAnalyticsQuery`: one row covering the risk metrics, distributions,
 * most-deployed module, and orphan detection; the four list widgets arrive as
 * JSON arrays. Fetched separately so it streams in after the scalars paint.
 */
export async function loadHomeAnalytics(stateId?: string): Promise<HomeAnalyticsData> {
  const analyticsResult = await executeMQL(homeGraphAnalyticsQuery(stateId));

  const row = (analyticsResult.data[0] ?? {}) as Partial<HomeGraphAnalyticsRow>;

  const provDistRows = row.provider_distribution ?? [];
  const rtDistRows = row.resource_type_distribution ?? [];
  const orphByStateRows = row.orphaned_by_state ?? [];
  const orphTopRows = row.orphaned_top ?? [];

  const resourcesSummary: ResourceTypeData[] = rtDistRows
    .map(r => ({ type: r.type, instances: num(r.c) }))
    .sort((a, b) => b.instances - a.instances);

  const modules: Module[] = [];

  // Risk metrics from MQL
  const hotspotCount = num(row.dependency_hotspot_count);
  const dependencyHotspot: DependencyHotspot | null =
    row.dependency_hotspot && hotspotCount > 0
      ? { address: row.dependency_hotspot, inboundReferences: hotspotCount }
      : null;

  const largestBlastRadius: HighSignalMetric | null =
    dependencyHotspot
      ? { address: dependencyHotspot.address, references: dependencyHotspot.inboundReferences }
      : null;

  const graphStructure: GraphStructure = {
    roots: num(row.graph_roots),
    leaves: num(row.graph_leaves),
  };

  // Provider distribution
  const totalProvInstances = provDistRows.reduce((sum, r) => sum + num(r.c), 0);
  const providerDistribution: ProviderDistribution[] = provDistRows.map(r => ({
    provider: r.provider,
    instances: num(r.c),
    percentage: totalProvInstances > 0 ? (num(r.c) / totalProvInstances) * 100 : 0,
  }));

  const mostDeployedModule: Module | null =
    row.most_deployed_module
      ? {
          name: row.most_deployed_module,
          resource_count: 0,
          instance_count: num(row.most_deployed_module_count),
        }
      : null;

  const orphanedCandidates: OrphanedCandidates = {
    count: num(row.orphaned_count),
    addresses: orphTopRows.map(o => o.address),
    orphanedTop: orphTopRows.map(o => ({ address: o.address, stateName: o.state_name })),
    // Only show per-state breakdown in All States view (no stateId)
    byState: stateId ? undefined : orphByStateRows.map(o => ({ stateName: o.state_name, count: num(o.c) })),
  };

  return {
    resourcesSummary,
    modules,
    largestBlastRadius,
    dependencyHotspot,
    graphStructure,
    providerDistribution,
    mostDeployedModule,
    orphanedCandidates,
  };
}

// ============================================================================
// HELPERS
// ============================================================================

/**
 * Shape the single `transactionMetricsQuery` row into the four Control Plane
 * Status metrics. Server-side counts replace the old client-side computation,
 * so this is pure mapping — every field is null-safe against an empty row (a
 * tenant with no transactions yields all-zero/none metrics).
 */
function buildTransactionMetrics(row: TransactionMetricsRow): {
  activeTransactions: ActiveTransactionsMetric;
  lastTransactionOutcome: LastTransactionOutcome;
  recentStability: RecentStability;
  lastChangeImpact: LastChangeImpact;
} {
  // Active — sublabel derived from the latest in-progress tx's tags.
  let sublabel: string | null = null;
  const tags = row.active_tags;
  if (tags) {
    if (typeof tags.operation === 'string') sublabel = `${tags.operation} in progress`;
    else if (typeof tags.action === 'string') sublabel = `${tags.action} in progress`;
  }
  const activeTransactions: ActiveTransactionsMetric = {
    count: num(row.active_count),
    activeTransaction: null,
    sublabel,
  };

  // Last outcome — most recently completed transaction.
  const lastTransactionOutcome: LastTransactionOutcome = row.last_completed_at
    ? {
        state: row.last_state ?? 'none',
        relativeTime: formatRelativeTime(row.last_completed_at),
        transaction: null,
      }
    : { state: 'none', relativeTime: 'No transactions yet', transaction: null };

  // Recent stability — counts within the 24h window.
  const committedCount = num(row.recent_committed);
  const abortedCount = num(row.recent_aborted);
  const failedCount = num(row.recent_failed);
  const parts: string[] = [];
  if (committedCount > 0) parts.push(`${committedCount} committed`);
  if (failedCount > 0) parts.push(`${failedCount} failed`);
  if (abortedCount > 0) parts.push(`${abortedCount} aborted`);
  const recentStability: RecentStability = {
    committedCount,
    abortedCount,
    failedCount,
    totalCount: num(row.recent_total),
    windowHours: 24,
    summary: parts.length > 0 ? parts.join(', ') : 'No recent changes',
  };

  // Last change impact — distinct affected resources, falling back to log count.
  const impactDistinct = num(row.impact_distinct);
  const impactLogs = num(row.impact_logs);
  const lastChangeImpact: LastChangeImpact = {
    blastRadius: impactDistinct > 0 ? impactDistinct : impactLogs,
    transaction: null,
    hasData: impactLogs > 0,
  };

  return { activeTransactions, lastTransactionOutcome, recentStability, lastChangeImpact };
}

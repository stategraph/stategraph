// Infrastructure Overview Metrics Computation
// Pure utility functions for deriving Control Plane insights from Stategraph API data

import type { Instance, Module, StateSummary, Transaction, TransactionLog } from '@/lib/api/client';
import { formatRelativeTime } from '@/lib/utils/time';

// ============================================================================
// TYPES
// ============================================================================

export interface GraphDensity {
  value: number; // edges per resource
  edges: number;
  resources: number;
}

export interface DependencyHotspot {
  address: string;
  inboundReferences: number;
}

export interface GraphStructure {
  roots: number;
  leaves: number;
}

export interface OrphanedCandidates {
  count: number;
  addresses: string[];
  orphanedTop?: { address: string; stateName: string }[];
  byState?: { stateName: string; count: number }[];
}

export interface ComplexityScore {
  score: number; // 0-100
  breakdown: {
    resources: number;
    edges: number;
    modules: number;
  };
}

export interface StateRecency {
  lastUpdated: string; // ISO timestamp
  lastUpdatedAgo: string; // "2 hours ago"
  created: string; // ISO timestamp
  createdFormatted: string; // "2024-01-15"
}

// ============================================================================
// COMPUTATION FUNCTIONS
// ============================================================================

/**
 * Compute graph density: edges per resource
 * Higher density = more interconnected infrastructure
 */
export function computeGraphDensity(summary: StateSummary): GraphDensity {
  const { edges, resources } = summary;
  const value = resources > 0 ? edges / resources : 0;

  return {
    value: parseFloat(value.toFixed(2)),
    edges,
    resources,
  };
}

/**
 * Find the resource with the most inbound references (most depended-on)
 * This is computed by scanning all dependencies and counting references
 */
export function computeDependencyHotspot(
  instances: Instance[],
  maxSample = 5000
): DependencyHotspot | null {
  // For performance, cap analysis to first N instances if needed
  const sampled = instances.slice(0, maxSample);

  // Build inbound reference map
  const inboundMap = new Map<string, number>();

  // Initialize all addresses with 0
  sampled.forEach(instance => {
    inboundMap.set(instance.address, 0);
  });

  // Count inbound references
  sampled.forEach(instance => {
    if (instance.dependencies && Array.isArray(instance.dependencies)) {
      instance.dependencies.forEach(dep => {
        inboundMap.set(dep, (inboundMap.get(dep) || 0) + 1);
      });
    }
  });

  // Find max
  let maxAddress: string | null = null;
  let maxCount = 0;

  inboundMap.forEach((count, address) => {
    if (count > maxCount) {
      maxCount = count;
      maxAddress = address;
    }
  });

  if (!maxAddress || maxCount === 0) {
    return null;
  }

  return {
    address: maxAddress,
    inboundReferences: maxCount,
  };
}

/**
 * Compute graph structure: roots and leaves
 * Roots = no dependencies (entry points)
 * Leaves = not referenced by anyone (terminal nodes)
 */
export function computeGraphStructure(instances: Instance[]): GraphStructure {
  // Count roots (no dependencies)
  let roots = 0;
  instances.forEach(instance => {
    if (!instance.dependencies || instance.dependencies.length === 0) {
      roots++;
    }
  });

  // Count leaves (not referenced)
  const referenced = new Set<string>();
  instances.forEach(instance => {
    if (instance.dependencies && Array.isArray(instance.dependencies)) {
      instance.dependencies.forEach(dep => referenced.add(dep));
    }
  });

  let leaves = 0;
  instances.forEach(instance => {
    if (!referenced.has(instance.address)) {
      leaves++;
    }
  });

  return { roots, leaves };
}

/**
 * Find largest module by resource count
 */
export function findLargestModule(modules: Module[]): Module | null {
  if (modules.length === 0) return null;

  return modules.reduce((max, current) =>
    current.resource_count > max.resource_count ? current : max
  );
}

/**
 * Find most deployed module by instance count
 */
export function findMostDeployedModule(modules: Module[]): Module | null {
  if (modules.length === 0) return null;

  return modules.reduce((max, current) =>
    current.instance_count > max.instance_count ? current : max
  );
}

/**
 * Find orphaned candidates (heuristic)
 * These are leaf nodes with no module or very low connectivity
 */
export function findOrphanedCandidates(
  instances: Instance[],
  maxResults = 100
): OrphanedCandidates {
  // Build reference set
  const referenced = new Set<string>();
  instances.forEach(instance => {
    if (instance.dependencies && Array.isArray(instance.dependencies)) {
      instance.dependencies.forEach(dep => referenced.add(dep));
    }
  });

  // Find candidates: leaves with no module and no/few dependencies
  const candidates: string[] = [];

  instances.forEach(instance => {
    const isLeaf = !referenced.has(instance.address);
    const hasNoModule = !instance.module || instance.module === '';
    const hasLowDeps = !instance.dependencies || instance.dependencies.length <= 1;

    if (isLeaf && (hasNoModule || hasLowDeps)) {
      candidates.push(instance.address);
    }
  });

  return {
    count: candidates.length,
    addresses: candidates.slice(0, maxResults),
  };
}

/**
 * Compute complexity score (0-100)
 * Formula: min(100, round((resources + edges/2 + modules*3) / K))
 * K is chosen to give a nice spread for typical infrastructures
 */
export function computeComplexityScore(summary: StateSummary): ComplexityScore {
  const { resources, edges, modules } = summary;

  // Tuning constant - adjust based on typical infrastructure sizes
  // This gives: small infra (5-10 resources) ~10-20, medium (50) ~40-60, large (200+) ~80-100
  const K = 5;

  const rawScore = (resources + edges / 2 + modules * 3) / K;
  const score = Math.min(100, Math.round(rawScore));

  return {
    score,
    breakdown: {
      resources,
      edges,
      modules,
    },
  };
}

/**
 * Format state recency information
 * Uses shared formatRelativeTime helper for consistency
 */
export function computeStateRecency(state: { created_at: string; updated_at?: string }): StateRecency {
  const lastUpdatedTimestamp = state.updated_at || state.created_at;
  const created = new Date(state.created_at);

  // Use shared helper for human-readable relative time
  const lastUpdatedAgo = formatRelativeTime(lastUpdatedTimestamp);

  // Format created date as YYYY-MM-DD
  const createdFormatted = created.toISOString().split('T')[0];

  return {
    lastUpdated: lastUpdatedTimestamp,
    lastUpdatedAgo,
    created: state.created_at,
    createdFormatted,
  };
}

/**
 * Normalize provider string to friendly name
 * e.g. "provider[\"registry.terraform.io/hashicorp/aws\"]" -> "AWS"
 */
export function normalizeProviderName(provider: string): string {
  // Extract provider name from registry path
  const match = provider.match(/hashicorp\/(\w+)/i);
  if (match) {
    const name = match[1].toUpperCase();
    // Map common providers to friendly names
    const mapping: Record<string, string> = {
      'AWS': 'AWS',
      'AZURERM': 'Azure',
      'GOOGLE': 'GCP',
      'KUBERNETES': 'Kubernetes',
      'HELM': 'Helm',
      'GITHUB': 'GitHub',
      'GITLAB': 'GitLab',
      'DATADOG': 'Datadog',
      'CLOUDFLARE': 'Cloudflare',
      'RANDOM': 'Random',
      'NULL': 'Null',
      'LOCAL': 'Local',
      'EXTERNAL': 'External',
      'TERRAFORM': 'Terraform',
    };
    return mapping[name] || name;
  }

  return provider;
}

/**
 * Compute provider distribution from instances
 */
export function computeProviderDistribution(
  instances: Instance[]
): Array<{ provider: string; instances: number; percentage: number }> {
  const providerCounts = new Map<string, number>();

  instances.forEach(instance => {
    const normalized = normalizeProviderName(instance.provider);
    providerCounts.set(normalized, (providerCounts.get(normalized) || 0) + 1);
  });

  const total = instances.length;

  return Array.from(providerCounts.entries())
    .map(([provider, count]) => ({
      provider,
      instances: count,
      percentage: total > 0 ? (count / total) * 100 : 0,
    }))
    .sort((a, b) => b.instances - a.instances);
}

// ============================================================================
// TRANSACTION METRICS
// ============================================================================

export interface ActiveTransactionsMetric {
  count: number;
  activeTransaction: Transaction | null;
  sublabel: string | null; // e.g., "apply in progress"
}

export interface LastTransactionOutcome {
  state: string; // "committed", "aborted", "failed"
  relativeTime: string; // "3 minutes ago"
  transaction: Transaction | null;
}

export interface RecentStability {
  committedCount: number;
  abortedCount: number;
  failedCount: number;
  totalCount: number;
  windowHours: number; // e.g., 24
  summary: string; // e.g., "8 committed, 1 failed"
}

export interface LastChangeImpact {
  blastRadius: number; // number of nodes affected
  transaction: Transaction | null;
  hasData: boolean;
}

/**
 * Compute active transactions metric
 */
export function computeActiveTransactions(
  transactions: Transaction[]
): ActiveTransactionsMetric {
  const activeTransactions = transactions.filter(
    tx => tx.state === 'active' || tx.state === 'pending'
  );

  const count = activeTransactions.length;
  const activeTransaction = activeTransactions[0] || null;

  // Derive sublabel from transaction tags if available
  let sublabel: string | null = null;
  if (activeTransaction?.tags) {
    const tags = activeTransaction.tags as Record<string, unknown>;
    if (typeof tags.operation === 'string') {
      sublabel = `${tags.operation} in progress`;
    } else if (typeof tags.action === 'string') {
      sublabel = `${tags.action} in progress`;
    }
  }

  return {
    count,
    activeTransaction,
    sublabel,
  };
}

/**
 * Compute last transaction outcome
 * Only considers transactions with valid completed_at timestamps
 */
export function computeLastTransactionOutcome(
  transactions: Transaction[]
): LastTransactionOutcome {
  // Find most recent completed transaction with valid timestamp
  const completedTransactions = transactions
    .filter(tx => {
      // Must have completed_at field
      if (!tx.completed_at) return false;

      // Must be a valid date
      const date = new Date(tx.completed_at);
      if (isNaN(date.getTime())) return false;

      return true;
    })
    .sort((a, b) => {
      const timeA = new Date(a.completed_at!).getTime();
      const timeB = new Date(b.completed_at!).getTime();
      return timeB - timeA;
    });

  const lastTransaction = completedTransactions[0] || null;

  if (!lastTransaction) {
    return {
      state: 'none',
      relativeTime: 'No transactions yet',
      transaction: null,
    };
  }

  return {
    state: lastTransaction.state,
    relativeTime: formatRelativeTime(lastTransaction.completed_at!),
    transaction: lastTransaction,
  };
}

/**
 * Compute recent changes (last 24 hours by default)
 */
export function computeRecentStability(
  transactions: Transaction[],
  windowHours: number = 24
): RecentStability {
  const now = new Date();
  const windowStart = new Date(now.getTime() - windowHours * 60 * 60 * 1000);

  // Filter transactions within window
  const recentTransactions = transactions.filter(tx => {
    const createdAt = new Date(tx.created_at);
    return createdAt >= windowStart;
  });

  // Count by state
  let committedCount = 0;
  let abortedCount = 0;
  let failedCount = 0;

  recentTransactions.forEach(tx => {
    if (tx.state === 'committed') committedCount++;
    else if (tx.state === 'aborted') abortedCount++;
    else if (tx.state === 'failed' || tx.state === 'failed-committed')
      failedCount++;
  });

  const totalCount = recentTransactions.length;

  // Build summary string - literal counts only
  const parts: string[] = [];
  if (committedCount > 0) parts.push(`${committedCount} committed`);
  if (failedCount > 0) parts.push(`${failedCount} failed`);
  if (abortedCount > 0) parts.push(`${abortedCount} aborted`);

  const summary = parts.length > 0 ? parts.join(', ') : 'No recent changes';

  return {
    committedCount,
    abortedCount,
    failedCount,
    totalCount,
    windowHours,
    summary,
  };
}

/**
 * Compute last change impact from transaction logs
 */
export function computeLastChangeImpact(
  transactions: Transaction[],
  transactionLogs: Map<string, TransactionLog[]>
): LastChangeImpact {
  // Find most recent committed transaction
  const committedTransactions = transactions
    .filter(tx => tx.state === 'committed' && tx.completed_at)
    .sort((a, b) => {
      const timeA = new Date(a.completed_at!).getTime();
      const timeB = new Date(b.completed_at!).getTime();
      return timeB - timeA;
    });

  const lastCommittedTx = committedTransactions[0] || null;

  if (!lastCommittedTx) {
    return {
      blastRadius: 0,
      transaction: null,
      hasData: false,
    };
  }

  // Get logs for this transaction
  const logs = transactionLogs.get(lastCommittedTx.id) || [];

  // Count unique affected resources (instances)
  const affectedResources = new Set<string>();

  logs.forEach(log => {
    if (log.object_type === 'instance' || log.object_type === 'resource') {
      // Extract resource identifier from log data if available
      if (log.data && typeof log.data === 'object') {
        const data = log.data as Record<string, unknown>;
        if (typeof data.address === 'string') {
          affectedResources.add(data.address);
        } else if (typeof data.resource_address === 'string') {
          affectedResources.add(data.resource_address);
        }
      }
    }
  });

  // If no specific resources found, use log count as proxy
  const blastRadius = affectedResources.size > 0 ? affectedResources.size : logs.length;

  return {
    blastRadius,
    transaction: lastCommittedTx,
    hasData: logs.length > 0,
  };
}

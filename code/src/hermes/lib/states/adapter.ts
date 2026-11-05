// States data adapter - Maps API responses to UI data structures
// This layer transforms raw backend data into the shape required by the States table.

import type {
  State,
  StateSummary,
  Transaction,
} from "@/lib/api/client";

// ============================================================================
// Types
// ============================================================================

export type StateSource = "Terraform" | "OpenTofu" | "Imported";
export type StateStatus = "Healthy" | "Drift detected" | "Locked" | "Failed";
export type BlastRadiusSize = "Small" | "Medium" | "Large";

/**
 * Per-state aggregates + most-recent transaction, as produced by the states
 * overview MQL query (`app/(console)/states/mqlQueries.ts`). This is the raw
 * input the list table derives its presentational fields from; status, source,
 * and blast-radius sizing are computed client-side (they are not DB columns).
 */
export interface StateOverview {
  instances: number;
  edges: number;
  last_tx_created_at: string | null;
  last_tx_completed_at: string | null;
  last_tx_status: string | null;
}

export interface StateTableRow {
  id: string;
  name: string;
  workspace: string;
  groupId: string;
  resourceCount: number;
  lastTransaction: {
    type: string;
    relativeTime: string;
    timestamp: string;
  } | null;
  status: StateStatus;
  blastRadius: {
    size: BlastRadiusSize;
    count: number;
  };
  // Original data for detail view
  _raw: {
    state: State;
    overview?: StateOverview;
  };
}

export interface StateDetail {
  id: string;
  name: string;
  status: StateStatus;
  createdAt: string;
  importedAt?: string;
  source: StateSource;
  resourceCount: number;
  lastSuccessfulApply?: string;
  recentActivity: {
    type: string;
    timestamp: string;
    result: string;
  }[];
  context: {
    groupId: string;
    workspace: string;
  };
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Derive state source from state metadata.
 * In the absence of explicit source tracking, we use heuristics:
 * - States with updated_at are considered imported
 * - Otherwise, default to Terraform
 */
function deriveSource(state: State): StateSource {
  // This is a placeholder heuristic. In reality, you'd check:
  // - Tags or metadata indicating import
  // - OpenTofu-specific state format markers
  // - Explicit source field when backend adds it

  // For now: if state has specific tags or markers (future enhancement)
  // For demo purposes, we'll mark some as imported based on naming patterns
  if (state.name.toLowerCase().includes("import")) {
    return "Imported";
  }

  // Default to Terraform (most common case)
  return "Terraform";
}

/**
 * Derive state status from available data.
 * This is a placeholder - in a real implementation, you'd check:
 * - Active locks (from transaction sessions)
 * - Drift detection results
 * - Failed transaction states
 * - Health checks
 */
function deriveStatus(
  lastTxCreatedAt: string | null,
  lastTxCompletedAt: string | null
): StateStatus {
  // Placeholder logic - can be enhanced with real drift/lock/health data

  // Check if the most-recent transaction is still open (completed_at is null).
  if (lastTxCreatedAt && !lastTxCompletedAt) {
    const createdAt = new Date(lastTxCreatedAt).getTime();
    const now = Date.now();
    const hoursSinceCreated = (now - createdAt) / (1000 * 60 * 60);

    // If transaction has been open for more than 1 hour, consider it locked or failed
    if (hoursSinceCreated > 1) {
      return "Locked";
    }
  }

  // Default to healthy
  return "Healthy";
}

/**
 * Calculate blast radius size based on edge count.
 * Categorizes the impact scope into Small/Medium/Large.
 */
function calculateBlastRadius(
  edgeCount: number
): { size: BlastRadiusSize; count: number } {
  let size: BlastRadiusSize;
  if (edgeCount < 50) {
    size = "Small";
  } else if (edgeCount < 200) {
    size = "Medium";
  } else {
    size = "Large";
  }

  return { size, count: edgeCount };
}

/**
 * Format relative time for last transaction.
 * Converts timestamp to human-readable relative format (e.g., "2 hours ago")
 */
function formatRelativeTime(timestamp: string): string {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSecs = Math.floor(diffMs / 1000);
  const diffMins = Math.floor(diffSecs / 60);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSecs < 60) {
    return "Just now";
  } else if (diffMins < 60) {
    return `${diffMins} minute${diffMins !== 1 ? "s" : ""} ago`;
  } else if (diffHours < 24) {
    return `${diffHours} hour${diffHours !== 1 ? "s" : ""} ago`;
  } else if (diffDays < 30) {
    return `${diffDays} day${diffDays !== 1 ? "s" : ""} ago`;
  } else {
    return date.toLocaleDateString();
  }
}

/**
 * Get transaction type label.
 * Converts transaction state to human-readable type.
 */
function getTransactionType(completedAt: string | null | undefined): string {
  // We have no transaction_type field, so label by completion status.
  return completedAt ? "Apply" : "In Progress";
}

// ============================================================================
// Adapter Functions
// ============================================================================

/**
 * Transform State + optional metadata into StateTableRow format.
 * This is the primary adapter function for the States list table.
 */
export function stateToTableRow(
  state: State,
  overview?: StateOverview
): StateTableRow {
  const lastTxCreatedAt = overview?.last_tx_created_at ?? null;
  const lastTxCompletedAt = overview?.last_tx_completed_at ?? null;

  return {
    id: state.id,
    name: state.name,
    workspace: state.workspace || "default",
    groupId: state.group_id || "",
    resourceCount: Number(overview?.instances ?? 0),
    lastTransaction: lastTxCreatedAt
      ? {
          type: getTransactionType(lastTxCompletedAt),
          relativeTime: formatRelativeTime(lastTxCreatedAt),
          timestamp: lastTxCreatedAt,
        }
      : null,
    status: deriveStatus(lastTxCreatedAt, lastTxCompletedAt),
    blastRadius: calculateBlastRadius(Number(overview?.edges ?? 0)),
    _raw: {
      state,
      overview,
    },
  };
}

/**
 * Transform State + metadata into StateDetail format.
 * This is used for the State details page.
 */
export function stateToDetail(
  state: State,
  summary?: StateSummary,
  recentTxs?: Transaction[]
): StateDetail {
  const lastSuccessfulTx = recentTxs?.find((tx) => tx.completed_at);

  return {
    id: state.id,
    name: state.name,
    status: deriveStatus(
      recentTxs?.[0]?.created_at ?? null,
      recentTxs?.[0]?.completed_at ?? null
    ),
    createdAt: state.created_at,
    importedAt: state.updated_at,
    source: deriveSource(state),
    resourceCount: summary?.instances ?? 0,
    lastSuccessfulApply: lastSuccessfulTx?.completed_at,
    recentActivity:
      recentTxs?.slice(0, 5).map((tx) => ({
        type: getTransactionType(tx.completed_at),
        timestamp: tx.created_at,
        result: tx.completed_at ? "Success" : "In Progress",
      })) ?? [],
    context: {
      groupId: state.group_id,
      workspace: state.workspace,
    },
  };
}

/**
 * Sort table rows by a given column.
 */
export function sortTableRows(
  rows: StateTableRow[],
  sortBy: "name" | "resourceCount" | "lastTransaction",
  direction: "asc" | "desc"
): StateTableRow[] {
  const sorted = [...rows].sort((a, b) => {
    switch (sortBy) {
      case "name":
        return a.name.localeCompare(b.name);
      case "resourceCount":
        return a.resourceCount - b.resourceCount;
      case "lastTransaction": {
        const aTime = a.lastTransaction?.timestamp ?? "";
        const bTime = b.lastTransaction?.timestamp ?? "";
        return aTime.localeCompare(bTime);
      }
      default:
        return 0;
    }
  });

  return direction === "desc" ? sorted.reverse() : sorted;
}

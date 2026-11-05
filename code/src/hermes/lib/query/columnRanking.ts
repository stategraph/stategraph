/**
 * Column Ranking for Curated Table View (Stategraph-specific)
 *
 * Provides deterministic scoring to select the most useful columns
 * when displaying wide result sets (e.g. SELECT * queries).
 *
 * Based on actual Stategraph MQL schema tables:
 * - instances, resources, states, transactions, transaction_logs
 * - providers, outputs, check_results, check_entries
 */

export interface ColumnScore {
  column: string;
  score: number;
  reason: string;
}

/**
 * Score a column name based on Stategraph schema semantics.
 * Higher scores = more important to show by default.
 */
function scoreColumnName(column: string): { score: number; reason: string } {
  const lower = column.toLowerCase();

  // High priority identity columns (100-120 range)
  // instances.address, resources.address, resources.name, states.name
  if (lower === 'address') {
    return { score: 120, reason: 'resource address' };
  }
  if (lower === 'name') {
    return { score: 115, reason: 'resource name' };
  }
  if (lower === 'type') {
    return { score: 110, reason: 'resource type' };
  }

  // Graph-relevant columns (80-95 range)
  // resources.module, resources.provider, resources.mode, states.workspace
  if (lower === 'module') {
    return { score: 95, reason: 'terraform module' };
  }
  if (lower === 'provider') {
    return { score: 90, reason: 'cloud provider' };
  }
  if (lower === 'workspace') {
    return { score: 88, reason: 'terraform workspace' };
  }
  if (lower === 'mode') {
    return { score: 85, reason: 'resource mode' };
  }
  if (lower === 'resource_address') {
    return { score: 82, reason: 'resource reference' };
  }

  // Operational/status columns (60-75 range)
  // instances.status, check_results.status, transactions.state
  if (lower === 'status') {
    return { score: 75, reason: 'resource status' };
  }
  if (lower === 'state') {
    return { score: 72, reason: 'transaction state' };
  }
  if (lower === 'action') {
    return { score: 68, reason: 'log action' };
  }
  if (lower === 'object_type') {
    return { score: 65, reason: 'object type' };
  }
  if (lower === 'tags') {
    return { score: 62, reason: 'tags (jsonb)' };
  }

  // Data columns (45-55 range)
  // instances.index_key, instances.deposed, outputs.value
  if (lower === 'index_key') {
    return { score: 55, reason: 'instance index' };
  }
  if (lower === 'deposed') {
    return { score: 52, reason: 'deposed key' };
  }
  if (lower === 'value') {
    return { score: 50, reason: 'output value' };
  }
  if (lower === 'data') {
    return { score: 48, reason: 'log data' };
  }

  // JSONB/wide columns (35-42 range) - useful but can be very wide
  if (lower === 'attributes') {
    return { score: 42, reason: 'attributes (jsonb)' };
  }
  if (lower === 'sensitive_attributes') {
    return { score: 38, reason: 'sensitive data' };
  }
  if (lower === 'identity') {
    return { score: 36, reason: 'identity (jsonb)' };
  }

  // Internal/UUID columns (20-32 range)
  // state_id, tenant_id, group_id, user_id, tx_id, created_by, completed_by
  const uuidCols = ['state_id', 'tenant_id', 'group_id', 'user_id', 'tx_id',
                    'created_by', 'completed_by'];
  if (uuidCols.includes(lower)) {
    return { score: 28, reason: 'internal uuid' };
  }

  // Timestamp columns
  const timestampCols = ['created_at', 'updated_at', 'completed_at'];
  if (timestampCols.includes(lower)) {
    return { score: 25, reason: 'timestamp' };
  }

  // Schema/version columns
  if (lower === 'schema_version' || lower === 'identity_schema_version') {
    return { score: 22, reason: 'schema version' };
  }

  // Private/internal text
  if (lower === 'private') {
    return { score: 20, reason: 'private data' };
  }

  // Generic 'id' - could be meaningful in aggregations (count by id)
  if (lower === 'id') {
    return { score: 32, reason: 'id (uuid)' };
  }

  // Count column from aggregations
  if (lower === 'count') {
    return { score: 100, reason: 'aggregate count' };
  }

  // Default score for unknown columns (might be from JOINs or custom expressions)
  return { score: 50, reason: 'unknown' };
}

/**
 * Calculate null ratio for a column across sample rows.
 */
function calculateNullRatio(column: string, rows: Record<string, unknown>[]): number {
  if (rows.length === 0) return 1;
  const nullCount = rows.filter(row => row[column] === null || row[column] === undefined).length;
  return nullCount / rows.length;
}

/**
 * Rank columns by importance for display.
 * Returns sorted array of column names (most important first).
 *
 * @param columns - All available column names
 * @param rows - Sample rows for null-detection (optional, improves ranking)
 * @param limit - Max columns to return (default: 7)
 */
export function rankColumns(
  columns: string[],
  rows: Record<string, unknown>[] = [],
  limit: number = 7
): string[] {
  // Score each column
  const scored: ColumnScore[] = columns.map(column => {
    const nameScore = scoreColumnName(column);
    let score = nameScore.score;

    // Penalize columns that are mostly null (if we have sample data)
    if (rows.length > 0) {
      const nullRatio = calculateNullRatio(column, rows);
      if (nullRatio > 0.8) {
        score -= 20;
      }
    }

    // Tie-breaker: prefer shorter column names
    const lengthPenalty = Math.min(column.length / 100, 5);
    score -= lengthPenalty;

    return {
      column,
      score,
      reason: nameScore.reason
    };
  });

  // Sort by score (desc), then by column name (asc) for stability
  scored.sort((a, b) => {
    if (b.score !== a.score) {
      return b.score - a.score;
    }
    return a.column.localeCompare(b.column);
  });

  // Return top N columns
  return scored.slice(0, limit).map(s => s.column);
}

/**
 * Get all column scores for debugging/inspection.
 */
export function getColumnScores(
  columns: string[],
  rows: Record<string, unknown>[] = []
): ColumnScore[] {
  return columns.map(column => {
    const nameScore = scoreColumnName(column);
    let score = nameScore.score;

    if (rows.length > 0) {
      const nullRatio = calculateNullRatio(column, rows);
      if (nullRatio > 0.8) {
        score -= 20;
      }
    }

    const lengthPenalty = Math.min(column.length / 100, 5);
    score -= lengthPenalty;

    return { column, score, reason: nameScore.reason };
  }).sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.column.localeCompare(b.column);
  });
}

/**
 * Detect if a query looks like "SELECT *" (or semantic equivalent).
 */
export function isSelectAllQuery(query: string): boolean {
  const normalized = query.trim().toLowerCase();

  // Match "SELECT *" patterns
  if (/select\s+\*\s+from/i.test(normalized)) {
    return true;
  }

  // Also match "SELECT table.*" patterns
  if (/select\s+\w+\.\*\s+from/i.test(normalized)) {
    return true;
  }

  return false;
}

/**
 * State cost history.
 *
 * The dedicated `/api/v1/states/{state_id}/costs/history` REST endpoint was
 * dropped in favour of the generic MQL endpoint, now that `cost_snapshots`
 * is exposed via MQL with tenant scoping baked in. This module wraps the
 * equivalent MQL query into the same shape the UI used before.
 */

import { executeMQL } from "@/lib/api/client";
import { parseLinkHeader, hasNextPage } from "@/lib/api/pagination";

import { coveragePercent, num, optStr, str } from "./mql-coerce";

export interface StateCostHistoryPoint {
  snapshot_id: string;
  calculated_at: string;
  currency: string;
  monthly_cost: string | null;
  hourly_cost: string | null;
  resource_count: number;
  priced_count: number;
  coverage_percent: number;
  triggered_by: string;
}

interface CostSnapshotRow {
  id?: unknown;
  calculated_at?: unknown;
  currency?: unknown;
  monthly_cost?: unknown;
  hourly_cost?: unknown;
  resource_count?: unknown;
  priced_count?: unknown;
  triggered_by?: unknown;
}

// Page size for cursoring the history window. The `[from, to]` filter bounds
// the total row count, so the cursor loop terminates naturally.
const HISTORY_PAGE_LIMIT = 1000;

/** Escape a value for a single-quoted SQL string literal. */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** One page of a state's cost history, keyset-ordered `(calculated_at, id)`
 *  ascending (unique + oldest-first) so the MQL cursor advances cleanly. */
export function stateCostHistoryQuery(
  stateId: string,
  from: string,
  to: string,
  pageSize: number
): string {
  return `select id, calculated_at, currency, monthly_cost, hourly_cost,
    resource_count, priced_count, triggered_by
    from cost_snapshots
    where state_id = ${sqlLiteral(stateId)}
      and kind = 'current'
      and calculated_at >= ${sqlLiteral(from)}
      and calculated_at <= ${sqlLiteral(to)}
    order by calculated_at, id
    limit ${pageSize}`;
}

function rowToPoint(row: CostSnapshotRow): StateCostHistoryPoint {
  const resource_count = num(row.resource_count);
  const priced_count = num(row.priced_count);
  return {
    snapshot_id: str(row.id),
    calculated_at: str(row.calculated_at),
    currency: str(row.currency),
    monthly_cost: optStr(row.monthly_cost),
    hourly_cost: optStr(row.hourly_cost),
    resource_count,
    priced_count,
    coverage_percent: coveragePercent(resource_count, priced_count),
    triggered_by: str(row.triggered_by),
  };
}

/**
 * Fetch a state's cost history.
 *
 * Returns EVERY snapshot in the inclusive `[from, to]` window, oldest first so
 * a time-axis chart can plot them directly. Cursors past the MQL page cap via
 * the `Link` header — the previous fixed `limit 30` silently dropped everything
 * past the most-recent 30 snapshots, corrupting the chart's left edge, the
 * range delta baseline, and the snapshot-count hint (#1066). Each point holds
 * headline totals only; for the full latest breakdown use `fetchStateCost`.
 *
 * `from` / `to` are ISO 8601 timestamps. `limit` (optional) sets the page size,
 * not a total cap — the whole window is always loaded.
 */
export async function fetchStateCostHistory(
  stateId: string,
  options: { from: string; to: string; limit?: number }
): Promise<StateCostHistoryPoint[]> {
  const pageSize = Math.max(1, Math.min(HISTORY_PAGE_LIMIT, options.limit ?? HISTORY_PAGE_LIMIT));
  const query = stateCostHistoryQuery(stateId, options.from, options.to, pageSize);

  const points: StateCostHistoryPoint[] = [];
  let page: string[] | undefined = undefined;
  for (;;) {
    const result = await executeMQL(query, { page });
    const rows = result.data as CostSnapshotRow[];
    for (const row of rows) points.push(rowToPoint(row));
    const links = parseLinkHeader(result.linkHeader);
    if (rows.length < pageSize || !hasNextPage(links) || !links.next) break;
    page = links.next;
  }
  return points;
}

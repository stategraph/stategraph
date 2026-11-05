/**
 * Per-state latest cost summary.
 *
 * Originally surfaced as `latest_cost_*` fields on the state schema, but
 * scoping per-feature data onto the core state record doesn't scale -- every
 * UI screen would end up with its own fields hanging off `state`. We fetch
 * what the cost-analysis page actually needs via MQL, the same way history
 * is fetched: a `select distinct on (state_id)` over `cost_snapshots` gives
 * one row per state with its most recent `current` snapshot.
 */

import { executeMQL } from "@/lib/api/client";

import { coveragePercent, num, optStr, str } from "./mql-coerce";

export interface LatestStateCost {
  calculated_at: string;
  currency: string;
  monthly_cost: string | null;
  coverage_percent: number;
}

interface LatestRow {
  state_id?: unknown;
  calculated_at?: unknown;
  currency?: unknown;
  monthly_cost?: unknown;
  resource_count?: unknown;
  priced_count?: unknown;
}

/**
 * Fetch the most recent `current` cost snapshot for every state in the
 * caller's tenants. Returns a map keyed by `state_id`. States that have
 * never been priced are simply absent from the map -- callers should
 * default to "no cost data yet" when a state id is missing.
 *
 * MQL doesn't support `distinct on`, so we do the standard
 * "latest-per-group" pattern with a CTE: `max(calculated_at) group by
 * state_id`, then join back. If two snapshots for the same state share
 * `calculated_at` to microsecond precision, both rows survive the join and
 * the caller's `Map.set` collapses them (any of the tied rows is a
 * reasonable "latest cost summary" -- they're written in the same instant).
 *
 * Comma-separated FROM with WHERE is required by MQL's CTE-wrapping (see
 * `app/(console)/home/mqlQueries.ts` for the same idiom + rationale).
 */
export async function fetchLatestCostPerState(): Promise<Map<string, LatestStateCost>> {
  // MQL's parser requires explicit `AS` for table aliases (see
  // code/src/mql_parser/mql_parser.mly: the `table` non-terminal only
  // matches IDENTIFIER + AS + IDENTIFIER, not the SQL "FROM foo bar"
  // implicit-alias form), so write `cost_snapshots AS cs` even though
  // plain Postgres would accept it without.
  const query = `with latest as (
    select state_id, max(calculated_at) as max_at
    from cost_snapshots
    where kind = 'current'
    group by state_id
  )
  select cs.state_id, cs.calculated_at, cs.currency, cs.monthly_cost,
         cs.resource_count, cs.priced_count
  from cost_snapshots as cs, latest
  where cs.state_id = latest.state_id
    and cs.calculated_at = latest.max_at
    and cs.kind = 'current'`;
  const result = await executeMQL(query);
  const out = new Map<string, LatestStateCost>();
  for (const raw of result.data as LatestRow[]) {
    const stateId = str(raw.state_id);
    if (!stateId) continue;
    const resource_count = num(raw.resource_count);
    const priced_count = num(raw.priced_count);
    out.set(stateId, {
      calculated_at: str(raw.calculated_at),
      currency: str(raw.currency),
      monthly_cost: optStr(raw.monthly_cost),
      coverage_percent: coveragePercent(resource_count, priced_count),
    });
  }
  return out;
}

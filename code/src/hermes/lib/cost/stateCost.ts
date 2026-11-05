/**
 * Per-state cost reads via MQL (#1069, PR A) — replaces the dedicated
 * `getStateCosts` and `getStateCostUnsupported` REST endpoints.
 *
 * `getStateCosts` returned the latest `current` snapshot's totals + coverage +
 * the full per-resource `instance_costs` breakdown. `getStateCostUnsupported`
 * returned the same resources filtered to the unpriced/unsupported subset — so
 * once the breakdown comes from MQL, the unsupported list is derived from it
 * client-side (`deriveUnsupported`), dropping that second read entirely.
 *
 * Money stays a string end-to-end (`monthly_cost`/`hourly_cost` are projected
 * `::text` in the allow-list to preserve numeric precision; sum/compare via
 * `parseCost`, never SQL `::real`). MQL has no `distinct on`, so "latest
 * snapshot" is the `max(calculated_at)` CTE-join pattern (same as
 * `fetchLatestCostPerState`); comma-FROM + explicit `AS` aliases are required
 * by the MQL parser/CTE-wrapping.
 */

import {
  executeMQL,
  type StateCosts,
  type InstanceCost,
  type StateCostUnsupported,
} from "@/lib/api/client";
import { parseLinkHeader, hasNextPage } from "@/lib/api/pagination";
import { coveragePercent, num, optStr, str } from "./mql-coerce";

// The `/api/v1/mql` page hard-caps at 1000 rows; the breakdown cursors past it
// (a snapshot can have thousands of resources). An explicit LIMIT also avoids
// the endpoint's default-20 truncation.
const RESOURCES_PAGE_LIMIT = 1000;

/** Escape a value for a single-quoted SQL string literal. */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** Latest `current` snapshot totals for one state (one row, or none if the
 *  state has never been priced). */
export function stateCostTotalsQuery(stateId: string): string {
  const sid = sqlLiteral(stateId);
  return `with latest as (
    select state_id, max(calculated_at) as max_at
    from cost_snapshots
    where state_id = ${sid} and kind = 'current'
    group by state_id
  )
  select cs.id, cs.calculated_at, cs.currency, cs.monthly_cost, cs.hourly_cost,
         cs.resource_count, cs.supported_count, cs.priced_count, cs.source, cs.triggered_by
  from cost_snapshots as cs, latest
  where cs.state_id = latest.state_id
    and cs.calculated_at = latest.max_at
    and cs.kind = 'current'
  limit 1`;
}

/** Per-resource cost breakdown for a snapshot, keyset-ordered by `address` for
 *  stable cursor pagination past the 1000-row page cap. */
export function stateCostResourcesQuery(snapshotId: string): string {
  return `select address, type, provider, region, supported, no_price,
    monthly_cost, hourly_cost, components, tags, cloud_resource_id
  from cost_snapshot_resources
  where snapshot_id = ${sqlLiteral(snapshotId)}
  order by address
  limit ${RESOURCES_PAGE_LIMIT}`;
}

interface TotalsRow {
  id?: unknown; calculated_at?: unknown; currency?: unknown;
  monthly_cost?: unknown; hourly_cost?: unknown; resource_count?: unknown;
  supported_count?: unknown; priced_count?: unknown; source?: unknown; triggered_by?: unknown;
}

interface ResourceRow {
  address?: unknown; type?: unknown; provider?: unknown; region?: unknown;
  supported?: unknown; no_price?: unknown; monthly_cost?: unknown; hourly_cost?: unknown;
  components?: unknown; tags?: unknown; cloud_resource_id?: unknown;
}

function mapInstanceCost(r: ResourceRow): InstanceCost {
  return {
    address: str(r.address),
    type: str(r.type),
    provider: optStr(r.provider) ?? undefined,
    region: optStr(r.region) ?? undefined,
    supported: r.supported === true,
    no_price: r.no_price === true,
    monthly_cost: optStr(r.monthly_cost) ?? undefined,
    hourly_cost: optStr(r.hourly_cost) ?? undefined,
    components: Array.isArray(r.components) ? (r.components as InstanceCost["components"]) : undefined,
    tags: r.tags && typeof r.tags === "object" ? (r.tags as InstanceCost["tags"]) : undefined,
    cloud_resource_id: optStr(r.cloud_resource_id) ?? undefined,
  };
}

/**
 * Latest per-state cost snapshot (totals + coverage + per-resource breakdown),
 * via MQL. Throws when the state has never been priced — mirroring
 * `getStateCosts`' 404 contract, so callers (`useStateCosts` cache,
 * `CostAnalysisClient` allSettled) keep treating "no snapshot" as "no data".
 */
export async function fetchStateCost(stateId: string): Promise<StateCosts> {
  const totalsRes = await executeMQL(stateCostTotalsQuery(stateId));
  const row = (totalsRes.data as TotalsRow[])[0];
  if (!row) {
    throw new Error(`State ${stateId} has no cost snapshot`);
  }
  const snapshotId = str(row.id);

  // Cursor through the breakdown (a snapshot can exceed the 1000-row page cap).
  const instanceCosts: InstanceCost[] = [];
  let page: string[] | undefined = undefined;
  for (;;) {
    const resourcesRes = await executeMQL(stateCostResourcesQuery(snapshotId), { page });
    const rows = resourcesRes.data as ResourceRow[];
    for (const rr of rows) instanceCosts.push(mapInstanceCost(rr));
    const links = parseLinkHeader(resourcesRes.linkHeader);
    if (rows.length < RESOURCES_PAGE_LIMIT || !hasNextPage(links) || !links.next) break;
    page = links.next;
  }

  const resourceCount = num(row.resource_count);
  const pricedCount = num(row.priced_count);
  return {
    snapshot_id: snapshotId,
    calculated_at: str(row.calculated_at),
    currency: str(row.currency),
    monthly_cost: optStr(row.monthly_cost) ?? undefined,
    hourly_cost: optStr(row.hourly_cost) ?? undefined,
    resource_count: resourceCount,
    supported_count: num(row.supported_count),
    priced_count: pricedCount,
    coverage_percent: coveragePercent(resourceCount, pricedCount),
    source: str(row.source),
    triggered_by: str(row.triggered_by),
    instance_costs: instanceCosts,
  };
}

/**
 * The unsupported/unpriced coverage-gap list, derived from a state's cost
 * breakdown (replaces the separate `getStateCostUnsupported` read): every
 * resource that is unsupported or has no price.
 */
export function deriveUnsupported(costs: StateCosts): StateCostUnsupported {
  return {
    snapshot_id: costs.snapshot_id,
    calculated_at: costs.calculated_at,
    resources: costs.instance_costs
      .filter((r) => !r.supported || r.no_price)
      .map((r) => ({
        address: r.address,
        type: r.type,
        provider: r.provider,
        supported: r.supported,
        no_price: r.no_price,
      })),
  };
}

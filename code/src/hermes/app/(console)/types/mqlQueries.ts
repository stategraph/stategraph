// MQL query for the Resource Types page.
//
// Per-resource-type instance counts, either for a single state or across all
// live states, in ONE server-side query. Previously this screen fetched
// `/resources/summary` per state and merged the results client-side, which
// silently dropped any state whose fetch failed.
//
// IMPORTANT: All table references use comma-separated FROM with WHERE instead
// of INNER JOIN, and scoped tables (`resources`, `instances`, `states`) are
// referenced by BARE NAME — MQL wraps user queries inside outer CTEs for the
// tenant-scoped tables, so INNER JOIN and table aliasing on those tables are
// rejected. See `app/(console)/home/mqlQueries.ts` for the same idiom and
// rationale.
//
// Instances are joined to their resource by address, mirroring the count that
// `/resources/summary` produces. The explicit `limit` is required because the
// `/api/v1/mql` endpoint applies a default limit of 20 when none is given,
// which would silently truncate the type list.

// Cap on the number of distinct resource types returned. The endpoint's
// default limit (20) truncates silently, so we always request an explicit,
// generous cap.
export const MAX_TYPES = 1000;

/** One row returned by `resourceTypesQuery`. */
export interface ResourceTypeRow {
  type: string;
  instances: number;
}

/**
 * Per-resource-type instance counts.
 *
 * With `stateId`, counts are scoped to that single state. Without it, counts
 * are summed across every live (non-deleted) state.
 */
export function resourceTypesQuery(stateId?: string): string {
  if (stateId) {
    return `select resources.type as type, count(*) as instances
from resources, instances
where resources.state_id = '${stateId}'
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
group by resources.type
order by count(*) desc, resources.type
limit ${MAX_TYPES}`;
  }

  return `select resources.type as type, count(*) as instances
from resources, instances, states
where states.deleted_at is null
  and resources.state_id = states.id
  and instances.state_id = resources.state_id
  and instances.resource_address = resources.address
group by resources.type
order by count(*) desc, resources.type
limit ${MAX_TYPES}`;
}

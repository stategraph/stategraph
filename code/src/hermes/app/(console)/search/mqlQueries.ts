// MQL query for the Search page's filter-mode facet dropdowns.
//
// Distinct provider / type / module values for a scope (one state or all live
// states), computed server-side in ONE query. Previously the Search page
// fetched up to 10,000 instances per state and derived the distinct values
// client-side, which was both heavy and incomplete: a state with more than
// 10,000 instances (or hitting the endpoint's default limit) produced a partial
// facet list — the original "22 providers vs a truncated 20" symptom.
//
// provider / type / module are resource-level columns and every resource has at
// least one instance, so distinct-over-resources equals distinct-over-instances
// (what the old code computed from the instance list).
//
// IMPORTANT: scoped tables (`resources`, `states`) are referenced by BARE NAME
// with comma-separated FROM + WHERE (no INNER JOIN, no aliasing) — MQL wraps
// user queries inside outer CTEs for the tenant-scoped tables and rejects
// INNER JOIN / aliasing on them. See `app/(console)/types/mqlQueries.ts` for
// the same idiom and rationale.
//
// Each facet list is capped and folded into a single JSON array via `json_agg`
// so the whole result is ONE row. That dodges the `/api/v1/mql` default limit of
// 20 (applied when a query carries no explicit LIMIT) that would otherwise
// truncate a multi-row facet list silently.

// Cap on the number of distinct values returned per facet.
export const MAX_FACET_VALUES = 1000;

/**
 * The single row returned by `filterOptionsQuery`.
 *
 * Each field is `null` when its `json_agg` ran over zero rows (the scope has no
 * resources with that column set).
 */
export interface FilterOptionsRow {
  providers: string[] | null;
  types: string[] | null;
  modules: string[] | null;
}

/**
 * Distinct provider / type / module values for the filter dropdowns.
 *
 * With `stateId`, values are scoped to that single (live) state. Without it,
 * values span every live (non-deleted) state.
 */
export function filterOptionsQuery(stateId?: string): string {
  const scope = stateId ? `and states.id = '${stateId}'` : '';

  return `with
prov as (select resources.provider as v from resources, states
  where states.id = resources.state_id and states.deleted_at is null ${scope}
  and resources.provider is not null group by resources.provider order by resources.provider limit ${MAX_FACET_VALUES}),
typ as (select resources.type as v from resources, states
  where states.id = resources.state_id and states.deleted_at is null ${scope}
  and resources.type is not null group by resources.type order by resources.type limit ${MAX_FACET_VALUES}),
mod as (select resources.module as v from resources, states
  where states.id = resources.state_id and states.deleted_at is null ${scope}
  and resources.module is not null group by resources.module order by resources.module limit ${MAX_FACET_VALUES}),
prov_j as (select json_agg(prov.v) as j from prov),
typ_j as (select json_agg(typ.v) as j from typ),
mod_j as (select json_agg(mod.v) as j from mod)
select prov_j.j as providers, typ_j.j as types, mod_j.j as modules
from prov_j, typ_j, mod_j`;
}

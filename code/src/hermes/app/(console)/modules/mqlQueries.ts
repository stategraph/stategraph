// MQL query for the Modules page.
//
// Modules are NOT a physical table — they are an aggregation over `resources`
// grouped by the module column (MQL exposes it as `resources.module`; the
// physical column is `module_`). The all-states view aggregates across every
// state in one query instead of firing one REST request per state (#1073),
// which also fixes the modules-page truncation/search/footer bugs (#1062): the
// full tenant-wide set comes back in a single response, so search runs over the
// complete set and the footer total is the real distinct-module count.
//
// Two counts, mirroring the backend's own modules SQL:
//   resource_count — rows in `resources` for the module (one per address)
//   instance_count — rows in `instances` for the module (for_each/count expanded)
//
// MQL constraint: `count()` accepts ONLY `count(*)` — `count(<col>)` and
// `count(distinct <col>)` both fail to parse. So each count is its own
// `count(*)` CTE (a resources-only CTE gives distinct resources; an
// instances-joined CTE gives instance rows), joined on the module name.
//
// `module_ IS NULL` (the root module) is excluded, matching the REST endpoint
// (`GET /api/v1/states/{id}/modules` never returns "root").
//
// Engine idioms (shared with the other MQL queries): scoped tables
// (`resources`/`instances`/`states`) are referenced BARE NAME with comma-FROM +
// WHERE, never INNER JOIN.

import type { Module } from "@/lib/api/client";

// Real-world module counts are tens; this explicit cap sits far above any
// realistic estate and only guards against the MQL default-limit truncation on
// a pathological one (there is no cursor loop — the whole set is one page).
const MODULE_LIMIT = 1000;

/** One row returned by `allStatesModulesQuery`. */
export interface ModuleRow {
  module: string;
  resource_count: number;
  instance_count: number;
}

/** Map an aggregate row to the `Module` schema shape the UI renders. */
export function rowToModule(row: ModuleRow): Module {
  return {
    name: row.module,
    resource_count: Number(row.resource_count ?? 0),
    instance_count: Number(row.instance_count ?? 0),
  };
}

/**
 * Every module across ALL of the tenant's states, aggregated tenant-wide in a
 * single query (the tenant scope comes from the authenticated MQL context).
 * Replaces the per-state REST fan-out. Ordered by module name to match the
 * page's prior display order.
 */
export function allStatesModulesQuery(): string {
  return `with mods as (
  select resources.module as module, count(*) as resource_count
  from resources, states
  where states.id = resources.state_id
    and states.deleted_at is null
    and resources.module is not null
  group by resources.module),
insts as (
  select resources.module as module, count(*) as instance_count
  from resources, instances, states
  where instances.resource_address = resources.address
    and instances.state_id = resources.state_id
    and states.id = resources.state_id
    and states.deleted_at is null
    and resources.module is not null
  group by resources.module)
select mods.module as module,
       mods.resource_count as resource_count,
       insts.instance_count as instance_count
from mods, insts
where insts.module = mods.module
order by mods.module
limit ${MODULE_LIMIT}`;
}

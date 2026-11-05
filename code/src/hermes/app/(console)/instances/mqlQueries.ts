// Slim MQL queries for the Resources / inventory page.
//
// The inventory page needs the COMPLETE instance set for a state to compute
// facets, filters, the "no dependents" leaf view, and counts exactly (a fetched
// window makes them inaccurate). But loading the full `attributes` blob for every
// instance is what makes that slow: on a 3,000-instance state the attributes are
// ~20MB, and transferring + JSON.parsing + materializing them dominates page
// load (~1.3s of scripting, measured), while the table itself only ever renders
// ~100 rows and layout is negligible.
//
// So the whole-set load uses `slimInstancesQuery`, which returns only the columns
// the list + facets read: the resource identity columns plus a jsonb projection
// of `attributes` containing exactly the keys the client-side heuristics inspect
// (`tags` for tag facets, and `LOCATION_SOURCE_FIELDS` for the region heuristic).
// This is ~14x smaller than the full payload and keeps faceting byte-identical to
// today — the heuristics are unchanged, they just run over a slim projection.
//
// The full `attributes` (and `sensitive_attributes`) for a single instance are
// fetched on demand via `instanceAttributesQuery` when its detail drawer opens.
//
// Engine notes (shared with the dedicated instances endpoint): scoped tables
// (resources/instances/states) are referenced by BARE NAME with comma-FROM +
// WHERE. `attributes` comes back MASKED (`__SENSITIVE__`); the slim projection
// reads from the masked column, so masking is preserved. `(state_id, address)`
// is a unique total order, giving a stable keyset cursor WITHIN a state.

import type { Instance, InstanceAttributes } from "@/lib/api/client";
import { LOCATION_SOURCE_FIELDS } from "@/lib/instances/metadata";

// The `/api/v1/mql` endpoint hard-caps a page at 1000 rows; the loader cursors
// past this to assemble the full set.
export const PAGE_LIMIT = 1000;

/**
 * Attribute keys the slim projection keeps — exactly what the client-side
 * facet/filter heuristics read: `tags` (tag facets, environment/owner/etc.) and
 * every field `getLocation` inspects. Everything else in `attributes` is dropped
 * from the whole-set load and fetched on demand for the drawer.
 */
export const SLIM_ATTRIBUTE_KEYS: readonly string[] = ["tags", ...LOCATION_SOURCE_FIELDS];

/** One row returned by the slim instance queries, mirroring the selected columns. */
export interface InstanceRow {
  address: string;
  type: string;
  provider: string;
  module: string | null;
  attributes: InstanceAttributes | null;
  dependencies: string[] | null;
  state_id: string;
  /** Only the all-states query carries this (joined from `states.name`); the
   *  single-state query relies on the caller passing the name instead. */
  state_name?: string | null;
}

/** Full attributes for a single instance, returned by `instanceAttributesQuery`. */
export interface InstanceAttributesRow {
  attributes: InstanceAttributes | null;
  sensitive_attributes: InstanceAttributes | null;
}

/**
 * Convert a slim MQL row into the `Instance` shape the UI expects, normalizing
 * SQL `null`s to `undefined` (the API-typed optionals). `stateName` is threaded
 * in for the all-states view, which the query itself does not carry.
 */
export function instanceRowToInstance(row: InstanceRow, stateName?: string): Instance {
  return {
    address: row.address,
    type: row.type,
    provider: row.provider,
    module: row.module ?? undefined,
    attributes: row.attributes ?? undefined,
    dependencies: row.dependencies ?? undefined,
    state_id: row.state_id,
    // Prefer the name the all-states query joined in; fall back to the caller's
    // (single-state loads pass it explicitly since that query omits the column).
    state_name: row.state_name ?? stateName,
  };
}

/** Escape a value for a single-quoted SQL string literal. */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** The slim `attributes` jsonb projection: only the allowlisted facet keys. */
function slimAttributesProjection(): string {
  const pairs = SLIM_ATTRIBUTE_KEYS.map(
    (key) => `${sqlLiteral(key)}, instances.attributes->${sqlLiteral(key)}`
  ).join(",\n    ");
  return `jsonb_build_object(\n    ${pairs}\n  )`;
}

/**
 * All instances in one state with a SLIM attribute projection, keyset-ordered
 * for stable cursor pagination.
 */
export function slimInstancesQuery(stateId: string): string {
  return `select
  instances.address as address,
  resources.type as type,
  resources.provider as provider,
  resources.module as module,
  ${slimAttributesProjection()} as attributes,
  instances.dependencies as dependencies,
  instances.state_id as state_id
from resources, instances, states
where instances.resource_address = resources.address
  and instances.state_id = resources.state_id
  and states.id = instances.state_id
  and states.deleted_at is null
  and states.id = ${sqlLiteral(stateId)}
order by instances.state_id, instances.address
limit ${PAGE_LIMIT}`;
}

/**
 * Every instance across ALL of the tenant's states with the SLIM projection —
 * the all-states counterpart to `slimInstancesQuery`. Same columns plus the
 * joined `states.name` (so the caller needn't thread names per state), no
 * single-state filter, and the same `(state_id, address)` keyset order. Because
 * that order is a total order across states, the loader cursors the whole
 * tenant in one paginated walk (the #1059 keyset cursor) instead of firing one
 * request per state.
 */
export function slimInstancesAllStatesQuery(): string {
  return `select
  instances.address as address,
  resources.type as type,
  resources.provider as provider,
  resources.module as module,
  ${slimAttributesProjection()} as attributes,
  instances.dependencies as dependencies,
  instances.state_id as state_id,
  states.name as state_name
from resources, instances, states
where instances.resource_address = resources.address
  and instances.state_id = resources.state_id
  and states.id = instances.state_id
  and states.deleted_at is null
order by instances.state_id, instances.address
limit ${PAGE_LIMIT}`;
}

/**
 * Full `attributes` + `sensitive_attributes` for a single instance, for the
 * detail drawer (loaded on demand so the whole-set load stays slim).
 */
export function instanceAttributesQuery(stateId: string, address: string): string {
  return `select
  instances.attributes as attributes,
  instances.sensitive_attributes as sensitive_attributes
from instances, states
where instances.state_id = states.id
  and states.deleted_at is null
  and states.id = ${sqlLiteral(stateId)}
  and instances.address = ${sqlLiteral(address)}
limit 1`;
}

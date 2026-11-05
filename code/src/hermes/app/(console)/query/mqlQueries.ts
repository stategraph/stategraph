// MQL query for the query-editor autocomplete metadata (#1078).
//
// The editor's autocomplete needs the distinct resource TYPES in the selected
// state (provider suggestions are derived client-side from the type prefix,
// e.g. "aws" from "aws_instance" — unchanged). This replaces the dedicated
// `getStateResourcesSummary` read with a plain MQL read of allow-listed
// `resources`.
//
// Engine idiom: scoped tables (`resources`/`states`) are bare-name with
// comma-FROM + WHERE. The explicit LIMIT dodges the `/api/v1/mql` default-20 cap.

const TYPES_LIMIT = 1000;

/** Escape a value for a single-quoted SQL string literal (state id is from the
 *  selected-state context / URL). */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** One row returned by `resourceTypesQuery`. */
export interface ResourceTypeRow {
  type: string;
}

/**
 * Distinct resource types in one state, for autocomplete. Ordered for stable
 * suggestions. Callers derive the provider list from the type prefix, matching
 * the prior `Object.keys(resourcesSummary)` behavior.
 */
export function resourceTypesQuery(stateId: string): string {
  return `select resources.type as type
from resources, states
where states.id = resources.state_id
  and states.deleted_at is null
  and states.id = ${sqlLiteral(stateId)}
group by resources.type
order by resources.type
limit ${TYPES_LIMIT}`;
}

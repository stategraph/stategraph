// Server-side chart aggregation for the Visualization + Dashboard viewers (#1055).
//
// The viewers used to fetch a capped page of instances (limit 1000, or 20 on the
// dashboard MQL fallback) and count client-side, silently undercounting states
// with more instances than the cap. Instead we build a `count(*) group by <dim>`
// MQL query that the server evaluates over the WHOLE state — the same idiom the
// Resource Types page uses (`app/(console)/query`-adjacent `types/mqlQueries.ts`).
//
// Only the first-class dimensions below are supported; anything else (an exotic
// dimension, COUNT(field), or a WHERE on an unrecognized field) returns null so
// the viewer renders an explicit error state instead of a wrong chart.
//
// MQL engine notes: scoped tables (`resources`/`instances`) are referenced by
// BARE NAME with comma-FROM + WHERE (no INNER JOIN, no aliasing); `count(*)` is
// the only aggregate; `group by` requires an aggregate; always pass an explicit
// `limit` (the endpoint applies a silent default of 20 otherwise).

import type { WhereCondition, ParsedQuery } from "@/app/(console)/query/compiler";

/** Max distinct dimension values a group-by aggregation returns. */
export const AGG_LIMIT = 1000;

/**
 * dimensionField -> the MQL column to group by. These are the only dimensions
 * server-side aggregation supports (they match the fields the query compiler
 * recognizes in WHERE clauses). Anything else is unsupported.
 */
export const AGG_DIMENSION_COLUMNS: Record<string, string> = {
  type: "resources.type",
  provider: "resources.provider",
  module: "resources.module",
  address: "instances.address",
};

/** Escape a value for a single-quoted SQL string literal. */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/**
 * Translate the compiler's WHERE conditions into MQL predicate fragments, or
 * null if any condition references a field outside AGG_DIMENSION_COLUMNS — the
 * whole query is then unsupported rather than silently dropping a filter.
 *
 * Unlike the old tag-query path (which dropped LIKE and used only the first IN
 * value), MQL applies LIKE (as `ilike`) and full IN lists.
 */
function whereToMql(conditions: WhereCondition[]): string[] | null {
  const fragments: string[] = [];
  for (const { field, operator, value } of conditions) {
    const col = AGG_DIMENSION_COLUMNS[field];
    if (!col) return null;
    switch (operator) {
      case "=":
        fragments.push(`${col} = ${sqlLiteral(String(value))}`);
        break;
      case "!=":
        fragments.push(`${col} != ${sqlLiteral(String(value))}`);
        break;
      case "LIKE":
        fragments.push(`${col} ilike ${sqlLiteral(String(value))}`);
        break;
      case "IN": {
        const values = (Array.isArray(value) ? value : [value]).filter((v) => v !== "");
        if (values.length === 0) return null;
        fragments.push(`${col} in (${values.map((v) => sqlLiteral(String(v))).join(", ")})`);
        break;
      }
      default:
        return null;
    }
  }
  return fragments;
}

/**
 * Build a single-state server-side aggregation MQL query, or null when the shape
 * isn't supported (exotic dimension, COUNT(field), or a WHERE on an unrecognized
 * field). Generalizes `resourceTypesQuery` to any first-class dimension + filters.
 */
export function buildAggregationQuery(params: {
  stateId: string;
  dimensionField: string;
  where: WhereCondition[];
  aggregation?: ParsedQuery["aggregation"];
}): string | null {
  const { stateId, dimensionField, where, aggregation } = params;

  const whereFragments = whereToMql(where);
  if (whereFragments === null) return null;

  const scope = [
    `resources.state_id = ${sqlLiteral(stateId)}`,
    "instances.state_id = resources.state_id",
    "instances.resource_address = resources.address",
    ...whereFragments,
  ].join("\n  and ");

  // Scalar COUNT(*): a single total over the whole state (no grouping).
  if (aggregation) {
    if (aggregation.field !== "*") return null; // COUNT(field) unsupported
    return `select count(*) as cnt
from resources, instances
where ${scope}
limit 1`;
  }

  // Group-by chart.
  const col = AGG_DIMENSION_COLUMNS[dimensionField];
  if (!col) return null;

  return `select ${col} as dimension, count(*) as cnt
from resources, instances
where ${scope}
group by ${col}
order by count(*) desc, ${col}
limit ${AGG_LIMIT}`;
}

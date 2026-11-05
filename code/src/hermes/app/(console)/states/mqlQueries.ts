// MQL query for the States list page.
//
// One row per non-deleted state with its resource/instance/edge/module/provider
// counts AND the most-recent transaction touching it, in ONE server-side query.
// Previously this screen issued an N+1 fan-out (`getStateSummary` per state) plus
// a `getTenantTransactions(limit:100)` that it grouped by `tx.state` —
// `transactions.state` is the STATUS (open/committed/aborted/…), never a state
// id, so the grouping never matched and every row showed "No recorded activity".
// Transactions associate to states via `transaction_logs.state_id`; this query
// uses that relation.
//
// IMPORTANT: scoped tables (`states`, `instances`, `resources`, `providers`,
// `transactions`, `transaction_logs`) are referenced by BARE NAME inside CTEs
// (no alias, comma-FROM) — MQL wraps user queries in outer CTEs for the
// tenant-scoped tables and rejects aliasing/INNER JOIN on them; the LEFT JOINs
// below operate on the user CTEs, which is allowed. See
// `app/(console)/types/mqlQueries.ts` for the same idiom and rationale.
//
// `array_length(col, 1::integer)` uses a bare int literal cast (types as bigint,
// which the engine requires). The module count dedups (state_id, module) in its
// own CTE. The explicit final LIMIT is required because the `/api/v1/mql`
// endpoint applies a default limit of 20 when none is given.

// Cap on the number of states returned.
export const MAX_STATES = 1000;

/** One row returned by `statesOverviewQuery`. */
export interface StateOverviewRow {
  state_id: string;
  resources: number;
  instances: number;
  edges: number;
  modules: number;
  providers: number;
  last_tx_created_at: string | null;
  last_tx_completed_at: string | null;
  last_tx_status: string | null;
}

/** Escape a value for a single-quoted SQL string literal (state ids are
 *  URL-derived on the detail page, so escape rather than interpolate raw). */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** The single summary-count row returned by `stateSummaryQuery`, matching the
 *  fields of the `state-summary` API type. */
export interface StateSummaryRow {
  instances: number;
  resources: number;
  providers: number;
  modules: number;
  edges: number;
}

/**
 * Per-state aggregates + most-recent transaction for every live state in the
 * tenant, in one query.
 */
export function statesOverviewQuery(tenantId: string): string {
  return `with
ts as (select id, name, workspace, group_id from states where deleted_at is null and tenant_id = '${tenantId}'),
inst_agg as (select instances.state_id as sid, count(*) as instances,
  coalesce(sum(array_length(instances.dependencies, 1::integer)), 0) as edges
  from instances group by instances.state_id),
res_agg as (select resources.state_id as sid, count(*) as resources from resources group by resources.state_id),
prov_agg as (select providers.state_id as sid, count(*) as providers from providers group by providers.state_id),
mod_dedup as (select resources.state_id as sid, resources.module as m from resources
  where resources.module is not null group by resources.state_id, resources.module),
mod_agg as (select mod_dedup.sid as sid, count(*) as modules from mod_dedup group by mod_dedup.sid),
tx_state as (select transaction_logs.tx_id as tx_id, transaction_logs.state_id as sid
  from transaction_logs group by transaction_logs.tx_id, transaction_logs.state_id),
state_tx as (select tx_state.sid as sid, transactions.created_at as cat, transactions.completed_at as comp, transactions.state as st
  from transactions, tx_state where transactions.id = tx_state.tx_id),
max_tx as (select state_tx.sid as sid, max(state_tx.cat) as maxcat from state_tx group by state_tx.sid),
last_tx as (select state_tx.sid as sid, state_tx.cat as cat, state_tx.comp as comp, state_tx.st as st
  from state_tx, max_tx where state_tx.sid = max_tx.sid and state_tx.cat = max_tx.maxcat)
select ts.id as state_id,
  coalesce(res_agg.resources,0) as resources, coalesce(inst_agg.instances,0) as instances,
  coalesce(inst_agg.edges,0) as edges, coalesce(mod_agg.modules,0) as modules, coalesce(prov_agg.providers,0) as providers,
  last_tx.cat as last_tx_created_at, last_tx.comp as last_tx_completed_at, last_tx.st as last_tx_status
from ts
left join res_agg on res_agg.sid = ts.id left join inst_agg on inst_agg.sid = ts.id
left join prov_agg on prov_agg.sid = ts.id left join mod_agg on mod_agg.sid = ts.id
left join last_tx on last_tx.sid = ts.id
order by ts.id limit ${MAX_STATES}`;
}

// ---------------------------------------------------------------------------
// State detail page (#1087)
// ---------------------------------------------------------------------------

/**
 * Summary counts for ONE state (instances / resources / providers / modules +
 * edges = sum of dependency-array lengths), assembled as one row by
 * cross-joining single-row count CTEs (mirrors `homeScalarsQuery`). Replaces
 * the dedicated `getStateSummary` read on the detail page.
 */
export function stateSummaryQuery(stateId: string): string {
  const sid = sqlLiteral(stateId);
  return `with
ts as (select id from states where deleted_at is null and id = ${sid}),
cnt_i as (select count(*) as c from instances, ts where instances.state_id = ts.id),
cnt_r as (select count(*) as c from resources, ts where resources.state_id = ts.id),
cnt_p as (select count(*) as c from providers, ts where providers.state_id = ts.id),
edges as (select coalesce(sum(array_length(instances.dependencies, 1::integer)), 0) as c
  from instances, ts where instances.state_id = ts.id),
mod_dedup as (select resources.module as m from resources, ts
  where resources.state_id = ts.id and resources.module is not null
  group by resources.module),
cnt_m as (select count(*) as c from mod_dedup)
select cnt_i.c as instances, cnt_r.c as resources, cnt_p.c as providers,
  edges.c as edges, cnt_m.c as modules
from cnt_i, cnt_r, cnt_p, edges, cnt_m`;
}

/**
 * Transactions that touched ONE state, newest first. Associates via
 * `transaction_logs.state_id` (transactions have no state_id — `transactions.state`
 * is a STATUS, which is the bug this fixes). Replaces the detail page's
 * `getTenantTransactions({limit:100})` + client-side `tx.state === stateId` filter.
 * Returns rows shaped like the `transaction` API type (cast to `Transaction[]`).
 */
export function stateTransactionsQuery(stateId: string, limit = 1000): string {
  const sid = sqlLiteral(stateId);
  return `select transactions.id as id, transactions.state as state,
  transactions.created_at as created_at, transactions.completed_at as completed_at,
  transactions.tags as tags, transactions.created_by as created_by
from transactions, transaction_logs
where transaction_logs.tx_id = transactions.id
  and transaction_logs.state_id = ${sid}
group by transactions.id, transactions.state, transactions.created_at,
  transactions.completed_at, transactions.tags, transactions.created_by
order by transactions.created_at desc
limit ${limit}`;
}

/**
 * A single state by id, for the detail page's direct lookup — replaces
 * `getTenantStates().find()`, which searched only the default-20 page and so
 * hard-failed "State not found" past 20 states (#1063). Returns the fields the
 * detail adapter reads, cast to `State`.
 */
export function stateByIdQuery(stateId: string): string {
  return `select states.id as id, states.name as name, states.workspace as workspace,
  states.group_id as group_id, states.created_at as created_at, states.updated_at as updated_at
from states
where states.id = ${sqlLiteral(stateId)} and states.deleted_at is null
limit 1`;
}

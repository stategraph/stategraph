// MQL queries for the shared app-shell contexts (#1076).
//
// StateContext (the states list behind ~13 screens) and TenantContext (the
// tenant switcher) previously read dedicated REST endpoints (`getTenantStates` /
// `getUserTenants`). Under the "all reads via MQL" policy they run through
// `/api/v1/mql` instead. Both are plain tenant-scoped reads of allow-listed
// tables; the explicit LIMIT dodges the endpoint's default-20 cap — the #1063
// ">20 states hard-fails" failure mode.
//
// Engine idioms: scoped tables (`states`/`tenants`) are referenced by BARE NAME
// with comma-FROM + WHERE. The MQL `tenants` CTE is already self-scoped to the
// caller's memberships (via `tenant_users`); `states` is filtered explicitly by
// tenant so the tenant switcher stays correct across tenants.

import { sqlLiteral } from '@/lib/mql/escape';

// Cap far above any realistic tenant; the explicit limit is what avoids the
// `/api/v1/mql` default-20 truncation.
const LIST_LIMIT = 1000;

/**
 * All non-deleted states for one tenant, ordered by name — the StateContext
 * list read (replaces `getTenantStates`). Rows are cast to `State[]`; the
 * client-derived presentation (status / source / blast radius) is applied
 * downstream by the state adapters, unchanged.
 */
export function statesListQuery(tenantId: string): string {
  return `select states.id as id, states.name as name, states.workspace as workspace,
  states.group_id as group_id, states.created_at as created_at, states.updated_at as updated_at
from states
where states.tenant_id = ${sqlLiteral(tenantId)}
  and states.deleted_at is null
order by states.name
limit ${LIST_LIMIT}`;
}

/**
 * The caller's tenants — the TenantContext switcher read (replaces
 * `getUserTenants`). The MQL `tenants` CTE is already self-scoped to the
 * caller's memberships (via `tenant_users`), so no explicit filter is needed.
 * Rows are cast to `Tenant[]` (only `id`/`name` are in the type).
 */
export function tenantsListQuery(): string {
  return `select tenants.id as id, tenants.name as name
from tenants
order by tenants.name
limit ${LIST_LIMIT}`;
}

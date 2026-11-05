// MQL query for the Billing Connections page (#1080).
//
// listBillingSources previously read a dedicated REST endpoint
// (GET /api/v1/tenants/{tenant_id}/billing-sources). Under the "all reads via
// MQL" policy it runs through /api/v1/mql instead, against the newly
// allow-listed, tenant-scoped `focus_billing_sources` table. That table holds no
// secret/credential columns (credentials resolve ambiently via DuckDB's
// credential_chain), so every field is projected unmasked. The write paths
// (create / update / delete / sync) stay on REST.

import type { BillingSource } from "@/lib/api/client";

// Cap far above any realistic per-tenant source count; the explicit limit avoids
// the /api/v1/mql default-20 truncation.
const LIST_LIMIT = 1000;

/** Escape a value for a single-quoted SQL string literal. */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** One row from billingSourcesQuery, mirroring the selected columns. */
export interface BillingSourceRow {
  id: string;
  tenant_id: string;
  provider: string;
  source_uri: string;
  region: string | null;
  window_months: number;
  enabled: boolean;
  last_status: string | null;
  last_error: string | null;
  last_synced_at: string | null;
  last_row_count: number | null;
  created_at: string;
  updated_at: string;
}

/**
 * All billing sources for one tenant, newest first — the listBillingSources read.
 * The `focus_billing_sources` MQL CTE is already scoped to the caller's tenants,
 * but we also filter by tenant_id to pin the result to the current tenant, as
 * the REST endpoint (which took tenant_id in the path) did.
 */
export function billingSourcesQuery(tenantId: string): string {
  return `select id, tenant_id, provider, source_uri, region, window_months, enabled,
  last_status, last_error, last_synced_at, last_row_count, created_at, updated_at
from focus_billing_sources
where tenant_id = ${sqlLiteral(tenantId)}
order by created_at desc
limit ${LIST_LIMIT}`;
}

/** Convert an MQL row into the BillingSource shape (SQL nulls -> undefined). */
export function billingSourceRowToBillingSource(row: BillingSourceRow): BillingSource {
  return {
    id: row.id,
    tenant_id: row.tenant_id,
    provider: row.provider,
    source_uri: row.source_uri,
    region: row.region ?? undefined,
    window_months: row.window_months,
    enabled: row.enabled,
    last_status: row.last_status ?? undefined,
    last_error: row.last_error ?? undefined,
    last_synced_at: row.last_synced_at ?? undefined,
    last_row_count: row.last_row_count ?? undefined,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

/**
 * JSON export for the tenant resource-type breakdown.
 *
 * The numbers here are consumed for billing, so the export is not allowed to
 * quietly ship a partial file. Two properties make that checkable:
 *
 *   1. The endpoint is NOT paginated — `GET /api/v1/tenants/{id}/resource-types`
 *      returns every row in one response, so there is no cursor to walk and no
 *      page to drop. Completeness is structural rather than a loop invariant.
 *   2. The response carries its own totals, computed server-side over the same
 *      rows. `reconcile` re-derives them from the rows in the file and refuses
 *      to build an export when the two disagree — so a row lost anywhere between
 *      the database and the file is a thrown error, not a smaller number.
 *
 * Rows also carry `state_name`, so the file is readable offline without
 * resolving state ids against the paginated states list (the #1063 trap).
 */

import { TenantResourceTypes, getTenantResourceTypes } from '@/lib/api/client';
import { downloadFile } from '@/lib/export';

/** Identifies the file's shape to whatever consumes it downstream. */
export const EXPORT_SCHEMA = 'stategraph.resource-types.v1';

export type ResourceTypeRow = TenantResourceTypes['resource_types'][number];

export interface ResourceTypesExport {
  schema: typeof EXPORT_SCHEMA;
  exported_at: string;
  tenant_id: string;
  /** Every state in the tenant. The export deliberately ignores the on-screen filter. */
  scope: 'all-states';
  row_count: number;
  total_resources: number;
  total_instances: number;
  resource_types: ResourceTypeRow[];
}

export class ExportReconciliationError extends Error {
  constructor(
    readonly field: 'total_resources' | 'total_instances',
    readonly reported: number,
    readonly summed: number,
  ) {
    super(
      `resource-types export failed reconciliation: the server reported ${field}=${reported}, ` +
        `but the ${field === 'total_resources' ? 'resource_count' : 'instance_count'} values in ` +
        `the exported rows sum to ${summed}. Refusing to write a file that does not add up.`,
    );
    this.name = 'ExportReconciliationError';
  }
}

const sumBy = (rows: ResourceTypeRow[], pick: (row: ResourceTypeRow) => number): number =>
  rows.reduce((acc, row) => acc + pick(row), 0);

/**
 * Throw unless the rows add up to the totals the server reported alongside them.
 *
 * This is the whole safety argument of the export: the totals are computed on
 * the server from the same query, so a mismatch means rows went missing (or were
 * duplicated) on the way here. Silence would look like a smaller bill.
 */
export function reconcile(data: TenantResourceTypes): void {
  const resources = sumBy(data.resource_types, (row) => row.resource_count);
  if (resources !== data.total_resources) {
    throw new ExportReconciliationError('total_resources', data.total_resources, resources);
  }
  const instances = sumBy(data.resource_types, (row) => row.instance_count);
  if (instances !== data.total_instances) {
    throw new ExportReconciliationError('total_instances', data.total_instances, instances);
  }
}

/** Build the export payload from a whole-tenant response. Reconciles first. */
export function buildResourceTypesExport(
  data: TenantResourceTypes,
  meta: { tenantId: string; exportedAt: string },
): ResourceTypesExport {
  reconcile(data);
  return {
    schema: EXPORT_SCHEMA,
    exported_at: meta.exportedAt,
    tenant_id: meta.tenantId,
    scope: 'all-states',
    row_count: data.resource_types.length,
    total_resources: data.total_resources,
    total_instances: data.total_instances,
    resource_types: data.resource_types,
  };
}

export function exportFilename(tenantId: string, exportedAt: string): string {
  return `resource-types-${tenantId}-${exportedAt.replace(/[:.]/g, '-')}.json`;
}

/**
 * Re-fetch the WHOLE tenant and download it as JSON.
 *
 * The fetch is deliberately unfiltered and deliberately fresh: exporting the
 * component's current state would ship whatever the on-screen state filter had
 * narrowed it to, and whatever was loaded before the last change.
 */
export async function exportResourceTypesAsJSON(
  tenantId: string,
  now: () => string = () => new Date().toISOString(),
): Promise<ResourceTypesExport> {
  const data = await getTenantResourceTypes(tenantId);
  const exportedAt = now();
  const payload = buildResourceTypesExport(data, { tenantId, exportedAt });
  downloadFile(
    JSON.stringify(payload, null, 2),
    exportFilename(tenantId, exportedAt),
    'application/json',
  );
  return payload;
}

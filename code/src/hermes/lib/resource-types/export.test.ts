/**
 * Unit tests for the resource-type JSON export.
 *
 * The export feeds billing, so these pin the two ways a file could be wrong:
 * rows missing from it, and totals that do not describe the rows it holds.
 */
import {
  EXPORT_SCHEMA,
  ExportReconciliationError,
  buildResourceTypesExport,
  exportFilename,
  reconcile,
  type ResourceTypeRow,
} from './export';
import type { TenantResourceTypes } from '@/lib/api/client';

const row = (
  state_id: string,
  state_name: string,
  type: string,
  resource_count: number,
  instance_count: number,
): ResourceTypeRow => ({ state_id, state_name, type, resource_count, instance_count });

/** A response whose totals are, by construction, the sums of its rows. */
const consistent = (rows: ResourceTypeRow[]): TenantResourceTypes => ({
  resource_types: rows,
  total_resources: rows.reduce((a, r) => a + r.resource_count, 0),
  total_instances: rows.reduce((a, r) => a + r.instance_count, 0),
});

const META = { tenantId: 'tenant-1', exportedAt: '2026-08-26T00:00:00.000Z' };

const threw = (fn: () => unknown): unknown => {
  try {
    fn();
  } catch (e) {
    return e;
  }
  return null;
};

const rows = [
  row('s1', 'prod', 'aws_instance', 2, 5),
  row('s1', 'prod', 'aws_s3_bucket', 2, 2),
  row('s2', 'staging', 'aws_instance', 1, 1),
];

const tests: { name: string; fn: () => boolean }[] = [
  {
    name: 'every row survives into the file, in order',
    fn: () => {
      const out = buildResourceTypesExport(consistent(rows), META);
      return (
        out.resource_types.length === rows.length &&
        out.resource_types.every((r, i) => JSON.stringify(r) === JSON.stringify(rows[i]))
      );
    },
  },
  {
    name: 'row_count matches the number of rows written',
    fn: () => buildResourceTypesExport(consistent(rows), META).row_count === rows.length,
  },
  {
    name: 'totals in the file equal the sum of the rows in the file',
    fn: () => {
      const out = buildResourceTypesExport(consistent(rows), META);
      return (
        out.total_resources === out.resource_types.reduce((a, r) => a + r.resource_count, 0) &&
        out.total_instances === out.resource_types.reduce((a, r) => a + r.instance_count, 0)
      );
    },
  },
  {
    name: 'a dropped row is refused, not silently exported',
    fn: () => {
      // The server's totals describe three rows; only two arrive.
      const truncated: TenantResourceTypes = { ...consistent(rows), resource_types: rows.slice(0, 2) };
      const e = threw(() => buildResourceTypesExport(truncated, META));
      return e instanceof ExportReconciliationError && e.field === 'total_resources';
    },
  },
  {
    name: 'a dropped row that keeps resource_count balanced is still caught on instances',
    fn: () => {
      // Contrived so total_resources reconciles and only the instance total does not:
      // the missing row carries 0 resources but 4 instances.
      const withZero = [...rows, row('s3', 'edge', 'aws_lambda_function', 0, 4)];
      const data: TenantResourceTypes = { ...consistent(withZero), resource_types: rows };
      const e = threw(() => buildResourceTypesExport(data, META));
      return e instanceof ExportReconciliationError && e.field === 'total_instances';
    },
  },
  {
    name: 'a duplicated row is refused too',
    fn: () => {
      const data: TenantResourceTypes = { ...consistent(rows), resource_types: [...rows, rows[0]] };
      return threw(() => buildResourceTypesExport(data, META)) instanceof ExportReconciliationError;
    },
  },
  {
    name: 'an empty tenant exports cleanly with zero totals',
    fn: () => {
      const out = buildResourceTypesExport(consistent([]), META);
      return out.row_count === 0 && out.total_resources === 0 && out.total_instances === 0;
    },
  },
  {
    name: 'reconcile accepts a large consistent set',
    fn: () => {
      const many: ResourceTypeRow[] = [];
      for (let s = 0; s < 200; s++) {
        for (let t = 0; t < 25; t++) {
          many.push(row(`s${s}`, `state-${s}`, `type_${t}`, t + 1, (t + 1) * 3));
        }
      }
      const out = buildResourceTypesExport(consistent(many), META);
      return out.row_count === 5000 && out.total_instances === out.resource_types.reduce((a, r) => a + r.instance_count, 0);
    },
  },
  {
    name: 'scope records that the file covers every state',
    fn: () => buildResourceTypesExport(consistent(rows), META).scope === 'all-states',
  },
  {
    name: 'schema tag is stamped',
    fn: () => buildResourceTypesExport(consistent(rows), META).schema === EXPORT_SCHEMA,
  },
  {
    name: 'reconcile is a no-op on a consistent response',
    fn: () => threw(() => reconcile(consistent(rows))) === null,
  },
  {
    name: 'filename carries the tenant and a filesystem-safe timestamp',
    fn: () => exportFilename('t1', '2026-08-26T00:00:00.000Z') === 'resource-types-t1-2026-08-26T00-00-00-000Z.json',
  },
];

let passed = 0;
let failed = 0;
for (const t of tests) {
  let ok = false;
  try {
    ok = t.fn();
  } catch (e) {
    ok = false;
    console.log(`  threw: ${e instanceof Error ? e.message : String(e)}`);
  }
  console.log(`${ok ? 'PASS' : 'FAIL'}: ${t.name}`);
  if (ok) passed++;
  else failed++;
}
console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
process.exit(failed === 0 ? 0 : 1);

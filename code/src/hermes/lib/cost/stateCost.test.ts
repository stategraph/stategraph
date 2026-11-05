/**
 * Tests for the per-state cost MQL queries + unsupported derivation (#1069 A).
 * Run with: npx tsx lib/cost/stateCost.test.ts
 */

import { stateCostTotalsQuery, stateCostResourcesQuery, deriveUnsupported } from './stateCost';
import type { StateCosts } from '@/lib/api/client';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing per-state cost MQL queries\n' + '='.repeat(60));

// --- totals query -----------------------------------------------------------
const t = stateCostTotalsQuery('s1');
check('totals: latest-per-state CTE (max calculated_at)', /latest as \(\s*select state_id, max\(calculated_at\)/.test(t));
check('totals: only current snapshots', (t.match(/kind = 'current'/g) || []).length >= 2);
check('totals: scoped to the state', t.includes("state_id = 's1'"));
check('totals: comma-FROM with explicit AS alias (MQL idiom)', t.includes('from cost_snapshots as cs, latest'));
check('totals: one row', t.includes('limit 1'));
check('totals: projects the snapshot fields',
  ['cs.id', 'cs.calculated_at', 'cs.currency', 'cs.monthly_cost', 'cs.hourly_cost',
   'cs.resource_count', 'cs.supported_count', 'cs.priced_count', 'cs.source', 'cs.triggered_by'].every((c) => t.includes(c)));
check('totals: escapes the state id', stateCostTotalsQuery("x'; drop--").includes("state_id = 'x''; drop--'"));

// --- resources query --------------------------------------------------------
const r = stateCostResourcesQuery('snap1');
check('resources: scoped to the snapshot', r.includes("snapshot_id = 'snap1'"));
check('resources: ordered by address', r.includes('order by address'));
check('resources: carries an explicit page limit (avoids default-20; cursors past)', /limit \d+/.test(r));
check('resources: projects breakdown columns',
  ['address', 'type', 'provider', 'region', 'supported', 'no_price', 'monthly_cost', 'hourly_cost', 'components', 'tags', 'cloud_resource_id'].every((c) => r.includes(c)));
check('resources: escapes the snapshot id', stateCostResourcesQuery("x'--").includes("snapshot_id = 'x''--'"));

// --- deriveUnsupported -------------------------------------------------------
const costs: StateCosts = {
  snapshot_id: 'snap1', calculated_at: '2026-07-09T00:00:00Z', currency: 'USD',
  resource_count: 3, supported_count: 2, priced_count: 1, coverage_percent: 33,
  source: 'schedule', triggered_by: 'system',
  instance_costs: [
    { address: 'aws_instance.a', type: 'aws_instance', supported: true, no_price: false, monthly_cost: '10' },
    { address: 'aws_foo.b', type: 'aws_foo', supported: false, no_price: false },       // unsupported type
    { address: 'aws_iam_role.c', type: 'aws_iam_role', supported: true, no_price: true }, // supported but free
  ],
};
const uns = deriveUnsupported(costs);
check('unsupported: keeps snapshot_id + calculated_at', uns.snapshot_id === 'snap1' && uns.calculated_at === costs.calculated_at);
check('unsupported: includes unsupported-type AND no-price rows only',
  uns.resources.length === 2 &&
  uns.resources.some((x) => x.address === 'aws_foo.b') &&
  uns.resources.some((x) => x.address === 'aws_iam_role.c'));
check('unsupported: excludes the priced/supported row', !uns.resources.some((x) => x.address === 'aws_instance.a'));
check('unsupported: projects the gap fields', uns.resources.every((x) => 'address' in x && 'type' in x && 'supported' in x && 'no_price' in x));

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

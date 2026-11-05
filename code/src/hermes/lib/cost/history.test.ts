/**
 * Tests for the state cost-history MQL query (#1066).
 * Run with: npx tsx lib/cost/history.test.ts
 */

import { stateCostHistoryQuery } from './history';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing state cost-history MQL query\n' + '='.repeat(60));

const q = stateCostHistoryQuery('s1', '2026-01-01T00:00:00Z', '2026-06-30T00:00:00Z', 1000);

check('scoped to the state', q.includes("state_id = 's1'"));
check('only current snapshots', q.includes("kind = 'current'"));
check('lower window bound', q.includes("calculated_at >= '2026-01-01T00:00:00Z'"));
check('upper window bound', q.includes("calculated_at <= '2026-06-30T00:00:00Z'"));
check('keyset order (calculated_at, id) ascending, oldest-first', q.includes('order by calculated_at, id'));
check('page limit present (not the old fixed 30 cap)', q.includes('limit 1000') && !/limit 30\b/.test(q));
check('projects the history point fields',
  ['id', 'calculated_at', 'currency', 'monthly_cost', 'hourly_cost', 'resource_count', 'priced_count', 'triggered_by'].every((c) => q.includes(c)));
check('escapes the state id', stateCostHistoryQuery("x'; drop--", 'a', 'b', 10).includes("state_id = 'x''; drop--'"));
check('escapes the window timestamps', stateCostHistoryQuery('s', "a'b", "c'd", 10).includes("calculated_at >= 'a''b'") &&
  stateCostHistoryQuery('s', "a'b", "c'd", 10).includes("calculated_at <= 'c''d'"));

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

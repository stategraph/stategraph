/**
 * Tests for the all-states modules MQL query (#1073 modules slice / #1062).
 * Run with: npx tsx "app/(console)/modules/mqlQueries.test.ts"
 */

import { allStatesModulesQuery, rowToModule, type ModuleRow } from './mqlQueries';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing all-states modules MQL query\n' + '='.repeat(60));

const q = allStatesModulesQuery();

// --- MQL count() constraint: only count(*) is legal --------------------------
check('uses count(*) aggregates', q.includes('count(*)'));
check('does NOT use count(distinct ...) (MQL rejects it)', !/count\s*\(\s*distinct/i.test(q));
check('does NOT use count(<column>) (MQL rejects it)', !/count\s*\(\s*(?!\*)[a-z]/i.test(q));

// --- Two-CTE shape: resource_count from resources, instance_count from join --
check('has a resources-only CTE for resource_count',
  /mods as \(/.test(q) && q.includes('as resource_count'));
check('has an instances-joined CTE for instance_count',
  /insts as \(/.test(q) && q.includes('as instance_count') && q.includes('instances.resource_address = resources.address'));
check('joins the two CTEs on module name', q.includes('where insts.module = mods.module'));

// --- Aggregation scope -------------------------------------------------------
check('groups by module', /group by resources\.module/.test(q));
check('excludes the root module (module is not null)', q.includes('resources.module is not null'));
check('filters out deleted states', q.includes('states.deleted_at is null'));
check('has NO single-state filter (aggregates every state)', !/states\.id = '/.test(q));
check('orders by module name', q.includes('order by mods.module'));
check('carries an explicit limit (guards default-limit truncation)', /limit \d+/.test(q));

// --- Row mapping -------------------------------------------------------------
const row: ModuleRow = { module: 'module.networking', resource_count: 695, instance_count: 700 };
const m = rowToModule(row);
check('maps module -> name', m.name === 'module.networking');
check('maps resource_count', m.resource_count === 695);
check('maps instance_count', m.instance_count === 700);
// string/undefined counts coerced to numbers (MQL returns numeric-as-is, be safe)
const coerced = rowToModule({ module: 'm', resource_count: '3' as unknown as number, instance_count: undefined as unknown as number });
check('coerces string count to number', coerced.resource_count === 3);
check('coerces missing count to 0', coerced.instance_count === 0);

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

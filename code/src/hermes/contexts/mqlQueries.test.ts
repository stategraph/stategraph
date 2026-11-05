/**
 * Tests for the app-shell context MQL queries (#1076).
 * Run with: npx tsx contexts/mqlQueries.test.ts
 */

import { statesListQuery, tenantsListQuery } from './mqlQueries';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing app-shell context MQL queries\n' + '='.repeat(60));

const TID = 'tenant-abc';
const s = statesListQuery(TID);
const t = tenantsListQuery();

// --- states list -------------------------------------------------------------
check('states scopes to the given tenant', s.includes(`states.tenant_id = '${TID}'`));
check('states excludes deleted', s.includes('states.deleted_at is null'));
check('states ordered by name', s.includes('order by states.name'));
check('states carries an explicit limit (dodges default-20 → #1063)', /limit \d+/.test(s));
check('states projects the fields the State type/adapter needs',
  ['id', 'name', 'workspace', 'group_id', 'created_at', 'updated_at'].every((f) => s.includes(`as ${f}`)));
check('states escapes single quotes in the tenant id',
  statesListQuery("x'; drop table states; --").includes("states.tenant_id = 'x''; drop table states; --'"));

// --- tenants list ------------------------------------------------------------
check('tenants selects id + name', t.includes('tenants.id as id') && t.includes('tenants.name as name'));
check('tenants is self-scoped (no explicit tenant filter needed)', !/tenant_id/.test(t));
check('tenants carries an explicit limit', /limit \d+/.test(t));
check('tenants ordered by name', t.includes('order by tenants.name'));

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

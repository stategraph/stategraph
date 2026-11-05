/**
 * Tests for the query-editor autocomplete MQL query (#1078).
 * Run with: npx tsx "app/(console)/query/mqlQueries.test.ts"
 */

import { resourceTypesQuery } from './mqlQueries';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing query-editor autocomplete MQL query\n' + '='.repeat(60));

const SID = 'abc-123';
const q = resourceTypesQuery(SID);

check('selects resources.type', q.includes('resources.type as type'));
check('scopes to the given state', q.includes(`states.id = '${SID}'`));
check('excludes deleted states', q.includes('states.deleted_at is null'));
check('groups by type (distinct)', q.includes('group by resources.type'));
check('ordered for stable suggestions', q.includes('order by resources.type'));
check('carries an explicit limit (dodges default-20)', /limit \d+/.test(q));
check('does not select provider (derived client-side from the type prefix)',
  !q.includes('resources.provider'));
check('escapes single quotes in the state id',
  resourceTypesQuery("x'; drop table resources; --").includes("states.id = 'x''; drop table resources; --'"));

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

/**
 * Tests for the server-side chart aggregation query builder (#1055).
 * Run with: npx tsx lib/analytics/aggregationQuery.test.ts
 */

import { buildAggregationQuery, AGG_LIMIT } from './aggregationQuery';
import type { WhereCondition } from '@/app/(console)/query/compiler';

let passed = 0;
let failed = 0;

function check(name: string, cond: boolean) {
  if (cond) {
    console.log(`✓ ${name}`);
    passed++;
  } else {
    console.error(`✗ ${name}`);
    failed++;
  }
}

const S = 's1';

// --- Group-by per dimension ------------------------------------------------
for (const [dim, col] of Object.entries({
  type: 'resources.type',
  provider: 'resources.provider',
  module: 'resources.module',
  address: 'instances.address',
})) {
  const q = buildAggregationQuery({ stateId: S, dimensionField: dim, where: [] });
  check(`${dim} -> group by ${col}`, q !== null && q.includes(`${col} as dimension`) && q.includes(`group by ${col}`));
}

const base = buildAggregationQuery({ stateId: S, dimensionField: 'type', where: [] })!;
check('scopes to the state', base.includes(`resources.state_id = 's1'`));
check('joins instances to resources', base.includes('instances.resource_address = resources.address'));
check('counts with count(*)', base.includes('count(*) as cnt'));
check('orders by count desc', base.includes('order by count(*) desc'));
check('caps distinct dimension values', base.includes(`limit ${AGG_LIMIT}`));

// --- WHERE translation -----------------------------------------------------
const eq = buildAggregationQuery({
  stateId: S,
  dimensionField: 'type',
  where: [{ field: 'provider', operator: '=', value: 'aws' }],
})!;
check('= translates', eq.includes(`resources.provider = 'aws'`));

const neq = buildAggregationQuery({
  stateId: S,
  dimensionField: 'type',
  where: [{ field: 'module', operator: '!=', value: 'root' }],
})!;
check('!= translates', neq.includes(`resources.module != 'root'`));

const like = buildAggregationQuery({
  stateId: S,
  dimensionField: 'type',
  where: [{ field: 'type', operator: 'LIKE', value: '%bucket%' }],
})!;
check('LIKE -> ilike (was dropped before)', like.includes(`resources.type ilike '%bucket%'`));

const inList = buildAggregationQuery({
  stateId: S,
  dimensionField: 'type',
  where: [{ field: 'provider', operator: 'IN', value: ['aws', 'gcp'] }],
})!;
check('IN -> full list (was first-value-only before)', inList.includes(`resources.provider in ('aws', 'gcp')`));

const escaped = buildAggregationQuery({
  stateId: S,
  dimensionField: 'type',
  where: [{ field: 'type', operator: '=', value: "a'b" }],
})!;
check('single quotes escaped', escaped.includes(`resources.type = 'a''b'`));

// --- Scalar COUNT(*) -------------------------------------------------------
const scalar = buildAggregationQuery({
  stateId: S,
  dimensionField: 'count',
  where: [],
  aggregation: { type: 'COUNT', field: '*' },
});
check('COUNT(*) -> scalar count, no group by', scalar !== null && scalar.includes('count(*) as cnt') && !scalar.includes('group by'));

// --- Unsupported shapes -> null -------------------------------------------
check('exotic dimension -> null', buildAggregationQuery({ stateId: S, dimensionField: 'attributes', where: [] }) === null);
check('COUNT(field) -> null', buildAggregationQuery({ stateId: S, dimensionField: 'x', where: [], aggregation: { type: 'COUNT', field: 'provider' } }) === null);
const badWhere: WhereCondition[] = [{ field: 'tags', operator: '=', value: 'x' }];
check('WHERE on unknown field -> null', buildAggregationQuery({ stateId: S, dimensionField: 'type', where: badWhere }) === null);

console.log(`\nTests: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

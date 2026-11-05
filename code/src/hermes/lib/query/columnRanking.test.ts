/**
 * Tests for Column Ranking Logic
 * Run with: npx tsx lib/query/columnRanking.test.ts
 */

import { rankColumns, isSelectAllQuery } from './columnRanking';

interface TestCase {
  name: string;
  test: () => void;
}

const tests: TestCase[] = [
  {
    name: 'should prioritize identity columns (address, name, type)',
    test: () => {
      const columns = ['created_at', 'address', 'state_id', 'name', 'type', 'private'];
      const ranked = rankColumns(columns, [], 10);

      // Top 3 should be identity columns (name is shorter so comes first)
      const top3 = ranked.slice(0, 3);
      if (!top3.includes('address')) throw new Error('Expected address in top 3');
      if (!top3.includes('name')) throw new Error('Expected name in top 3');
      if (!top3.includes('type')) throw new Error('Expected type in top 3');
    },
  },
  {
    name: 'should de-prioritize internal UUID and timestamp columns',
    test: () => {
      const columns = ['address', 'state_id', 'tenant_id', 'created_at', 'type'];
      const ranked = rankColumns(columns, [], 10);

      const lastThree = ranked.slice(-3);
      if (!lastThree.includes('state_id')) throw new Error('Expected state_id to be in last three');
      if (!lastThree.includes('tenant_id')) throw new Error('Expected tenant_id to be in last three');
      if (!lastThree.includes('created_at')) throw new Error('Expected created_at to be in last three');
    },
  },
  {
    name: 'should prioritize Stategraph graph columns (module, provider, workspace)',
    test: () => {
      const columns = ['state_id', 'module', 'provider', 'created_at', 'workspace', 'mode'];
      const ranked = rankColumns(columns, [], 10);

      const topFour = ranked.slice(0, 4);
      if (!topFour.includes('module')) throw new Error('Expected module in top 4');
      if (!topFour.includes('provider')) throw new Error('Expected provider in top 4');
      if (!topFour.includes('workspace')) throw new Error('Expected workspace in top 4');
      if (!topFour.includes('mode')) throw new Error('Expected mode in top 4');
    },
  },
  {
    name: 'should respect the limit parameter',
    test: () => {
      const columns = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];
      const ranked = rankColumns(columns, [], 5);

      if (ranked.length !== 5) throw new Error(`Expected 5 columns, got ${ranked.length}`);
    },
  },
  {
    name: 'should penalize columns that are mostly null',
    test: () => {
      const columns = ['address', 'empty_col', 'type'];
      const rows = [
        { address: 'foo', empty_col: null, type: 'aws' },
        { address: 'bar', empty_col: null, type: 'gcp' },
        { address: 'baz', empty_col: null, type: 'azure' },
      ];

      const ranked = rankColumns(columns, rows, 10);

      if (ranked[ranked.length - 1] !== 'empty_col') {
        throw new Error(`Expected empty_col to be last, got ${ranked[ranked.length - 1]}`);
      }
    },
  },
  {
    name: 'should be deterministic',
    test: () => {
      const columns = ['z', 'a', 'm', 'b', 'y', 'c'];
      const rows = [{ z: 1, a: 2, m: 3, b: 4, y: 5, c: 6 }];

      const ranked1 = rankColumns(columns, rows, 10);
      const ranked2 = rankColumns(columns, rows, 10);
      const ranked3 = rankColumns(columns, rows, 10);

      if (JSON.stringify(ranked1) !== JSON.stringify(ranked2)) {
        throw new Error('Results are not deterministic');
      }
      if (JSON.stringify(ranked2) !== JSON.stringify(ranked3)) {
        throw new Error('Results are not deterministic');
      }
    },
  },
  {
    name: 'should use column name as tie-breaker for same-length columns',
    test: () => {
      // Use same-length columns so they have identical scores
      const columns = ['zulu', 'alfa', 'mike'];
      const ranked = rankColumns(columns, [], 10);

      // All have same score (50 - length penalty), should sort alphabetically
      if (JSON.stringify(ranked) !== JSON.stringify(['alfa', 'mike', 'zulu'])) {
        throw new Error(`Expected alphabetical order, got ${JSON.stringify(ranked)}`);
      }
    },
  },
  {
    name: 'should handle realistic instances table columns',
    test: () => {
      // All actual columns from instances table
      const columns = [
        'address', 'attributes', 'deposed', 'identity',
        'identity_schema_version', 'index_key', 'private', 'resource_address',
        'schema_version', 'sensitive_attributes', 'state_id', 'status',
      ];

      const ranked = rankColumns(columns, [], 7);

      // Should include high-priority columns
      if (!ranked.includes('address')) throw new Error('Expected address in top 7');
      if (!ranked.includes('status')) throw new Error('Expected status in top 7');
      if (!ranked.includes('resource_address')) throw new Error('Expected resource_address in top 7');

      // Should NOT include low-priority columns
      if (ranked.includes('state_id')) throw new Error('Did not expect state_id in top 7');
      if (ranked.includes('schema_version')) throw new Error('Did not expect schema_version in top 7');
      if (ranked.includes('private')) throw new Error('Did not expect private in top 7');
    },
  },
  {
    name: 'should prioritize count in aggregation results',
    test: () => {
      const columns = ['type', 'count', 'created_at'];
      const ranked = rankColumns(columns, [], 10);

      // count should be highly ranked (score 100) for aggregations
      const top2 = ranked.slice(0, 2);
      if (!top2.includes('count')) throw new Error('Expected count in top 2');
      if (!top2.includes('type')) throw new Error('Expected type in top 2');
    },
  },
  {
    name: 'should prioritize resources table columns correctly',
    test: () => {
      // Actual resources table columns
      const columns = ['address', 'mode', 'module', 'name', 'provider', 'state_id', 'type'];
      const ranked = rankColumns(columns, [], 5);

      // Top 5 should be the useful ones
      const top5 = ranked.slice(0, 5);
      if (!top5.includes('address')) throw new Error('Expected address in top 5');
      if (!top5.includes('name')) throw new Error('Expected name in top 5');
      if (!top5.includes('type')) throw new Error('Expected type in top 5');
      if (!top5.includes('module')) throw new Error('Expected module in top 5');
      if (!top5.includes('provider')) throw new Error('Expected provider in top 5');

      // state_id should NOT be in top 5
      if (top5.includes('state_id')) throw new Error('Did not expect state_id in top 5');
    },
  },
  {
    name: 'isSelectAllQuery should detect SELECT *',
    test: () => {
      if (!isSelectAllQuery('SELECT * FROM instances')) throw new Error('Failed to detect SELECT *');
      if (!isSelectAllQuery('select * from resources')) throw new Error('Failed to detect select *');
      if (!isSelectAllQuery('SELECT instances.* FROM instances')) throw new Error('Failed to detect table.*');
    },
  },
  {
    name: 'isSelectAllQuery should NOT detect specific columns',
    test: () => {
      if (isSelectAllQuery('SELECT address, type FROM instances')) {
        throw new Error('Incorrectly detected specific columns');
      }
      if (isSelectAllQuery('SELECT COUNT(*) FROM instances')) {
        throw new Error('Incorrectly detected COUNT(*)');
      }
    },
  },
];

// Run tests
if (require.main === module) {
  console.log('Running column ranking tests...\n');

  let passed = 0;
  let failed = 0;

  for (const testCase of tests) {
    try {
      testCase.test();
      console.log(`✓ ${testCase.name}`);
      passed++;
    } catch (error) {
      console.error(`✗ ${testCase.name}`);
      console.error(`  ${error instanceof Error ? error.message : String(error)}`);
      failed++;
    }
  }

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

/**
 * Tests for DashboardChartCard query execution consistency
 *
 * This test ensures that visualizations render with the same data
 * whether viewed standalone or embedded in a dashboard.
 */

import { compileSQL } from './compiler';
const tests = [
  {
    name: 'should not apply ensureTagQuery normalization to compiled queries',
    fn: () => {
      const bareSearchQuery = 'SELECT * FROM instances WHERE address LIKE "ecs_cluster"';
      const compiled = compileSQL(bareSearchQuery);

      if (!compiled.success || !compiled.parsed) {
        throw new Error('Compilation failed');
      }

      const qString = compiled.parsed.qString || '';

      if (qString.includes('ecs_cluster')) {
        const hasORExpansion = (qString.match(/\bOR\b/g) || []).length > 5;
        if (hasORExpansion) {
          throw new Error('Query was incorrectly expanded with OR operators');
        }
      }
    }
  },
  {
    name: 'should preserve exact query string from compiler output',
    fn: () => {
      const fieldQuery = 'SELECT * FROM instances WHERE type = "aws_instance"';
      const compiled = compileSQL(fieldQuery);

      if (!compiled.success) {
        throw new Error('Compilation failed');
      }

      if (compiled.parsed?.qString !== 'type:aws_instance') {
        throw new Error(`Expected 'type:aws_instance', got '${compiled.parsed?.qString}'`);
      }
    }
  },
  {
    name: 'should preserve AND/OR logic in compiled queries',
    fn: () => {
      const complexQuery = 'SELECT * FROM instances WHERE type = "aws_instance" AND provider = "aws"';
      const compiled = compileSQL(complexQuery);

      if (!compiled.success || !compiled.parsed) {
        throw new Error('Compilation failed');
      }

      const qString = compiled.parsed.qString || '';

      if (!qString.includes('type:aws_instance') || !qString.includes('provider:aws')) {
        throw new Error(`Query string missing expected terms: ${qString}`);
      }
    }
  }
];

// Execute tests
let passed = 0;
let failed = 0;

console.log('Running DashboardChartCard query consistency tests...\n');

for (const test of tests) {
  try {
    test.fn();
    console.log(`✓ ${test.name}`);
    passed++;
  } catch (error) {
    console.log(`✗ ${test.name}`);
    console.log(`  Error: ${error instanceof Error ? error.message : String(error)}`);
    failed++;
  }
}

console.log(`\n${passed} passed, ${failed} failed`);

if (failed > 0) {
  process.exit(1);
}

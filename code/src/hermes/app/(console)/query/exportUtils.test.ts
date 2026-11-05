/**
 * Tests for export utilities
 * Run with: npx tsx exportUtils.test.ts
 */

import { convertToCSV, convertToJSON } from './exportUtils';

interface TestCase {
  name: string;
  data: Record<string, unknown>[];
  expectedCSV?: string;
  expectedJSONFields?: string[];
}

const testCases: TestCase[] = [
  {
    name: 'Simple data export',
    data: [
      { id: '1', name: 'Resource A', provider: 'aws' },
      { id: '2', name: 'Resource B', provider: 'gcp' },
    ],
    expectedCSV: 'id,name,provider\n1,Resource A,aws\n2,Resource B,gcp',
  },
  {
    name: 'CSV with quotes and commas',
    data: [
      { id: '1', description: 'This has a comma, in it' },
      { id: '2', description: 'This has "quotes" in it' },
    ],
    expectedCSV: 'id,description\n1,"This has a comma, in it"\n2,"This has ""quotes"" in it"',
  },
  {
    name: 'CSV with null and undefined values',
    data: [
      { id: '1', value: null, other: 'test' },
      { id: '2', value: undefined, other: 'test2' },
      { id: '3', value: '', other: 'test3' },
    ],
    expectedCSV: 'id,value,other\n1,,test\n2,,test2\n3,,test3',
  },
  {
    name: 'Empty results',
    data: [],
    expectedCSV: '',
  },
  {
    name: 'Aggregate COUNT result',
    data: [{ count: 42 }],
    expectedCSV: 'count\n42',
  },
  {
    name: 'JSON with metadata',
    data: [
      { id: '1', provider: 'aws' },
      { id: '2', provider: 'gcp' },
    ],
    expectedJSONFields: ['metadata', 'results'],
  },
];

console.log('🧪 Running Export Utilities Tests\n');

let passed = 0;
let failed = 0;

testCases.forEach((test) => {
  console.log(`Testing: ${test.name}`);

  // Test CSV conversion
  if (test.expectedCSV !== undefined) {
    const csv = convertToCSV(test.data);
    if (csv === test.expectedCSV) {
      console.log('  ✅ PASS: CSV conversion correct');
      passed++;
    } else {
      console.log('  ❌ FAIL: CSV conversion mismatch');
      console.log(`     Expected: ${JSON.stringify(test.expectedCSV)}`);
      console.log(`     Got:      ${JSON.stringify(csv)}`);
      failed++;
    }
  }

  // Test JSON conversion
  if (test.expectedJSONFields) {
    const query = "SELECT * FROM instances;";
    const executionTime = 123;
    const json = convertToJSON(test.data, query, executionTime);
    const parsed = JSON.parse(json);

    // Check that all expected fields are present
    const hasAllFields = test.expectedJSONFields.every(field => field in parsed);
    if (hasAllFields) {
      console.log('  ✅ PASS: JSON structure correct');

      // Verify metadata structure
      if (parsed.metadata) {
        const hasQuery = 'query' in parsed.metadata;
        const hasRowCount = 'rowCount' in parsed.metadata;
        const hasExecutionTime = 'executionTimeMs' in parsed.metadata;
        const hasExportedAt = 'exportedAt' in parsed.metadata;

        if (hasQuery && hasRowCount && hasExecutionTime && hasExportedAt) {
          console.log('  ✅ PASS: JSON metadata complete');
          console.log(`     Query: "${parsed.metadata.query}"`);
          console.log(`     Row count: ${parsed.metadata.rowCount}`);
          console.log(`     Execution time: ${parsed.metadata.executionTimeMs}ms`);
          passed++;
        } else {
          console.log('  ❌ FAIL: JSON metadata incomplete');
          failed++;
        }
      }
    } else {
      console.log('  ❌ FAIL: JSON structure missing fields');
      console.log(`     Expected fields: ${test.expectedJSONFields.join(', ')}`);
      console.log(`     Got fields: ${Object.keys(parsed).join(', ')}`);
      failed++;
    }
  }
});

console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${testCases.length * 2} tests`);

if (failed === 0) {
  console.log('🎉 All export tests passed!');
  console.log('\n✅ Features verified:');
  console.log('   • CSV exports with proper escaping');
  console.log('   • Quotes and commas handled correctly');
  console.log('   • Null/undefined values handled');
  console.log('   • JSON exports with metadata');
  console.log('   • Empty results handled');
  console.log('   • Aggregate results supported');
}

process.exit(failed > 0 ? 1 : 0);

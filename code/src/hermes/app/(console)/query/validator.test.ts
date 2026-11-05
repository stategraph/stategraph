/**
 * Quick manual tests for the SQL validator
 * Run with: npx tsx validator.test.ts
 */

import { validateSQL } from './validator';

interface TestCase {
  name: string;
  sql: string;
  shouldBeValid: boolean;
  expectedErrors?: string[];
}

const testCases: TestCase[] = [
  {
    name: 'Valid: Simple SELECT *',
    sql: "SELECT * FROM instances;",
    shouldBeValid: true,
  },
  {
    name: 'Valid: SELECT with single quotes',
    sql: "SELECT * FROM instances WHERE provider = 'aws';",
    shouldBeValid: true,
  },
  {
    name: 'Valid: SELECT with LIKE',
    sql: "SELECT * FROM instances WHERE type LIKE 'aws_iam_%';",
    shouldBeValid: true,
  },
  {
    name: 'Valid: SELECT with AND',
    sql: "SELECT * FROM instances WHERE provider = 'aws' AND type = 'aws_instance';",
    shouldBeValid: true,
  },
  {
    name: 'Valid: Other table names',
    sql: "SELECT * FROM users;",
    shouldBeValid: true,
  },
  {
    name: 'Invalid: Double quotes instead of single',
    sql: 'SELECT * FROM instances WHERE provider = "aws";',
    shouldBeValid: false,
    expectedErrors: ['String literals must use single quotes'],
  },
  {
    name: 'Invalid: Missing FROM clause',
    sql: "SELECT * WHERE provider = 'aws';",
    shouldBeValid: false,
    expectedErrors: ['FROM clause is required'],
  },
  {
    name: 'Invalid: Missing SELECT clause',
    sql: "FROM instances WHERE provider = 'aws';",
    shouldBeValid: false,
    expectedErrors: ['SELECT clause is required'],
  },
  {
    name: 'Invalid: OR operator (not supported)',
    sql: "SELECT * FROM instances WHERE provider = 'aws' OR provider = 'gcp';",
    shouldBeValid: false,
    expectedErrors: ['OR operator is not yet supported'],
  },
  {
    name: 'Valid: Empty query',
    sql: "",
    shouldBeValid: true,
  },
];

console.log('🧪 Running SQL Validator Tests\n');

let passed = 0;
let failed = 0;

testCases.forEach((test) => {
  const result = validateSQL(test.sql);
  const isValid = result.isValid;
  const testPassed = isValid === test.shouldBeValid;

  if (testPassed) {
    console.log(`✅ PASS: ${test.name}`);
    passed++;

    // Additional check for expected errors
    if (test.expectedErrors && result.errors.length > 0) {
      const hasExpectedErrors = test.expectedErrors.every((expectedMsg) =>
        result.errors.some((err) => err.message.includes(expectedMsg))
      );
      if (!hasExpectedErrors) {
        console.log(`   ⚠️  Warning: Expected error messages not found`);
        console.log(`   Expected: ${test.expectedErrors.join(', ')}`);
        console.log(`   Got: ${result.errors.map((e) => e.message).join(', ')}`);
      }
    }
  } else {
    console.log(`❌ FAIL: ${test.name}`);
    console.log(`   Expected: ${test.shouldBeValid ? 'valid' : 'invalid'}`);
    console.log(`   Got: ${isValid ? 'valid' : 'invalid'}`);
    if (result.errors.length > 0) {
      console.log(`   Errors: ${result.errors.map((e) => e.message).join(', ')}`);
    }
    failed++;
  }
});

console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${testCases.length} tests`);

if (failed === 0) {
  console.log('🎉 All tests passed!');
}

process.exit(failed > 0 ? 1 : 0);

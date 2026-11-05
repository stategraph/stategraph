/**
 * Tests for dedicated-slug validation
 * Run with: npx tsx lib/utils/dedicated-slug.test.ts
 */

import { isValidDedicatedSlug, DEDICATED_SLUG_MAX } from './dedicated-slug';

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  { name: 'accepts simple alphanumeric "foobar"', fn: () => isValidDedicatedSlug('foobar') === true },
  { name: 'accepts single char "a"', fn: () => isValidDedicatedSlug('a') === true },
  { name: 'accepts "acme1"', fn: () => isValidDedicatedSlug('acme1') === true },
  { name: 'accepts internal dash "ab-cd"', fn: () => isValidDedicatedSlug('ab-cd') === true },
  { name: 'rejects empty', fn: () => isValidDedicatedSlug('') === false },
  { name: 'accepts at the 14-char max', fn: () => isValidDedicatedSlug('a'.repeat(DEDICATED_SLUG_MAX)) === true },
  { name: 'rejects one past the max', fn: () => isValidDedicatedSlug('a'.repeat(DEDICATED_SLUG_MAX + 1)) === false },
  { name: 'rejects uppercase "Foo"', fn: () => isValidDedicatedSlug('Foo') === false },
  { name: 'rejects digit start "1foo"', fn: () => isValidDedicatedSlug('1foo') === false },
  { name: 'rejects leading dash "-foo"', fn: () => isValidDedicatedSlug('-foo') === false },
  { name: 'rejects trailing dash "foo-"', fn: () => isValidDedicatedSlug('foo-') === false },
  { name: 'rejects whitespace "foo bar"', fn: () => isValidDedicatedSlug('foo bar') === false },
  { name: 'rejects underscore "foo_bar"', fn: () => isValidDedicatedSlug('foo_bar') === false },
];

tests.forEach((test) => {
  try {
    if (test.fn()) {
      console.log(`PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`FAIL: ${test.name}`);
      failed++;
    }
  } catch (error) {
    console.log(`FAIL: ${test.name} (threw: ${error})`);
    failed++;
  }
});

console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
process.exit(failed > 0 ? 1 : 0);

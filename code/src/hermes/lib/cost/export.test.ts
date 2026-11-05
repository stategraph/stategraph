/**
 * Tests for cost CSV building.
 * Run with: npx tsx lib/cost/export.test.ts
 */
import { toCsv } from "./export";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  { name: "header only", fn: () => toCsv(["a", "b"], []) === "a,b" },
  {
    name: "headers + rows",
    fn: () => toCsv(["a", "b"], [["1", "2"], ["3", "4"]]) === "a,b\n1,2\n3,4",
  },
  { name: "escapes commas", fn: () => toCsv(["a"], [["x,y"]]) === 'a\n"x,y"' },
  { name: "escapes quotes", fn: () => toCsv(["a"], [['he said "hi"']]) === 'a\n"he said ""hi"""' },
  { name: "null/undefined cells -> empty", fn: () => toCsv(["a", "b", "c"], [[null, undefined, 5]]) === "a,b,c\n,,5" },
  { name: "numbers stringified", fn: () => toCsv(["n"], [[42]]) === "n\n42" },
];

tests.forEach((t) => {
  try {
    if (t.fn()) {
      console.log(`PASS: ${t.name}`);
      passed++;
    } else {
      console.log(`FAIL: ${t.name}`);
      failed++;
    }
  } catch (error) {
    console.log(`FAIL: ${t.name} (threw: ${error})`);
    failed++;
  }
});

console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
process.exit(failed > 0 ? 1 : 0);

/**
 * Tests for cost delta utilities.
 * Run with: npx tsx lib/cost/delta.test.ts
 */
import { deltaAbsolute, deltaOverRange, deltaPercent, groupDeltasOverRange } from "./delta";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: "empty series -> no values",
    fn: () => {
      const d = deltaOverRange([]);
      return d.previous === null && d.current === null;
    },
  },
  {
    name: "single priced point -> current only, no comparison",
    fn: () => {
      const d = deltaOverRange([{ monthly_cost: "10" }]);
      return d.previous === null && d.current === 10;
    },
  },
  {
    name: "first vs last priced",
    fn: () => {
      const d = deltaOverRange([
        { monthly_cost: "10" },
        { monthly_cost: null },
        { monthly_cost: "15" },
      ]);
      return d.previous === 10 && d.current === 15;
    },
  },
  {
    name: "skips unpriced endpoints",
    fn: () => {
      const d = deltaOverRange([
        { monthly_cost: null },
        { monthly_cost: "8" },
        { monthly_cost: "12" },
        { monthly_cost: undefined },
      ]);
      return d.previous === 8 && d.current === 12;
    },
  },
  { name: "absolute delta", fn: () => deltaAbsolute({ previous: 10, current: 15 }) === 5 },
  {
    name: "absolute null when incomparable",
    fn: () => deltaAbsolute({ previous: null, current: 15 }) === null,
  },
  {
    name: "percent delta",
    fn: () => {
      const p = deltaPercent({ previous: 10, current: 15 });
      return p !== null && Math.abs(p - 50) < 1e-9;
    },
  },
  {
    name: "percent null on zero base",
    fn: () => deltaPercent({ previous: 0, current: 15 }) === null,
  },
  {
    name: "accessor reads an alternate field (hourly)",
    fn: () => {
      const d = deltaOverRange(
        [
          { monthly_cost: "1", hourly_cost: "2" },
          { monthly_cost: "3", hourly_cost: "8" },
        ],
        (p) => p.hourly_cost
      );
      return d.previous === 2 && d.current === 8;
    },
  },
  {
    name: "groupDeltasOverRange pivots first vs last per group",
    fn: () => {
      const m = groupDeltasOverRange([
        { groups: [{ name: "aws", monthly_cost: "10" }, { name: "gcp", monthly_cost: "5" }] },
        { groups: [{ name: "aws", monthly_cost: "14" }, { name: "gcp", monthly_cost: "5" }] },
      ]);
      const aws = m.get("aws");
      const gcp = m.get("gcp");
      return (
        !!aws &&
        aws.previous === 10 &&
        aws.current === 14 &&
        !!gcp &&
        gcp.previous === 5 &&
        gcp.current === 5
      );
    },
  },
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

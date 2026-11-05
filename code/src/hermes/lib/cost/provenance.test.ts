/**
 * Tests for cost-snapshot provenance labels.
 * Run with: npx tsx lib/cost/provenance.test.ts
 */
import { groupLabel, isChangeEvent, provenanceMeta } from "./provenance";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  { name: "known label", fn: () => groupLabel("tx_apply") === "Apply" },
  { name: "unknown value humanized", fn: () => groupLabel("weird_cause") === "Weird Cause" },
  { name: "null -> Unknown", fn: () => groupLabel(null) === "Unknown" },
  { name: "meta for known", fn: () => provenanceMeta("scheduled").label === "Scheduled" },
  {
    name: "meta for unknown falls back",
    fn: () => provenanceMeta("foo_bar").label === "Foo Bar",
  },
  {
    name: "change events are apply/actuator only",
    fn: () =>
      isChangeEvent("tx_apply") &&
      isChangeEvent("actuator_commit") &&
      !isChangeEvent("scheduled") &&
      !isChangeEvent(null),
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

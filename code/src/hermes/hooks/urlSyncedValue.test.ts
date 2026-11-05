import assert from "node:assert";
import { reconcileUrlValue } from "./urlSyncedValue";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("an outside change is adopted and drops pending writes", () => {
  assert.deepEqual(reconcileUrlValue(["github:acme"], ""), { adopt: true, pending: [] });
  assert.deepEqual(reconcileUrlValue([], "github:acme"), { adopt: true, pending: [] });
});

test("the router catching up with an older own write is not adopted", () => {
  assert.deepEqual(reconcileUrlValue(["a", "ab"], "a"), { adopt: false, pending: ["ab"] });
  assert.deepEqual(reconcileUrlValue(["ab"], "ab"), { adopt: false, pending: [] });
});

test("catching up with a later own write skips the earlier ones", () => {
  assert.deepEqual(reconcileUrlValue(["a", "ab", "abc"], "abc"), { adopt: false, pending: [] });
});

test("an absent parameter (null) reconciles like any value", () => {
  assert.deepEqual(reconcileUrlValue<string | null>(["x", null], null), { adopt: false, pending: [] });
  assert.deepEqual(reconcileUrlValue<string | null>(["x"], null), { adopt: true, pending: [] });
});

if (failures > 0) process.exit(1);

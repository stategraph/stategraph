/**
 * Run with: npx tsx lib/getting-started/first-run.test.ts
 */

import assert from "node:assert";
import { firstRunSetupEnabled, hasSeenFirstRun, markFirstRunSeen } from "./first-run";

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`not ok - ${name}`);
    console.error(e);
  }
}

function memoryStore() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
  };
}

test("a tenant is unseen until marked, and the mark is per tenant", () => {
  const store = memoryStore();
  assert.equal(hasSeenFirstRun("t1", store), false);
  markFirstRunSeen("t1", store);
  assert.equal(hasSeenFirstRun("t1", store), true);
  assert.equal(hasSeenFirstRun("t2", store), false);
});

test("no storage means unseen, and marking does not throw", () => {
  assert.equal(hasSeenFirstRun("t1", null), false);
  markFirstRunSeen("t1", null);
  const broken = {
    getItem: () => {
      throw new Error("blocked");
    },
    setItem: () => {
      throw new Error("blocked");
    },
  };
  assert.equal(hasSeenFirstRun("t1", broken), false);
  markFirstRunSeen("t1", broken);
});

test("COMMUNISM mode runs first-run setup whatever the capability says", () => {
  for (const orchestrationEnabled of [true, false, null]) {
    assert.equal(
      firstRunSetupEnabled({ modeLoading: false, mode: "COMMUNISM", orchestrationEnabled }),
      true,
    );
  }
});

test("a self-hosted server runs first-run setup only with orchestration enabled", () => {
  assert.equal(
    firstRunSetupEnabled({ modeLoading: false, mode: undefined, orchestrationEnabled: true }),
    true,
  );
  assert.equal(
    firstRunSetupEnabled({ modeLoading: false, mode: undefined, orchestrationEnabled: false }),
    false,
  );
});

test("first-run setup is undecided until the mode and the capability load", () => {
  assert.equal(
    firstRunSetupEnabled({ modeLoading: true, mode: undefined, orchestrationEnabled: true }),
    null,
  );
  assert.equal(
    firstRunSetupEnabled({ modeLoading: false, mode: undefined, orchestrationEnabled: null }),
    null,
  );
});

if (failures > 0) process.exit(1);

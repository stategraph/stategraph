/**
 * Run with: npx tsx lib/getting-started/next-steps.test.ts
 */

import assert from "node:assert";
import {
  DRIFT_DOCS_HREF,
  MEMBERS_SETTINGS_HREF,
  dismissNextSteps,
  nextSteps,
  nextStepsDismissed,
  showNextSteps,
} from "./next-steps";
import { ORCHESTRATION_SETUP_HREF } from "./setup-progress";

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

const NEW_TENANT = { memberCount: 1, hasDriftRun: false, repositoriesWithRuns: 1 };

test("a new tenant has every step to do, in order, each with its link", () => {
  assert.deepEqual(nextSteps(NEW_TENANT), [
    { id: "invite", done: false, href: MEMBERS_SETTINGS_HREF, external: false },
    { id: "drift", done: false, href: DRIFT_DOCS_HREF, external: true },
    { id: "repository", done: false, href: ORCHESTRATION_SETUP_HREF, external: false },
  ]);
});

test("a second member finishes the invite step", () => {
  assert.equal(nextSteps({ ...NEW_TENANT, memberCount: 2 })[0].done, true);
});

test("a drift run finishes the drift step", () => {
  assert.equal(nextSteps({ ...NEW_TENANT, hasDriftRun: true })[1].done, true);
});

test("runs in a second repository finish the repository step", () => {
  assert.equal(nextSteps({ ...NEW_TENANT, repositoriesWithRuns: 2 })[2].done, true);
});

test("a step whose fact is not known is left out", () => {
  assert.deepEqual(
    nextSteps({ memberCount: null, hasDriftRun: false, repositoriesWithRuns: null }).map((s) => s.id),
    ["drift"],
  );
  assert.deepEqual(nextSteps({ memberCount: null, hasDriftRun: null, repositoriesWithRuns: null }), []);
});

test("the card shows while a known step is not done and it is not dismissed", () => {
  const todo = nextSteps(NEW_TENANT);
  assert.equal(showNextSteps(todo, false), true);
  assert.equal(showNextSteps(todo, true), false);
});

test("the card hides once every known step is done, or when no step is known", () => {
  const done = nextSteps({ memberCount: 3, hasDriftRun: true, repositoriesWithRuns: 2 });
  assert.equal(showNextSteps(done, false), false);
  assert.equal(showNextSteps([], false), false);
});

function memoryStore() {
  const data = new Map<string, string>();
  return {
    getItem: (k: string) => data.get(k) ?? null,
    setItem: (k: string, v: string) => void data.set(k, v),
  };
}

test("dismissing is per tenant", () => {
  const store = memoryStore();
  assert.equal(nextStepsDismissed("t1", store), false);
  dismissNextSteps("t1", store);
  assert.equal(nextStepsDismissed("t1", store), true);
  assert.equal(nextStepsDismissed("t2", store), false);
});

test("a store that throws or is missing reads as not dismissed and never throws", () => {
  const throwing = {
    getItem: () => {
      throw new Error("denied");
    },
    setItem: () => {
      throw new Error("full");
    },
  };
  assert.equal(nextStepsDismissed("t1", throwing), false);
  dismissNextSteps("t1", throwing);
  assert.equal(nextStepsDismissed("t1", null), false);
  dismissNextSteps("t1", null);
});

if (failures > 0) process.exit(1);

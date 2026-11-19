/**
 * Run with: npx tsx lib/getting-started/path-attempts.test.ts
 */

import assert from "node:assert/strict";
import { nextPathSelectionAttempt, type CounterStore } from "./path-attempts";

function memoryStore(): CounterStore {
  const values = new Map<string, string>();
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => {
      values.set(key, value);
    },
  };
}

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "each selection in a tab counts one more attempt",
    run: () => {
      const store = memoryStore();
      assert.equal(nextPathSelectionAttempt(store), 1);
      assert.equal(nextPathSelectionAttempt(store), 2);
      assert.equal(nextPathSelectionAttempt(store), 3);
    },
  },
  {
    name: "a damaged count or no storage starts at 1",
    run: () => {
      const store = memoryStore();
      store.setItem("stategraph-getting-started-path-attempts", "garbage");
      assert.equal(nextPathSelectionAttempt(store), 1);
      store.setItem("stategraph-getting-started-path-attempts", "-4");
      assert.equal(nextPathSelectionAttempt(store), 1);
      assert.equal(nextPathSelectionAttempt(null), 1);
    },
  },
];

let failed = 0;
for (const t of tests) {
  try {
    t.run();
    console.log(`ok - ${t.name}`);
  } catch (e) {
    failed += 1;
    console.error(`not ok - ${t.name}`);
    console.error(e);
  }
}
if (failed > 0) process.exit(1);

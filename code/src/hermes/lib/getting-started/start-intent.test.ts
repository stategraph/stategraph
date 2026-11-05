/**
 * Run with: npx tsx lib/getting-started/start-intent.test.ts
 */

import assert from "node:assert";
import {
  clearStartIntent,
  parseStartIntent,
  readStartIntent,
  setupDestination,
  stashStartIntent,
} from "./start-intent";

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
  const m = new Map<string, string>();
  return {
    getItem: (k: string) => m.get(k) ?? null,
    setItem: (k: string, v: string) => void m.set(k, v),
    removeItem: (k: string) => void m.delete(k),
  };
}

test("only the two product names parse", () => {
  assert.equal(parseStartIntent("iaad"), "iaad");
  assert.equal(parseStartIntent("orchestration"), "orchestration");
  assert.equal(parseStartIntent("IAAD"), null);
  assert.equal(parseStartIntent(""), null);
  assert.equal(parseStartIntent(null), null);
  assert.equal(parseStartIntent(undefined), null);
});

test("a stashed intent reads back once and clears", () => {
  const store = memoryStore();
  stashStartIntent("iaad", store);
  assert.equal(readStartIntent(store), "iaad");
  clearStartIntent(store);
  assert.equal(readStartIntent(store), null);
});

test("an unknown value is never stashed", () => {
  const store = memoryStore();
  stashStartIntent("billing", store);
  assert.equal(readStartIntent(store), null);
});

test("a stored value that is not an intent reads as none", () => {
  const store = memoryStore();
  store.setItem("stategraph-start-intent", "garbage");
  assert.equal(readStartIntent(store), null);
});

test("a throwing store is treated as absent", () => {
  const broken = {
    getItem: () => {
      throw new Error("blocked");
    },
    setItem: () => {
      throw new Error("blocked");
    },
    removeItem: () => {
      throw new Error("blocked");
    },
  };
  stashStartIntent("iaad", broken);
  assert.equal(readStartIntent(broken), null);
  clearStartIntent(broken);
});

test("iaad lands on the state wizard, everything else on orchestration setup", () => {
  assert.equal(setupDestination("iaad"), "/migrate-stategraph");
  assert.equal(setupDestination("orchestration"), "/getting-started?path=orchestrate");
  assert.equal(setupDestination(null), "/getting-started?path=orchestrate");
});

if (failures > 0) process.exit(1);

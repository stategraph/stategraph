import assert from "node:assert";
import { stateFilterOptions } from "./stateFilterOptions";

function state(name: string, workspace = "default") {
  return { id: `id-${name}`, name, workspace };
}

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`);
  }
}

const STATES = [
  state("aws-network"),
  state("billing"),
  state("fargate"),
  state("prod-network", "production"),
];

const names = (states: { name: string }[]) => states.map((s) => s.name);

test("a blank query keeps every state, in order", () => {
  assert.deepEqual(names(stateFilterOptions(STATES, "")), [
    "aws-network",
    "billing",
    "fargate",
    "prod-network",
  ]);
  assert.deepEqual(names(stateFilterOptions(STATES, "   ")), names(STATES));
});

test("disabled states sink to the bottom, each group keeping its order", () => {
  assert.deepEqual(names(stateFilterOptions(STATES, "", ["id-aws-network", "id-fargate"])), [
    "billing",
    "prod-network",
    "aws-network",
    "fargate",
  ]);
});

test("the query is trimmed and case-insensitive", () => {
  assert.deepEqual(names(stateFilterOptions(STATES, "  NETWORK ")), ["aws-network", "prod-network"]);
});

test("disabled states can still be found, after the enabled matches", () => {
  assert.deepEqual(names(stateFilterOptions(STATES, "network", ["id-aws-network"])), [
    "prod-network",
    "aws-network",
  ]);
});

test("the workspace, which the picker does not show, is not matched", () => {
  // Every state here is in workspace "default": matching it would keep them
  // all for "fa", with nothing on screen saying why.
  assert.deepEqual(names(stateFilterOptions(STATES, "fa")), ["fargate"]);
  assert.deepEqual(names(stateFilterOptions(STATES, "production")), []);
});

test("the input list is not modified", () => {
  const before = names(STATES);
  stateFilterOptions(STATES, "network", ["id-aws-network"]);
  assert.deepEqual(names(STATES), before);
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed`);
  process.exit(1);
}
console.log("\nall stateFilterOptions tests passed");

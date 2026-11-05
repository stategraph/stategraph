import assert from "node:assert";
import { computeDriftStates, driftRunKind, humanizeCron, type DriftRow } from "./state";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

const row = (over: Partial<DriftRow>): DriftRow => ({
  id: "run-1",
  provider: "github",
  repoOwner: "acme",
  repoName: "infra",
  environment: "production",
  runType: "plan",
  dir: "envs/prod",
  workspace: "default",
  hasChanges: false,
  success: true,
  createdAt: "2026-07-10T06:00:00Z",
  ...over,
});

test("latest clean check -> clean (older drifted check ignored)", () => {
  const states = computeDriftStates([
    row({ id: "old", hasChanges: true, createdAt: "2026-07-01T06:00:00Z" }),
    row({ id: "new", hasChanges: false, createdAt: "2026-07-10T06:00:00Z" }),
  ]);
  assert.equal(states.length, 1);
  assert.equal(states[0].status, "clean");
  assert.equal(states[0].checkRunId, "new");
});

test("latest check drifted, no reconcile -> drifted", () => {
  const states = computeDriftStates([row({ id: "c1", hasChanges: true })]);
  assert.equal(states[0].status, "drifted");
  assert.equal(states[0].checkRunId, "c1");
});

test("drifted check followed by successful reconcile apply -> reconciled", () => {
  const states = computeDriftStates([
    row({ id: "c1", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
    row({ id: "a1", runType: "apply", createdAt: "2026-07-10T06:40:00Z" }),
  ]);
  assert.equal(states[0].status, "reconciled");
  assert.equal(states[0].reconciledAt, "2026-07-10T06:40:00Z");
});

test("reconcile BEFORE the drifted check does not clear it", () => {
  const states = computeDriftStates([
    row({ id: "a1", runType: "apply", createdAt: "2026-07-09T06:00:00Z" }),
    row({ id: "c1", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
  ]);
  assert.equal(states[0].status, "drifted");
});

test("failed reconcile apply does not clear drift", () => {
  const states = computeDriftStates([
    row({ id: "c1", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
    row({ id: "a1", runType: "apply", success: false, createdAt: "2026-07-10T06:40:00Z" }),
  ]);
  assert.equal(states[0].status, "drifted");
});

test("dirspaces are independent; drifted sorts first", () => {
  const states = computeDriftStates([
    row({ id: "c1", dir: "a", hasChanges: false }),
    row({ id: "c2", dir: "b", hasChanges: true }),
  ]);
  assert.equal(states.length, 2);
  assert.equal(states[0].dir, "b");
  assert.equal(states[0].status, "drifted");
  assert.equal(states[1].status, "clean");
});

test("rows in any order (apply seen before its check)", () => {
  const states = computeDriftStates([
    row({ id: "a1", runType: "apply", createdAt: "2026-07-10T06:40:00Z" }),
    row({ id: "c1", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
  ]);
  assert.equal(states[0].status, "reconciled");
});

test("legacy run_type aliases: autoplan is a check, autoapply/unsafe-apply reconcile", () => {
  const states = computeDriftStates([
    row({ id: "c1", runType: "autoplan", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
    row({ id: "a1", runType: "autoapply", createdAt: "2026-07-10T06:40:00Z" }),
  ]);
  assert.equal(states.length, 1);
  assert.equal(states[0].status, "reconciled");
  assert.equal(states[0].checkRunId, "c1");
  const unsafe = computeDriftStates([
    row({ id: "c2", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
    row({ id: "a2", runType: "unsafe-apply", createdAt: "2026-07-10T06:40:00Z" }),
  ]);
  assert.equal(unsafe[0].status, "reconciled");
});

test("driftRunKind: aliases normalize, anything else is other", () => {
  assert.equal(driftRunKind("plan"), "plan");
  assert.equal(driftRunKind("autoplan"), "plan");
  assert.equal(driftRunKind("apply"), "apply");
  assert.equal(driftRunKind("autoapply"), "apply");
  assert.equal(driftRunKind("unsafe-apply"), "apply");
  assert.equal(driftRunKind("index"), "other");
  assert.equal(driftRunKind("build-config"), "other");
  assert.equal(driftRunKind(""), "other");
});

test("unrelated run types (index, build-*) are ignored", () => {
  const states = computeDriftStates([
    row({ id: "c1", hasChanges: true, createdAt: "2026-07-10T06:00:00Z" }),
    row({ id: "x1", runType: "index", createdAt: "2026-07-10T06:40:00Z" }),
    row({ id: "x2", runType: "build-config", createdAt: "2026-07-10T06:41:00Z" }),
  ]);
  assert.equal(states.length, 1);
  assert.equal(states[0].status, "drifted");
});

test("humanizeCron: daily / weekly / fallback", () => {
  assert.equal(humanizeCron("0 4 * * *"), "Daily at 04:00 UTC");
  assert.equal(humanizeCron("0 6 * * 1"), "Weekly on Mon at 06:00 UTC");
  assert.equal(humanizeCron("0 3 * * 0"), "Weekly on Sun at 03:00 UTC");
  assert.equal(humanizeCron("*/15 * * * *"), "*/15 * * * *");
  assert.equal(humanizeCron("not a cron"), "not a cron");
});

if (failures > 0) { console.error(`\n${failures} test(s) failed`); process.exit(1); }
else console.log("\nall drift-state tests passed");

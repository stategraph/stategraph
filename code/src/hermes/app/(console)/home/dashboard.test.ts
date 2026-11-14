/**
 * Run with: npx tsx "app/(console)/home/dashboard.test.ts"
 */

import assert from "node:assert";
import type { DirspaceDrift } from "@/lib/drift/state";
import {
  ATTENTION_PER_KIND,
  activityTotal,
  attentionHref,
  bucketActivity,
  currentFailedRuns,
  mapStoredPlanRow,
  needsAttention,
  waitingForApply,
  windowStart,
  type FailedRunRow,
  type LatestRunRow,
  type StoredPlanRow,
  type AttentionTransactionRow,
} from "./dashboard";

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

/** Local time, so the day buckets do not depend on the zone the tests run in. */
const local = (day: number, hour = 12, minute = 0) => new Date(2026, 10, day, hour, minute);
const iso = (d: Date) => d.toISOString();
const NOW = local(13, 15);

function failedRun(over: Partial<FailedRunRow> = {}): FailedRunRow {
  return {
    provider: "github",
    id: "wm-1",
    state: "completed",
    runType: "plan",
    runKind: "pr",
    createdAt: iso(local(13, 9)),
    repoOwner: "acme",
    repoName: "infra",
    pullNumber: "12",
    branch: "feature",
    ...over,
  };
}

function latestRun(run: FailedRunRow, latest: Date): LatestRunRow {
  return {
    provider: run.provider,
    repoOwner: run.repoOwner,
    repoName: run.repoName,
    pullNumber: run.pullNumber,
    branch: run.branch,
    runKind: run.runKind,
    runType: run.runType,
    latest: iso(latest),
  };
}

function storedPlan(over: Partial<StoredPlanRow> = {}): StoredPlanRow {
  return {
    provider: "github",
    id: "wm-p1",
    createdAt: iso(local(13, 10)),
    repoOwner: "acme",
    repoName: "infra",
    pullNumber: "12",
    title: "Add the queue",
    path: "envs/prod",
    workspace: "default",
    hasChanges: true,
    ...over,
  };
}

function drift(over: Partial<DirspaceDrift> = {}): DirspaceDrift {
  return {
    key: "acme/infra|envs/prod|default",
    provider: "github",
    repoOwner: "acme",
    repoName: "infra",
    environment: "",
    dir: "envs/prod",
    workspace: "default",
    status: "drifted",
    checkRunId: "wm-d1",
    checkedAt: iso(local(12, 4)),
    ...over,
  };
}

// --- activity chart ----------------------------------------------------------

test("the window is 14 local days ending today", () => {
  const days = bucketActivity([], [], NOW);
  assert.equal(days.length, 14);
  assert.equal(days[0].day, "2026-10-31");
  assert.equal(days[13].day, "2026-11-13");
  assert.equal(days[0].start, windowStart(NOW, 14).getTime());
  assert.equal(activityTotal(days), 0);
});

test("hourly counts add up per local day and kind", () => {
  const days = bucketActivity(
    [
      { hour: iso(local(13, 9)), kind: "plan", count: 3 },
      { hour: iso(local(13, 14)), kind: "plan", count: 2 },
      { hour: iso(local(13, 10)), kind: "apply", count: 1 },
      { hour: iso(local(12, 23)), kind: "apply", count: 4 },
    ],
    [],
    NOW,
  );
  assert.deepEqual(
    days.slice(-2).map((d) => [d.day, d.plans, d.applies, d.failed]),
    [
      ["2026-11-12", 0, 4, 0],
      ["2026-11-13", 5, 1, 0],
    ],
  );
});

test("a failed run moves from its kind to failed on the day of its hour", () => {
  const days = bucketActivity(
    [
      { hour: iso(local(13, 9)), kind: "plan", count: 3 },
      { hour: iso(local(13, 10)), kind: "apply", count: 2 },
    ],
    [
      failedRun({ id: "a", createdAt: iso(local(13, 9, 40)) }),
      failedRun({ id: "b", runType: "autoapply", createdAt: iso(local(13, 10, 5)) }),
    ],
    NOW,
  );
  const today = days[13];
  assert.deepEqual([today.plans, today.applies, today.failed], [2, 1, 2]);
  assert.equal(activityTotal(days), 5);
});

test("runs outside the window, aborted runs and other run types are not counted", () => {
  const days = bucketActivity(
    [{ hour: iso(local(20, 9)), kind: "plan", count: 3 }],
    [
      failedRun({ id: "old", createdAt: iso(local(-1, 9)) }),
      failedRun({ id: "aborted", state: "aborted" }),
      failedRun({ id: "running", state: "running" }),
      failedRun({ id: "index", runType: "index" }),
    ],
    NOW,
  );
  assert.equal(activityTotal(days), 0);
});

test("a failure without its hourly count never drives a kind below zero", () => {
  const days = bucketActivity([], [failedRun()], NOW);
  assert.deepEqual([days[13].plans, days[13].applies, days[13].failed], [0, 0, 1]);
});

// --- waiting for apply ---------------------------------------------------------

test("an open pull request with a stored plan with changes waits for apply", () => {
  const waiting = waitingForApply([storedPlan()]);
  assert.equal(waiting.length, 1);
  assert.equal(waiting[0].pullNumber, "12");
  assert.equal(waiting[0].workspaces, 1);
  assert.equal(waiting[0].title, "Add the queue");
});

test("a plan without changes waits for nothing", () => {
  assert.deepEqual(waitingForApply([storedPlan({ hasChanges: false })]), []);
});

test("a later plan without changes supersedes an earlier plan with changes", () => {
  const plans = [
    storedPlan({ id: "new", createdAt: iso(local(13, 11)), hasChanges: false }),
    storedPlan({ id: "old", createdAt: iso(local(13, 9)), hasChanges: true }),
  ];
  assert.deepEqual(waitingForApply(plans), []);
  assert.deepEqual(waitingForApply([...plans].reverse()), []);
});

test("each workspace with changes counts once, and the newest plan dates the pull request", () => {
  const waiting = waitingForApply([
    storedPlan({ path: "a", createdAt: iso(local(13, 11)) }),
    storedPlan({ path: "a", createdAt: iso(local(13, 9)) }),
    storedPlan({ path: "b", createdAt: iso(local(13, 10)) }),
    storedPlan({ path: "c", hasChanges: false }),
  ]);
  assert.equal(waiting.length, 1);
  assert.equal(waiting[0].workspaces, 2);
  assert.equal(waiting[0].plannedAt, iso(local(13, 11)));
});

test("pull requests are keyed by provider, repository and number, newest first", () => {
  const waiting = waitingForApply([
    storedPlan({ pullNumber: "1", createdAt: iso(local(10)) }),
    storedPlan({ pullNumber: "2", createdAt: iso(local(12)) }),
    storedPlan({ pullNumber: "1", provider: "gitlab", createdAt: iso(local(11)) }),
    storedPlan({ pullNumber: "1", repoName: "other", createdAt: iso(local(9)) }),
  ]);
  assert.deepEqual(
    waiting.map((w) => `${w.provider}:${w.repoName}#${w.pullNumber}`),
    ["github:infra#2", "gitlab:infra#1", "github:infra#1", "github:other#1"],
  );
});

test("has_changes reads as a JSON boolean or its text", () => {
  assert.equal(mapStoredPlanRow("github", { has_changes: true }).hasChanges, true);
  assert.equal(mapStoredPlanRow("github", { has_changes: "true" }).hasChanges, true);
  assert.equal(mapStoredPlanRow("github", { has_changes: false }).hasChanges, false);
  assert.equal(mapStoredPlanRow("github", { has_changes: null }).hasChanges, false);
});

// --- failed runs -------------------------------------------------------------

const WEEK_AGO = NOW.getTime() - 7 * 24 * 3600 * 1000;

test("a failed run that is the newest of its kind needs attention", () => {
  const run = failedRun();
  assert.deepEqual(currentFailedRuns([run], [latestRun(run, local(13, 9))], WEEK_AGO), [run]);
});

test("a later run of the same kind on the same pull request replaces a failure", () => {
  const run = failedRun();
  assert.deepEqual(currentFailedRuns([run], [latestRun(run, local(13, 11))], WEEK_AGO), []);
});

test("a later run of another kind does not replace a failure", () => {
  const run = failedRun();
  const apply = { ...latestRun(run, local(13, 11)), runType: "apply" };
  const autoplan = { ...latestRun(run, local(13, 9)), runType: "autoplan" };
  assert.deepEqual(currentFailedRuns([run], [apply, autoplan], WEEK_AGO), [run]);
});

test("plan aliases share a kind: a later autoplan replaces a failed plan", () => {
  const run = failedRun();
  const autoplan = { ...latestRun(run, local(13, 11)), runType: "autoplan" };
  assert.deepEqual(currentFailedRuns([run], [autoplan], WEEK_AGO), []);
});

test("only the newest failure of a kind is listed", () => {
  const older = failedRun({ id: "older", createdAt: iso(local(13, 8)) });
  const newer = failedRun({ id: "newer", createdAt: iso(local(13, 9)) });
  assert.deepEqual(
    currentFailedRuns([older, newer], [latestRun(newer, local(13, 9))], WEEK_AGO).map((r) => r.id),
    ["newer"],
  );
});

test("failures older than the window, aborted and running runs are left out", () => {
  const old = failedRun({ id: "old", createdAt: iso(local(1)) });
  const aborted = failedRun({ id: "aborted", state: "aborted", pullNumber: "2" });
  const running = failedRun({ id: "running", state: "running", pullNumber: "3" });
  assert.deepEqual(currentFailedRuns([old, aborted, running], [], WEEK_AGO), []);
});

test("a failure whose key the latest runs miss counts as not replaced", () => {
  const run = failedRun({ branch: "main", pullNumber: "", runKind: "drift" });
  assert.deepEqual(currentFailedRuns([run], [], WEEK_AGO), [run]);
});

// --- needs attention ---------------------------------------------------------

const EMPTY = {
  failedRuns: [],
  latestRuns: [],
  drift: [],
  storedPlans: [],
  transactions: [],
  now: NOW,
};

function transaction(over: Partial<AttentionTransactionRow> = {}): AttentionTransactionRow {
  return { id: "tx-1", state: "failed", createdAt: iso(local(13, 8)), completedAt: iso(local(13, 8, 5)), ...over };
}

const openTransaction = (over: Partial<AttentionTransactionRow> = {}) =>
  transaction({ id: "tx-open", state: "open", createdAt: iso(local(13, 13)), completedAt: "", ...over });

test("nothing loaded means nothing needs attention", () => {
  const a = needsAttention(EMPTY);
  assert.deepEqual(a.items, []);
  assert.deepEqual(a.counts, {
    "failed-run": 0,
    "failed-transaction": 0,
    "open-transaction": 0,
    drift: 0,
    "waiting-for-apply": 0,
  });
});

test("items come failures first, then open transactions, drift, and pull requests waiting for apply", () => {
  const a = needsAttention({
    ...EMPTY,
    failedRuns: [failedRun()],
    drift: [drift(), drift({ key: "clean", status: "clean" }), drift({ key: "rec", status: "reconciled" })],
    storedPlans: [storedPlan()],
    transactions: [openTransaction(), transaction()],
  });
  assert.deepEqual(
    a.items.map((i) => i.kind),
    ["failed-run", "failed-transaction", "open-transaction", "drift", "waiting-for-apply"],
  );
  assert.equal(a.counts.drift, 1);
});

test("a transaction open for more than an hour needs attention, whatever its age", () => {
  for (const state of ["open", "previewing", "previewed", "commit-reserved", "committing"]) {
    const a = needsAttention({ ...EMPTY, transactions: [openTransaction({ state })] });
    assert.equal(a.counts["open-transaction"], 1, state);
  }
  const old = needsAttention({ ...EMPTY, transactions: [openTransaction({ createdAt: iso(local(1)) })] });
  assert.equal(old.counts["open-transaction"], 1);
});

test("a transaction open for less than an hour does not", () => {
  const a = needsAttention({
    ...EMPTY,
    transactions: [openTransaction({ createdAt: iso(local(13, 14, 30)) })],
  });
  assert.equal(a.counts["open-transaction"], 0);
});

test("a completed transaction is not open, whatever its state says", () => {
  const a = needsAttention({
    ...EMPTY,
    transactions: [
      openTransaction({ id: "done", completedAt: iso(local(13, 14)) }),
      ...["committed", "aborted", "failed", "failed-committed"].map((state) =>
        openTransaction({ id: state, state }),
      ),
    ],
  });
  assert.equal(a.counts["open-transaction"], 0);
  assert.equal(a.counts["failed-transaction"], 2);
});

test("open transactions list newest first and link to the transaction", () => {
  const a = needsAttention({
    ...EMPTY,
    transactions: [
      openTransaction({ id: "older", createdAt: iso(local(12)) }),
      openTransaction({ id: "newer", createdAt: iso(local(13, 9)) }),
    ],
  });
  assert.deepEqual(a.items.map(attentionHref), [
    "/timeline/detail?tx=newer",
    "/timeline/detail?tx=older",
  ]);
});

test("each kind lists at most ATTENTION_PER_KIND items and counts them all", () => {
  const drifts = [1, 2, 3, 4, 5].map((n) =>
    drift({ key: `k${n}`, dir: `d${n}`, checkRunId: `wm-${n}`, checkedAt: iso(local(n)) }),
  );
  const a = needsAttention({ ...EMPTY, drift: drifts });
  assert.equal(a.items.length, ATTENTION_PER_KIND);
  assert.equal(a.counts.drift, 5);
  assert.deepEqual(
    a.items.map((i) => (i.kind === "drift" ? i.drift.dir : "")),
    ["d5", "d4", "d3"],
  );
});

test("a failed transaction older than the window is left out", () => {
  const a = needsAttention({
    ...EMPTY,
    transactions: [transaction({ id: "tx-old", createdAt: iso(local(1)) })],
  });
  assert.equal(a.counts["failed-transaction"], 0);
});

test("every item links to its detail page", () => {
  const a = needsAttention({
    ...EMPTY,
    failedRuns: [failedRun({ id: "wm-f" })],
    drift: [drift({ checkRunId: "wm-d" })],
    storedPlans: [storedPlan({ repoOwner: "a b", pullNumber: "7" })],
    transactions: [transaction({ state: "failed-committed" })],
  });
  assert.deepEqual(a.items.map(attentionHref), [
    "/runs/wm?id=wm-f",
    "/timeline/detail?tx=tx-1",
    "/runs/wm?id=wm-d",
    "/pull-requests/detail?provider=github&owner=a%20b&repo=infra&pr=7",
  ]);
});

if (failures > 0) process.exit(1);

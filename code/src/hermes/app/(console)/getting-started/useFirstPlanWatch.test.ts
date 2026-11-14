import assert from "node:assert/strict";
import {
  FIRST_PLAN_POLL_MS,
  firstPlanCounts,
  firstPlanPollDelay,
  firstPlanStatus,
  startFirstPlanWatch,
  type FirstPlanCounts,
  type FirstPlanStatus,
} from "./useFirstPlanWatch";

const counts = (partial: Partial<FirstPlanCounts> = {}): FirstPlanCounts => ({
  completed: 0,
  inFlight: 0,
  aborted: 0,
  ...partial,
});

const flush = (): Promise<void> => new Promise((resolve) => setImmediate(resolve));

/** A watch on a fake clock: `advance` fires the pending timer once its delay
 *  has passed, and each read takes the next scripted answer. */
function harness(answers: Array<FirstPlanCounts | Error>) {
  let clock = 0;
  let hidden = false;
  let nextId = 1;
  const timers = new Map<number, { at: number; fn: () => void }>();
  const statuses: FirstPlanStatus[] = [];
  let reads = 0;
  const watch = startFirstPlanWatch({
    load: async () => {
      const answer = answers[Math.min(reads, answers.length - 1)];
      reads += 1;
      if (answer instanceof Error) throw answer;
      return answer;
    },
    onStatus: (status) => statuses.push(status),
    hidden: () => hidden,
    now: () => clock,
    setTimer: (fn, ms) => {
      const id = nextId++;
      timers.set(id, { at: clock + ms, fn });
      return id;
    },
    clearTimer: (id) => {
      timers.delete(id);
    },
  });
  return {
    watch,
    statuses,
    reads: () => reads,
    pending: () => [...timers.values()].map((t) => t.at - clock),
    setHidden: (value: boolean) => {
      hidden = value;
    },
    advance: async (ms: number) => {
      clock += ms;
      for (const [id, t] of [...timers]) {
        if (t.at <= clock) {
          timers.delete(id);
          t.fn();
        }
      }
      await flush();
    },
  };
}

const httpError = (status: number): Error => Object.assign(new Error(`HTTP ${status}`), { status });

const tests: Array<{ name: string; run: () => void | Promise<void> }> = [
  {
    name: "rows fold into completed, in-flight and aborted counts",
    run: () => {
      assert.deepEqual(
        firstPlanCounts([
          { state: "completed", c: 2 },
          { state: "queued", c: "1" },
          { state: "running", c: 1 },
          { state: "aborted", c: 3 },
          { state: "unknown", c: 9 },
        ]),
        counts({ completed: 2, inFlight: 2, aborted: 3 }),
      );
      assert.deepEqual(firstPlanCounts([]), counts());
    },
  },
  {
    name: "a completed plan is arrived only once a read has shown none",
    run: () => {
      assert.equal(firstPlanStatus(counts({ completed: 1 }), true), "arrived");
      assert.equal(firstPlanStatus(counts({ completed: 1 }), false), "existing");
      assert.equal(firstPlanStatus(counts({ inFlight: 1, aborted: 1 }), true), "running");
      assert.equal(firstPlanStatus(counts({ aborted: 1 }), true), "stopped");
      assert.equal(firstPlanStatus(counts(), false), "waiting");
    },
  },
  {
    name: "reads back off from 10 s to 30 s to 60 s, but stay at 10 s while a plan runs",
    run: () => {
      assert.equal(firstPlanPollDelay(0, "waiting"), FIRST_PLAN_POLL_MS);
      assert.equal(firstPlanPollDelay(5 * 60_000 - 1, "waiting"), 10_000);
      assert.equal(firstPlanPollDelay(5 * 60_000, "waiting"), 30_000);
      assert.equal(firstPlanPollDelay(15 * 60_000, "stopped"), 60_000);
      assert.equal(firstPlanPollDelay(60 * 60_000, "running"), 10_000);
    },
  },
  {
    name: "the watch reads at once, polls, and stops when the plan arrives",
    run: async () => {
      const h = harness([counts(), counts({ inFlight: 1 }), counts({ completed: 1 })]);
      await flush();
      assert.deepEqual(h.statuses, ["waiting"]);
      assert.deepEqual(h.pending(), [10_000]);
      await h.advance(10_000);
      assert.deepEqual(h.statuses, ["waiting", "running"]);
      await h.advance(10_000);
      assert.deepEqual(h.statuses, ["waiting", "running", "arrived"]);
      assert.deepEqual(h.pending(), []);
      await h.advance(60_000);
      assert.equal(h.reads(), 3);
    },
  },
  {
    name: "a plan that completed before the first read stops the watch without arriving",
    run: async () => {
      const h = harness([counts({ completed: 4 })]);
      await flush();
      assert.deepEqual(h.statuses, ["existing"]);
      assert.deepEqual(h.pending(), []);
      h.watch.resume();
      await flush();
      assert.equal(h.reads(), 1);
    },
  },
  {
    name: "a hidden tab skips reads until resume, which reads at once and restarts the backoff",
    run: async () => {
      const h = harness([counts()]);
      await flush();
      await h.advance(6 * 60_000);
      assert.deepEqual(h.pending(), [30_000]);
      h.setHidden(true);
      await h.advance(30_000);
      const readsWhileHidden = h.reads();
      assert.deepEqual(h.pending(), []);
      await h.advance(5 * 60_000);
      assert.equal(h.reads(), readsWhileHidden);
      h.setHidden(false);
      h.watch.resume();
      await flush();
      assert.equal(h.reads(), readsWhileHidden + 1);
      assert.deepEqual(h.pending(), [10_000]);
    },
  },
  {
    name: "a transient failure keeps polling and a later read still arrives",
    run: async () => {
      const h = harness([httpError(502), counts(), counts({ completed: 1 })]);
      await flush();
      assert.deepEqual(h.statuses, ["error"]);
      assert.deepEqual(h.pending(), [10_000]);
      await h.advance(10_000);
      await h.advance(10_000);
      assert.deepEqual(h.statuses, ["error", "waiting", "arrived"]);
    },
  },
  {
    name: "a deterministic failure stops the watch",
    run: async () => {
      const unavailable = Object.assign(new Error("table"), {
        status: 400,
        body: { id: "TABLE_ACCESS_ERR" },
      });
      for (const error of [httpError(403), unavailable]) {
        const h = harness([error]);
        await flush();
        assert.deepEqual(h.statuses, ["error"]);
        assert.deepEqual(h.pending(), []);
      }
    },
  },
  {
    name: "stop cancels the pending read and ignores a read in flight",
    run: async () => {
      const h = harness([counts()]);
      h.watch.stop();
      await flush();
      assert.deepEqual(h.statuses, []);
      assert.deepEqual(h.pending(), []);
    },
  },
];

async function main(): Promise<void> {
  let failed = 0;
  for (const test of tests) {
    try {
      await test.run();
      console.log(`PASS: ${test.name}`);
    } catch (error) {
      failed += 1;
      console.error(`FAIL: ${test.name}`);
      console.error(error);
    }
  }
  process.exit(failed === 0 ? 0 : 1);
}

void main();

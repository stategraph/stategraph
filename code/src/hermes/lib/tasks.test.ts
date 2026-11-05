/**
 * Tests for the pollTask helper.
 *
 * pollTask hits GET /api/v1/tasks/{id} via fetchAPI -> globalThis.fetch, so we
 * stub fetch at the global level. Each test installs its own fetch and
 * restores the previous one afterwards.
 *
 * Run with: npx tsx lib/tasks.test.ts
 */

import { isTerminalTaskState, pollTask } from "./tasks";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => Promise<boolean>;
}

type FetchFn = typeof globalThis.fetch;

function installFetch(stub: FetchFn): () => void {
  const prev = globalThis.fetch;
  globalThis.fetch = stub;
  return () => {
    globalThis.fetch = prev;
  };
}

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

const tests: TestCase[] = [
  {
    name: "isTerminalTaskState: completed/failed/aborted are terminal",
    fn: async () => {
      return (
        isTerminalTaskState("completed") &&
        isTerminalTaskState("failed") &&
        isTerminalTaskState("aborted")
      );
    },
  },
  {
    name: "isTerminalTaskState: pending/running are non-terminal",
    fn: async () => {
      return !isTerminalTaskState("pending") && !isTerminalTaskState("running");
    },
  },
  {
    name: "pollTask: resolves on first terminal response",
    fn: async () => {
      const restore = installFetch(async () =>
        jsonResponse({ id: "t1", state: "completed" })
      );
      try {
        const task = await pollTask("t1", { intervalMs: 1 });
        return task.state === "completed";
      } finally {
        restore();
      }
    },
  },
  {
    name: "pollTask: polls past non-terminal states until terminal",
    fn: async () => {
      const seq = ["running", "running", "completed"] as const;
      let i = 0;
      const restore = installFetch(async () =>
        jsonResponse({ id: "t2", state: seq[Math.min(i++, seq.length - 1)] })
      );
      try {
        const task = await pollTask("t2", { intervalMs: 1 });
        return task.state === "completed" && i === seq.length;
      } finally {
        restore();
      }
    },
  },
  {
    name: "pollTask: rejects with AbortError when signal is already aborted",
    fn: async () => {
      const restore = installFetch(async () =>
        jsonResponse({ id: "t3", state: "completed" })
      );
      const ctrl = new AbortController();
      ctrl.abort();
      try {
        await pollTask("t3", { intervalMs: 1, signal: ctrl.signal });
        return false; // should have thrown
      } catch (err) {
        return err instanceof DOMException && err.name === "AbortError";
      } finally {
        restore();
      }
    },
  },
  {
    name: "pollTask: aborting mid-delay rejects with AbortError and clears the timer",
    fn: async () => {
      const restore = installFetch(async () =>
        jsonResponse({ id: "t4", state: "running" })
      );
      const ctrl = new AbortController();
      // Abort after the first getTask returns but during the delay.
      setTimeout(() => ctrl.abort(), 20);
      const start = Date.now();
      try {
        await pollTask("t4", { intervalMs: 5000, signal: ctrl.signal });
        return false; // should have thrown
      } catch (err) {
        const elapsed = Date.now() - start;
        const isAbortError = err instanceof DOMException && err.name === "AbortError";
        // If the timer wasn't cleared, the promise would only settle after
        // 5 seconds; we expect the abort path to settle promptly.
        const settledPromptly = elapsed < 1000;
        return isAbortError && settledPromptly;
      } finally {
        restore();
      }
    },
  },
  {
    name: "pollTask: rejects after maxAttempts is exhausted",
    fn: async () => {
      const restore = installFetch(async () =>
        jsonResponse({ id: "t5", state: "running" })
      );
      try {
        await pollTask("t5", { intervalMs: 1, maxAttempts: 3 });
        return false; // should have thrown
      } catch (err) {
        return err instanceof Error && /did not finish/i.test(err.message);
      } finally {
        restore();
      }
    },
  },
];

(async () => {
  for (const test of tests) {
    try {
      if (await test.fn()) {
        console.log(`PASS: ${test.name}`);
        passed++;
      } else {
        console.log(`FAIL: ${test.name}`);
        failed++;
      }
    } catch (error) {
      console.log(`FAIL: ${test.name} (threw: ${error})`);
      failed++;
    }
  }
  console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
  process.exit(failed > 0 ? 1 : 0);
})();

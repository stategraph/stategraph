/**
 * Generic async-task polling.
 *
 * Several backend endpoints return 202 + a task id and run work in the
 * background (cost recompute, gap analysis, ...). The task status endpoint
 * (`GET /api/v1/tasks/{id}`) reports one of pending | running | completed |
 * failed | aborted. This helper consolidates the polling + cancellation
 * pattern so new callers (e.g. the cost recompute kicked off from Cost
 * Analysis) don't reinvent it.
 *
 * NOTE: gap-analysis was the inspiration for this helper but has not been
 * retrofitted yet -- its polling loop in
 * `app/(console)/gap-analysis/page.tsx` is structurally different (it
 * re-fetches the gap-analysis result with no-cache headers rather than
 * GETting a task id). Migrating it is a separate task.
 */

import { getTask, type Task } from "@/lib/api/client";

const TERMINAL_STATES: ReadonlySet<Task["state"]> = new Set<Task["state"]>([
  "completed",
  "failed",
  "aborted",
]);

export function isTerminalTaskState(state: Task["state"]): boolean {
  return TERMINAL_STATES.has(state);
}

export interface PollTaskOptions {
  /** Delay between polls, in ms. Default 2000. */
  intervalMs?: number;
  /** Abort the poll loop (e.g. on component unmount). */
  signal?: AbortSignal;
  /** Safety cap on the number of polls. Default 150 (~5 min at 2s). */
  maxAttempts?: number;
}

/**
 * Poll a task until it reaches a terminal state (completed | failed | aborted)
 * and resolve with the final {@link Task}. Resolves (does not reject) on
 * terminal states so callers can branch on `task.state`; rejects only on
 * network/HTTP errors, abort, or when `maxAttempts` is exhausted.
 */
export async function pollTask(
  taskId: string,
  options?: PollTaskOptions
): Promise<Task> {
  const intervalMs = options?.intervalMs ?? 2000;
  const maxAttempts = options?.maxAttempts ?? 150;
  const signal = options?.signal;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    if (signal?.aborted) throw new DOMException("Aborted", "AbortError");
    const task = await getTask(taskId);
    if (isTerminalTaskState(task.state)) return task;
    await delay(intervalMs, signal);
  }
  throw new Error(`Task ${taskId} did not finish after ${maxAttempts} polls`);
}

function delay(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new DOMException("Aborted", "AbortError"));
      return;
    }
    const onAbort = () => {
      clearTimeout(timer);
      reject(new DOMException("Aborted", "AbortError"));
    };
    const timer = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

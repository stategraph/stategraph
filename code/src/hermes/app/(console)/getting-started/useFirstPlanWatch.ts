"use client";

import { useEffect, useState } from "react";
import { asNumber, asText, executeWithRetry, transientFailure } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";
import { firstPlanQuery } from "./mqlQueries";

/** `existing`: a plan had completed before the first read, so the arrival
 *  cannot be attributed to this wizard. `error`: the runs could not be read. */
export type FirstPlanStatus =
  | "checking"
  | "waiting"
  | "running"
  | "stopped"
  | "arrived"
  | "existing"
  | "error";

export interface FirstPlanCounts {
  completed: number;
  inFlight: number;
  aborted: number;
}

export const FIRST_PLAN_POLL_MS = 10_000;
export const FIRST_PLAN_ADVANCE_MS = 2_000;

export function firstPlanCounts(rows: readonly unknown[]): FirstPlanCounts {
  const counts: FirstPlanCounts = { completed: 0, inFlight: 0, aborted: 0 };
  for (const raw of rows) {
    const row = raw as Record<string, unknown>;
    const c = asNumber(row.c);
    switch (asText(row.state)) {
      case "completed":
        counts.completed += c;
        break;
      case "queued":
      case "running":
        counts.inFlight += c;
        break;
      case "aborted":
        counts.aborted += c;
        break;
    }
  }
  return counts;
}

/** `watched` is true once an earlier read showed no completed plan. */
export function firstPlanStatus(counts: FirstPlanCounts, watched: boolean): FirstPlanStatus {
  if (counts.completed > 0) return watched ? "arrived" : "existing";
  if (counts.inFlight > 0) return "running";
  if (counts.aborted > 0) return "stopped";
  return "waiting";
}

/** Delay before the next read. `activeMs` counts from the start of the watch
 *  or from the tab's last return to the foreground. */
export function firstPlanPollDelay(activeMs: number, status: FirstPlanStatus): number {
  if (status === "running") return FIRST_PLAN_POLL_MS;
  if (activeMs < 5 * 60_000) return FIRST_PLAN_POLL_MS;
  if (activeMs < 15 * 60_000) return 30_000;
  return 60_000;
}

export async function loadFirstPlanCounts(provider: VcsProvider): Promise<FirstPlanCounts> {
  return firstPlanCounts(await executeWithRetry(firstPlanQuery(provider)));
}

export interface FirstPlanWatchDeps {
  load: () => Promise<FirstPlanCounts>;
  onStatus: (status: FirstPlanStatus) => void;
  hidden: () => boolean;
  now: () => number;
  setTimer: (fn: () => void, ms: number) => number;
  clearTimer: (id: number) => void;
}

export interface FirstPlanWatch {
  /** Read now and restart the backoff. */
  resume: () => void;
  stop: () => void;
}

/** Read at once, then on the backoff schedule until the plan arrives, a plan
 *  already exists, a read fails for good, or `stop`. A hidden tab skips its
 *  reads; `resume` restarts them. */
export function startFirstPlanWatch(deps: FirstPlanWatchDeps): FirstPlanWatch {
  let stopped = false;
  let finished = false;
  let inFlight = false;
  let watched = false;
  let timer: number | null = null;
  let status: FirstPlanStatus = "checking";
  let activeSince = deps.now();

  const cancelTimer = (): void => {
    if (timer === null) return;
    deps.clearTimer(timer);
    timer = null;
  };

  const tick = async (): Promise<void> => {
    if (stopped || finished || inFlight || deps.hidden()) return;
    inFlight = true;
    try {
      const counts = await deps.load();
      if (stopped) return;
      status = firstPlanStatus(counts, watched);
      if (counts.completed === 0) watched = true;
      finished = status === "arrived" || status === "existing";
    } catch (error) {
      if (stopped) return;
      status = "error";
      finished = !transientFailure(error);
    } finally {
      inFlight = false;
    }
    deps.onStatus(status);
    if (finished) return;
    cancelTimer();
    timer = deps.setTimer(() => {
      timer = null;
      void tick();
    }, firstPlanPollDelay(deps.now() - activeSince, status));
  };

  void tick();

  return {
    resume: () => {
      if (stopped || finished) return;
      activeSince = deps.now();
      cancelTimer();
      void tick();
    },
    stop: () => {
      stopped = true;
      cancelTimer();
    },
  };
}

/** Watch for the tenant's first pull request plan while the caller is mounted. */
export function useFirstPlanWatch(provider: VcsProvider): FirstPlanStatus {
  const [status, setStatus] = useState<FirstPlanStatus>("checking");

  useEffect(() => {
    const watch = startFirstPlanWatch({
      load: () => loadFirstPlanCounts(provider),
      onStatus: setStatus,
      hidden: () => document.hidden,
      now: () => Date.now(),
      setTimer: (fn, ms) => window.setTimeout(fn, ms),
      clearTimer: (id) => window.clearTimeout(id),
    });
    const onVisibility = (): void => {
      if (!document.hidden) watch.resume();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      document.removeEventListener("visibilitychange", onVisibility);
      watch.stop();
    };
  }, [provider]);

  return status;
}

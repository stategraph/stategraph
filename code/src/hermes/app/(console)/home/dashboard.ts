// The Orchestration parts of Home: Needs attention and the activity chart, derived from the rows
// of the queries in ./mqlQueries.

import type { VcsProvider } from "@/lib/vcs/links";
import { asNumber, asText } from "@/lib/mql/providers";
import { driftRunKind, type DirspaceDrift, type DriftRunKind } from "@/lib/drift/state";
import { runListOutcome } from "@/lib/wm/decode";

/** Days the activity chart covers, today included. */
export const ACTIVITY_DAYS = 14;
/** How far back a failed run or transaction needs attention. */
export const ATTENTION_DAYS = 7;
/** Items of each kind that Needs attention lists. */
export const ATTENTION_PER_KIND = 3;

const DAY_MS = 24 * 3600 * 1000;
const HOUR_MS = 3600 * 1000;

const ts = (iso: string): number => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : 0;
};

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

export interface FailedRunRow {
  provider: VcsProvider;
  id: string;
  state: string;
  runType: string;
  runKind: string;
  createdAt: string;
  repoOwner: string;
  repoName: string;
  pullNumber: string;
  branch: string;
}

export function mapFailedRunRow(provider: VcsProvider, raw: unknown): FailedRunRow {
  const o = raw as Record<string, unknown>;
  return {
    provider,
    id: asText(o.id),
    state: asText(o.state),
    runType: asText(o.run_type),
    runKind: asText(o.run_kind),
    createdAt: asText(o.created_at),
    repoOwner: asText(o.repo_owner),
    repoName: asText(o.repo_name),
    pullNumber: asText(o.pull_number),
    branch: asText(o.branch),
  };
}

export interface LatestRunRow {
  provider: VcsProvider;
  repoOwner: string;
  repoName: string;
  pullNumber: string;
  branch: string;
  runKind: string;
  runType: string;
  latest: string;
}

export function mapLatestRunRow(provider: VcsProvider, raw: unknown): LatestRunRow {
  const o = raw as Record<string, unknown>;
  return {
    provider,
    repoOwner: asText(o.repo_owner),
    repoName: asText(o.repo_name),
    pullNumber: asText(o.pull_number),
    branch: asText(o.branch),
    runKind: asText(o.run_kind),
    runType: asText(o.run_type),
    latest: asText(o.latest),
  };
}

export interface StoredPlanRow {
  provider: VcsProvider;
  id: string;
  createdAt: string;
  repoOwner: string;
  repoName: string;
  pullNumber: string;
  title: string;
  path: string;
  workspace: string;
  hasChanges: boolean;
}

export function mapStoredPlanRow(provider: VcsProvider, raw: unknown): StoredPlanRow {
  const o = raw as Record<string, unknown>;
  return {
    provider,
    id: asText(o.id),
    createdAt: asText(o.created_at),
    repoOwner: asText(o.repo_owner),
    repoName: asText(o.repo_name),
    pullNumber: asText(o.pull_number),
    title: asText(o.title),
    path: asText(o.path),
    workspace: asText(o.workspace),
    hasChanges: o.has_changes === true || asText(o.has_changes) === "true",
  };
}

export interface ActivityHourRow {
  hour: string;
  kind: "plan" | "apply";
  count: number;
}

export function mapActivityHourRow(raw: unknown): ActivityHourRow {
  const o = raw as Record<string, unknown>;
  return {
    hour: asText(o.hour),
    kind: asText(o.kind) === "apply" ? "apply" : "plan",
    count: asNumber(o.c),
  };
}

export interface AttentionTransactionRow {
  id: string;
  state: string;
  createdAt: string;
  /** "" while the transaction is open. */
  completedAt: string;
}

export function mapAttentionTransactionRow(raw: unknown): AttentionTransactionRow {
  const o = raw as Record<string, unknown>;
  return {
    id: asText(o.id),
    state: asText(o.state),
    createdAt: asText(o.created_at),
    completedAt: asText(o.completed_at),
  };
}

// ---------------------------------------------------------------------------
// Activity chart
// ---------------------------------------------------------------------------

/** Local midnight `days - 1` days before `now`: the start of `days` local days ending today. */
export function windowStart(now: Date, days: number): Date {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() - (days - 1));
}

function dayKey(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

export interface ActivityDay {
  /** Local date, `YYYY-MM-DD`. */
  day: string;
  /** Local midnight of the day, epoch millis. */
  start: number;
  /** Plan runs without a failure. */
  plans: number;
  /** Apply runs without a failure. */
  applies: number;
  /** Plan and apply runs with a failure. */
  failed: number;
}

/**
 * Plan and apply runs per local day, for the `days` days ending on the day of `now`. The counts
 * come per hour, so a run is counted on the local day its hour starts in, and a failed run is
 * placed by its hour the same way. A failed run counts under `failed` and not under its kind.
 */
export function bucketActivity(
  hours: readonly ActivityHourRow[],
  failedRuns: readonly FailedRunRow[],
  now: Date,
  days: number = ACTIVITY_DAYS,
): ActivityDay[] {
  const start = windowStart(now, days);
  const totals = new Map<string, { plan: number; apply: number; failedPlan: number; failedApply: number }>();
  const out: ActivityDay[] = [];
  for (let i = 0; i < days; i++) {
    const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
    out.push({ day: dayKey(d), start: d.getTime(), plans: 0, applies: 0, failed: 0 });
    totals.set(dayKey(d), { plan: 0, apply: 0, failedPlan: 0, failedApply: 0 });
  }
  const bucket = (iso: string) => {
    const t = Date.parse(iso);
    if (!Number.isFinite(t)) return undefined;
    return totals.get(dayKey(new Date(Math.floor(t / HOUR_MS) * HOUR_MS)));
  };
  for (const h of hours) {
    const b = bucket(h.hour);
    if (!b) continue;
    if (h.kind === "apply") b.apply += h.count;
    else b.plan += h.count;
  }
  for (const r of failedRuns) {
    if (runListOutcome(r.state, 1) !== "failed") continue;
    const kind = driftRunKind(r.runType);
    if (kind === "other") continue;
    const b = bucket(r.createdAt);
    if (!b) continue;
    if (kind === "apply") b.failedApply += 1;
    else b.failedPlan += 1;
  }
  for (const row of out) {
    const b = totals.get(row.day)!;
    row.plans = Math.max(0, b.plan - b.failedPlan);
    row.applies = Math.max(0, b.apply - b.failedApply);
    row.failed = b.failedPlan + b.failedApply;
  }
  return out;
}

export function activityTotal(days: readonly ActivityDay[]): number {
  return days.reduce((sum, d) => sum + d.plans + d.applies + d.failed, 0);
}

// ---------------------------------------------------------------------------
// Needs attention
// ---------------------------------------------------------------------------

export type AttentionKind =
  | "failed-run"
  | "failed-transaction"
  | "open-transaction"
  | "drift"
  | "waiting-for-apply";

export const ATTENTION_ORDER: readonly AttentionKind[] = [
  "failed-run",
  "failed-transaction",
  "open-transaction",
  "drift",
  "waiting-for-apply",
];

/** How long a transaction stays open before it needs attention. */
export const OPEN_TRANSACTION_HOURS = 1;

export const FAILED_TRANSACTION_STATES: readonly string[] = ["failed", "failed-committed"];
/** The states that complete a transaction and set its `completed_at`. */
export const TERMINAL_TRANSACTION_STATES: readonly string[] = [
  "committed",
  "aborted",
  ...FAILED_TRANSACTION_STATES,
];

/** An open pull request with a stored plan that has changes and no apply. */
export interface WaitingPullRequest {
  provider: VcsProvider;
  repoOwner: string;
  repoName: string;
  pullNumber: string;
  title: string;
  /** Directories and workspaces whose latest plan has changes. */
  workspaces: number;
  /** When the newest of those plans ran. */
  plannedAt: string;
}

export type AttentionItem =
  | { kind: "failed-run"; at: string; run: FailedRunRow }
  | { kind: "failed-transaction"; at: string; transaction: AttentionTransactionRow }
  | { kind: "open-transaction"; at: string; transaction: AttentionTransactionRow }
  | { kind: "drift"; at: string; drift: DirspaceDrift }
  | { kind: "waiting-for-apply"; at: string; pullRequest: WaitingPullRequest };

export interface NeedsAttention {
  /** At most ATTENTION_PER_KIND of each kind, in ATTENTION_ORDER, newest first within a kind. */
  items: AttentionItem[];
  counts: Record<AttentionKind, number>;
}

/**
 * The open pull requests waiting for apply. A directory and workspace waits when the newest stored
 * plan for it on the pull request has changes: an applied plan is deleted, and a later plan without
 * changes supersedes an earlier one with changes.
 */
export function waitingForApply(plans: readonly StoredPlanRow[]): WaitingPullRequest[] {
  const newest = new Map<string, StoredPlanRow>();
  for (const p of plans) {
    const key = [p.provider, p.repoOwner, p.repoName, p.pullNumber, p.path, p.workspace].join("|");
    const prev = newest.get(key);
    if (!prev || ts(p.createdAt) > ts(prev.createdAt)) newest.set(key, p);
  }
  const byPull = new Map<string, WaitingPullRequest>();
  for (const p of newest.values()) {
    if (!p.hasChanges) continue;
    const key = [p.provider, p.repoOwner, p.repoName, p.pullNumber].join("|");
    const prev = byPull.get(key);
    if (!prev) {
      byPull.set(key, {
        provider: p.provider,
        repoOwner: p.repoOwner,
        repoName: p.repoName,
        pullNumber: p.pullNumber,
        title: p.title,
        workspaces: 1,
        plannedAt: p.createdAt,
      });
      continue;
    }
    prev.workspaces += 1;
    if (ts(p.createdAt) > ts(prev.plannedAt)) prev.plannedAt = p.createdAt;
  }
  return [...byPull.values()].sort((a, b) => ts(b.plannedAt) - ts(a.plannedAt));
}

function runKey(r: {
  provider: VcsProvider;
  repoOwner: string;
  repoName: string;
  pullNumber: string;
  branch: string;
  runKind: string;
}, kind: DriftRunKind): string {
  return [r.provider, r.repoOwner, r.repoName, r.pullNumber, r.branch, r.runKind, kind].join("|");
}

/**
 * The failed runs since `since` (epoch millis) that no later run replaced: a failed run needs
 * attention while it is the newest run of its kind (plan, apply or other) for the same repository,
 * pull request, branch and run kind. A key missing from `latest` counts as not replaced.
 */
export function currentFailedRuns(
  failed: readonly FailedRunRow[],
  latest: readonly LatestRunRow[],
  since: number,
): FailedRunRow[] {
  const latestAt = new Map<string, number>();
  for (const l of latest) {
    const key = runKey(l, driftRunKind(l.runType));
    latestAt.set(key, Math.max(latestAt.get(key) ?? 0, ts(l.latest)));
  }
  const seen = new Set<string>();
  return [...failed]
    .sort((a, b) => ts(b.createdAt) - ts(a.createdAt))
    .filter((r) => {
      if (runListOutcome(r.state, 1) !== "failed") return false;
      const at = ts(r.createdAt);
      if (at < since) return false;
      const key = runKey(r, driftRunKind(r.runType));
      if (seen.has(key)) return false;
      seen.add(key);
      return at >= (latestAt.get(key) ?? 0);
    });
}

export function needsAttention(input: {
  failedRuns: readonly FailedRunRow[];
  latestRuns: readonly LatestRunRow[];
  drift: readonly DirspaceDrift[];
  storedPlans: readonly StoredPlanRow[];
  transactions: readonly AttentionTransactionRow[];
  now: Date;
}): NeedsAttention {
  const since = input.now.getTime() - ATTENTION_DAYS * DAY_MS;
  const openBefore = input.now.getTime() - OPEN_TRANSACTION_HOURS * HOUR_MS;
  const transactions = [...input.transactions].sort((a, b) => ts(b.createdAt) - ts(a.createdAt));
  const byKind: Record<AttentionKind, AttentionItem[]> = {
    "failed-run": currentFailedRuns(input.failedRuns, input.latestRuns, since).map((run) => ({
      kind: "failed-run",
      at: run.createdAt,
      run,
    })),
    "failed-transaction": transactions
      .filter((t) => FAILED_TRANSACTION_STATES.includes(t.state) && ts(t.createdAt) >= since)
      .map((transaction) => ({ kind: "failed-transaction", at: transaction.createdAt, transaction })),
    "open-transaction": transactions
      .filter(
        (t) =>
          t.completedAt === "" &&
          !TERMINAL_TRANSACTION_STATES.includes(t.state) &&
          ts(t.createdAt) > 0 &&
          ts(t.createdAt) <= openBefore,
      )
      .map((transaction) => ({ kind: "open-transaction", at: transaction.createdAt, transaction })),
    drift: input.drift
      .filter((d) => d.status === "drifted")
      .sort((a, b) => ts(b.checkedAt) - ts(a.checkedAt))
      .map((drift) => ({ kind: "drift", at: drift.checkedAt, drift })),
    "waiting-for-apply": waitingForApply(input.storedPlans).map((pullRequest) => ({
      kind: "waiting-for-apply",
      at: pullRequest.plannedAt,
      pullRequest,
    })),
  };
  return {
    items: ATTENTION_ORDER.flatMap((kind) => byKind[kind].slice(0, ATTENTION_PER_KIND)),
    counts: {
      "failed-run": byKind["failed-run"].length,
      "failed-transaction": byKind["failed-transaction"].length,
      "open-transaction": byKind["open-transaction"].length,
      drift: byKind.drift.length,
      "waiting-for-apply": byKind["waiting-for-apply"].length,
    },
  };
}

const enc = encodeURIComponent;

/** The detail page of an item. */
export function attentionHref(item: AttentionItem): string {
  switch (item.kind) {
    case "failed-run":
      return `/runs/wm?id=${enc(item.run.id)}`;
    case "failed-transaction":
    case "open-transaction":
      return `/timeline/detail?tx=${enc(item.transaction.id)}`;
    case "drift":
      return `/runs/wm?id=${enc(item.drift.checkRunId)}`;
    case "waiting-for-apply": {
      const pr = item.pullRequest;
      return `/pull-requests/detail?provider=${pr.provider}&owner=${enc(pr.repoOwner)}&repo=${enc(pr.repoName)}&pr=${enc(pr.pullNumber)}`;
    }
  }
}

/** The list page of a kind. */
export const ATTENTION_LIST_HREF: Record<AttentionKind, string> = {
  "failed-run": "/runs",
  "failed-transaction": "/timeline",
  "open-transaction": "/timeline",
  drift: "/drift",
  "waiting-for-apply": "/pull-requests?status=open",
};

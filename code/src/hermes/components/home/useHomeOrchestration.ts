"use client";

import { useEffect, useState } from "react";
import { asNumber, executeWithRetry, runAcrossProviders } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";
import { computeDriftStates, type DriftRow } from "@/lib/drift/state";
import { DRIFT_CAP, driftStepQuery, mapDriftRow } from "@/app/(console)/drift/mqlQueries";
import {
  HOME_ROWS_CAP,
  RECENT_RUNS_SHOWN,
  activityByHourQuery,
  attentionTransactionsQuery,
  failedRunsQuery,
  latestRunsQuery,
  mapRunRow,
  mergeRecentRuns,
  openPullRequestPlansQuery,
  openPullRequestsQuery,
  recentRunsQuery,
  runsSinceCountQuery,
  type RunRow,
} from "@/app/(console)/home/mqlQueries";
import {
  ACTIVITY_DAYS,
  ATTENTION_DAYS,
  OPEN_TRANSACTION_HOURS,
  bucketActivity,
  mapActivityHourRow,
  mapAttentionTransactionRow,
  mapFailedRunRow,
  mapLatestRunRow,
  mapStoredPlanRow,
  needsAttention,
  windowStart,
  type ActivityDay,
  type ActivityHourRow,
  type AttentionTransactionRow,
  type FailedRunRow,
  type LatestRunRow,
  type NeedsAttention,
  type StoredPlanRow,
} from "@/app/(console)/home/dashboard";

export interface HomeOrchestration {
  runs: RunRow[];
  /** Providers whose recent runs failed to load while another provider's loaded. */
  runsFailed: VcsProvider[];
  /** `null` when no provider's counts loaded. */
  counts: { runs24h: number; openPrs: number; drifted: number; driftCapped: boolean } | null;
  /** Providers whose runs loaded and whose counts did not. */
  countsFailed: VcsProvider[];
  /** `null` when no provider's activity loaded. */
  activity: ActivityDay[] | null;
  activityFailed: VcsProvider[];
  /** `null` when no provider's items loaded and no transaction needs attention. */
  attention: NeedsAttention | null;
  attentionFailed: VcsProvider[];
  /** The transactions were asked for and did not load. */
  transactionsFailed: boolean;
}

interface ProviderData {
  runs: RunRow[];
  metrics: { runs24h: number; openPrs: number; drift: DriftRow[]; capped: boolean } | null;
  activity: { hours: ActivityHourRow[]; failed: FailedRunRow[] } | null;
  attention: { failed: FailedRunRow[]; latest: LatestRunRow[]; plans: StoredPlanRow[] } | null;
}

const HOUR_MS = 3600 * 1000;
const DAY_MS = 24 * HOUR_MS;

const first = (rows: unknown[]): Record<string, unknown> | undefined =>
  rows[0] as Record<string, unknown> | undefined;

async function loadProvider(
  p: VcsProvider,
  since: { day: string; activity: string; attention: string },
): Promise<ProviderData> {
  // The two drift queries pull up to DRIFT_CAP step-output rows each, the Drift screen's whole
  // load: "drifted" has to be the same number the Drift screen shows, and only the same fold
  // produces it. driftMetricQuery(p, "finds", since) counts drift checks that found changes, not
  // distinct drifted dirspaces.
  const [recent, count24h, prs, driftPlan, driftApply, hours, failed, latest, plans] =
    await Promise.allSettled([
      executeWithRetry(recentRunsQuery(p)),
      executeWithRetry(runsSinceCountQuery(p, since.day)),
      executeWithRetry(openPullRequestsQuery(p)),
      executeWithRetry(driftStepQuery(p, "plan")),
      executeWithRetry(driftStepQuery(p, "apply")),
      executeWithRetry(activityByHourQuery(p, since.activity)),
      executeWithRetry(failedRunsQuery(p, since.activity)),
      executeWithRetry(latestRunsQuery(p, since.attention)),
      executeWithRetry(openPullRequestPlansQuery(p)),
    ]);
  if (recent.status === "rejected") throw recent.reason;
  const runs = recent.value.map((r) => mapRunRow(p, r));
  // Each group is all-or-nothing per provider, so a half-fetched provider never contributes a
  // partial number. Recent runs never wait on the other groups.
  const metrics =
    count24h.status === "fulfilled" &&
    prs.status === "fulfilled" &&
    driftPlan.status === "fulfilled" &&
    driftApply.status === "fulfilled"
      ? {
          runs24h: asNumber(first(count24h.value)?.c),
          openPrs: asNumber(first(prs.value)?.c),
          drift: [...driftPlan.value, ...driftApply.value].map((row) => mapDriftRow(p, row)),
          // A provider returning exactly its cap means older checks were cut, so a dirspace whose
          // latest check fell outside the window is missing from the fold and `drifted`
          // undercounts.
          capped: driftPlan.value.length >= DRIFT_CAP || driftApply.value.length >= DRIFT_CAP,
        }
      : null;
  const failedRows =
    failed.status === "fulfilled" ? failed.value.map((r) => mapFailedRunRow(p, r)) : null;
  return {
    runs,
    metrics,
    activity:
      hours.status === "fulfilled" && failedRows
        ? { hours: hours.value.map(mapActivityHourRow), failed: failedRows }
        : null,
    attention:
      metrics && failedRows && latest.status === "fulfilled" && plans.status === "fulfilled"
        ? {
            failed: failedRows,
            latest: latest.value.map((r) => mapLatestRunRow(p, r)),
            plans: plans.value.map((r) => mapStoredPlanRow(p, r)),
          }
        : null,
  };
}

function combine(
  results: { provider: VcsProvider; value: ProviderData }[],
  down: VcsProvider[],
  txRows: AttentionTransactionRow[] | null,
  now: Date,
): HomeOrchestration {
  const values = results.map((r) => r.value);
  const metrics = values.flatMap((v) => (v.metrics ? [v.metrics] : []));
  const activity = values.flatMap((v) => (v.activity ? [v.activity] : []));
  const attention = values.flatMap((v) => (v.attention ? [v.attention] : []));
  const driftStates = computeDriftStates(metrics.flatMap((m) => m.drift));
  const failedProviders = (pick: (v: ProviderData) => unknown): VcsProvider[] => [
    ...down,
    ...results.filter((r) => pick(r.value) === null).map((r) => r.provider),
  ];
  return {
    runs: mergeRecentRuns(
      values.map((v) => v.runs),
      RECENT_RUNS_SHOWN,
    ),
    runsFailed: down,
    counts:
      metrics.length > 0
        ? {
            runs24h: metrics.reduce((sum, m) => sum + m.runs24h, 0),
            openPrs: metrics.reduce((sum, m) => sum + m.openPrs, 0),
            drifted: driftStates.filter((d) => d.status === "drifted").length,
            driftCapped: metrics.some((m) => m.capped),
          }
        : null,
    countsFailed: results.filter((r) => r.value.metrics === null).map((r) => r.provider),
    activity:
      activity.length > 0
        ? bucketActivity(
            activity.flatMap((a) => a.hours),
            activity.flatMap((a) => a.failed),
            now,
          )
        : null,
    activityFailed: failedProviders((v) => v.activity),
    attention:
      attention.length > 0 || (txRows !== null && txRows.length > 0)
        ? needsAttention({
            failedRuns: attention.flatMap((a) => a.failed),
            latestRuns: attention.flatMap((a) => a.latest),
            drift: attention.length > 0 ? driftStates : [],
            storedPlans: attention.flatMap((a) => a.plans),
            transactions: txRows ?? [],
            now,
          })
        : null,
    attentionFailed: failedProviders((v) => v.attention),
    transactionsFailed: txRows === null,
  };
}

/**
 * Everything Home shows about Orchestration, for both providers. `null` until it loads, and when
 * every provider fails, most often on a server without Orchestration. With `includeTransactions`,
 * Needs attention also lists the tenant's failed and long-open Stategraph transactions. A change of
 * `reloadKey` loads again and keeps the current data until the new data lands.
 */
export function useHomeOrchestration({
  tenantId,
  enabled,
  includeTransactions,
  reloadKey,
}: {
  tenantId: string;
  /** Nothing loads while false. */
  enabled: boolean;
  includeTransactions: boolean;
  reloadKey: number;
}): HomeOrchestration | null {
  const [loaded, setLoaded] = useState<{ tenantId: string; value: HomeOrchestration } | null>(null);

  useEffect(() => {
    if (!enabled) return;
    let cancelled = false;

    async function load(): Promise<void> {
      const now = new Date();
      const since = {
        day: new Date(now.getTime() - DAY_MS).toISOString(),
        activity: windowStart(now, ACTIVITY_DAYS).toISOString(),
        attention: new Date(now.getTime() - ATTENTION_DAYS * DAY_MS).toISOString(),
      };
      const openBefore = new Date(now.getTime() - OPEN_TRANSACTION_HOURS * HOUR_MS).toISOString();
      const transactions: Promise<AttentionTransactionRow[] | null> = includeTransactions
        ? executeWithRetry(
            attentionTransactionsQuery(
              tenantId,
              { since: since.attention, openBefore },
              HOME_ROWS_CAP,
            ),
          ).then(
            (rows) => rows.map(mapAttentionTransactionRow),
            () => null,
          )
        : Promise.resolve([]);
      try {
        const [{ results, failed: down }, txRows] = await Promise.all([
          runAcrossProviders((p) => loadProvider(p, since)),
          transactions,
        ]);
        if (cancelled) return;
        setLoaded({ tenantId, value: combine(results, down, txRows, now) });
      } catch {
        // Every provider failed, or the fan-out itself broke, most often a server running
        // without Orchestration. The Orchestration sections stay hidden.
        if (!cancelled) setLoaded(null);
      }
    }

    // One tick later, so StrictMode's dev-only remount cancels the first load before it starts.
    const t = window.setTimeout(() => void load(), 0);
    return () => {
      cancelled = true;
      window.clearTimeout(t);
    };
  }, [tenantId, enabled, includeTransactions, reloadKey]);

  return enabled && loaded !== null && loaded.tenantId === tenantId ? loaded.value : null;
}

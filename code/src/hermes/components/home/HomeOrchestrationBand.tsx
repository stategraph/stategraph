"use client";

import { useCallback, useMemo, useState } from "react";
import { ArrowRight, GitPullRequest, GitCompare, Play } from "lucide-react";
import { useDeepLinkRouter, useInitialLoad } from "@/hooks";
import { asNumber, executeWithRetry, runAcrossProviders } from "@/lib/mql/providers";
import { StateChip } from "@/components/plans/StateChip";
import { prSigil, type VcsProvider } from "@/lib/vcs/links";
import { computeDriftStates } from "@/lib/drift/state";
import { formatRelativeTime } from "@/lib/utils/time";
import { DRIFT_CAP, driftStepQuery, mapDriftRow } from "@/app/(console)/drift/mqlQueries";
import {
  RECENT_RUNS_SHOWN,
  mapRunRow,
  mergeRecentRuns,
  openPullRequestsQuery,
  recentRunsQuery,
  runsSinceCountQuery,
  type RunRow,
} from "@/app/(console)/home/mqlQueries";

function Tile({
  label,
  value,
  icon: Icon,
  tone,
  title,
  onClick,
  onAuxClick,
}: {
  label: string;
  value: string;
  icon: React.ComponentType<{ className?: string }>;
  tone?: string;
  title?: string;
  onClick: (e: React.MouseEvent) => void;
  onAuxClick?: (e: React.MouseEvent) => void;
}) {
  return (
    <button
      onClick={onClick}
      onAuxClick={onAuxClick}
      title={title}
      className="flex-1 min-w-[140px] cursor-pointer rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-4 py-3 text-left transition-colors hover:border-[var(--sg-accent)] hover:bg-[var(--sg-bg-2)]"
    >
      <div className="flex items-center gap-1.5 text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
        <Icon className="h-3.5 w-3.5" /> {label}
      </div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${tone ?? "text-[var(--sg-text)]"}`}>{value}</div>
    </button>
  );
}

/**
 * The orchestration-first home band: recent runs, open pull requests, and
 * drifted workspaces across both providers, deep-linking into the orchestration
 * views. Renders nothing until its data resolves (no zeroed-tile flash, no
 * all-clear derived from empty data), nothing when the server has no
 * orchestration, and nothing when there is no activity — the inventory
 * sections below carry the page in those cases.
 */
export function HomeOrchestrationBand() {
  const router = useDeepLinkRouter();
  const [runs, setRuns] = useState<RunRow[] | null>(null);
  const [runs24h, setRuns24h] = useState(0);
  const [openPrs, setOpenPrs] = useState(0);
  const [drifted, setDrifted] = useState(0);
  const [runsFailed, setRunsFailed] = useState<VcsProvider[]>([]);
  const [countsFailed, setCountsFailed] = useState<VcsProvider[]>([]);
  const [countsLoaded, setCountsLoaded] = useState(false);
  const [driftCapped, setDriftCapped] = useState(false);

  const load = useCallback(async () => {
    try {
      const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
      // A provider whose recent-runs query fails contributes nothing; every
      // provider failing throws and the catch below leaves the band hidden.
      const { results, failed: down } = await runAcrossProviders(async (p) => {
        // Five queries per provider, and the two drift ones pull up to
        // DRIFT_CAP step-output rows each — the Drift screen's whole load, on
        // the front door, per mount and per Refresh. Accepted deliberately:
        // "drifted" has to be the same number the Drift screen shows, and only
        // the same fold produces it. driftMetricQuery(p, "finds", since) is one
        // cheap aggregate row, but it counts drift checks that found changes,
        // not distinct drifted dirspaces, so the tile would quietly disagree
        // with the screen it links to. The band stays behind !bootstrapping, so
        // the first-run setup path never pays this.
        const [recent, count24h, prs, driftPlan, driftApply] = await Promise.allSettled([
          executeWithRetry(recentRunsQuery(p)),
          executeWithRetry(runsSinceCountQuery(p, since)),
          executeWithRetry(openPullRequestsQuery(p)),
          executeWithRetry(driftStepQuery(p, "plan")),
          executeWithRetry(driftStepQuery(p, "apply")),
        ]);
        if (recent.status === "rejected") throw recent.reason;
        const providerRuns = recent.value.map((r) => mapRunRow(p, r));
        // Recent runs never wait on the auxiliary numbers: a failed count or
        // drift query still lists this provider's runs. The numbers stay
        // all-or-nothing per provider, so a half-fetched provider never
        // contributes a partial number.
        if (
          count24h.status === "rejected" ||
          prs.status === "rejected" ||
          driftPlan.status === "rejected" ||
          driftApply.status === "rejected"
        ) {
          return { runs: providerRuns, metrics: null };
        }
        return {
          runs: providerRuns,
          metrics: {
            runs24h: asNumber((count24h.value[0] as Record<string, unknown> | undefined)?.c),
            openPrs: asNumber((prs.value[0] as Record<string, unknown> | undefined)?.c),
            drift: [...driftPlan.value, ...driftApply.value].map((row) => mapDriftRow(p, row)),
            // A provider returning exactly its cap means older checks were cut,
            // so a dirspace whose latest check fell outside the window is missing
            // from the fold and `drifted` undercounts.
            capped: driftPlan.value.length >= DRIFT_CAP || driftApply.value.length >= DRIFT_CAP,
          },
        };
      });
      const metrics = results.flatMap((r) => (r.value.metrics ? [r.value.metrics] : []));
      const allRuns = mergeRecentRuns(results.map((r) => r.value.runs), RECENT_RUNS_SHOWN);
      const driftStates = computeDriftStates(metrics.flatMap((m) => m.drift));
      // A provider whose runs loaded but whose numbers did not is named apart
      // from the ones that failed outright: its runs are listed, the counts
      // leave it out. With no provider's numbers at all the tiles stay hidden
      // rather than showing zeros nobody loaded.
      setRunsFailed(down);
      setCountsFailed(results.filter((r) => r.value.metrics === null).map((r) => r.provider));
      setCountsLoaded(metrics.length > 0);
      setDriftCapped(metrics.some((m) => m.capped));
      setRuns(allRuns);
      setRuns24h(metrics.reduce((sum, m) => sum + m.runs24h, 0));
      setOpenPrs(metrics.reduce((sum, m) => sum + m.openPrs, 0));
      setDrifted(driftStates.filter((d) => d.status === "drifted").length);
    } catch {
      // Every provider failed, or the fan-out itself broke — most often a
      // server running without the orchestration side at all. Non-fatal for
      // the home band: `runs` stays null, so the band stays hidden and the
      // inventory sections below carry the page.
    }
  }, []);

  useInitialLoad(load);

  const hasActivity = useMemo(
    () => (runs?.length ?? 0) > 0 || runs24h > 0 || openPrs > 0 || drifted > 0,
    [runs, runs24h, openPrs, drifted],
  );

  // Nothing until the data resolves: no zeroed-tile flash, no green all-clear
  // derived from empty data (same rule the Drift screen enforces).
  if (runs === null) return null;
  if (!hasActivity) return null;

  return (
    <div className="space-y-4 mb-8">
      <h2 className="text-base font-semibold text-[var(--sg-text)] uppercase tracking-wide">Orchestration</h2>

      {runsFailed.length > 0 && (
        <div className="p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
          Could not load {runsFailed.join(", ")} orchestration activity — the runs and
          counts below cover the rest.
        </div>
      )}
      {countsFailed.length > 0 && (
        <div className="p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
          Could not load {countsFailed.join(", ")} counts — their recent runs are listed,
          the counts leave them out.
        </div>
      )}

      {countsLoaded ? (
        <div className="flex flex-wrap gap-3">
          <Tile
            label="Runs (24h)"
            value={String(runs24h)}
            icon={Play}
            {...router.nav("/runs")}
          />
          <Tile
            label="Open pull requests"
            value={String(openPrs)}
            icon={GitPullRequest}
            {...router.nav("/pull-requests?status=open")}
          />
          <Tile
            label="Drifted"
            // Past the cap the number can only be too low, so say "at least"
            // rather than a bare figure — the Drift screen makes the same
            // admission in prose under its check history.
            value={driftCapped ? `${drifted}+` : String(drifted)}
            icon={GitCompare}
            tone={
              drifted > 0
                ? "text-[var(--sg-warning)]"
                : runsFailed.length + countsFailed.length > 0 || driftCapped
                  ? undefined
                  : "text-[var(--sg-success)]"
            }
            title={
              driftCapped
                ? `Drifted workspaces from the most recent ${DRIFT_CAP} drift steps per provider — older checks were cut, so this may undercount`
                : `Drifted workspaces from the latest drift checks (up to ${DRIFT_CAP} steps per provider)`
            }
            {...router.nav("/drift")}
          />
        </div>
      ) : null}

      {/* Labelled, because the list and the Runs tile deliberately measure
          different things: the tile is a true 24h count, the list is the newest
          few of any age. An idle tenant showing "Runs (24h) 0" above month-old
          rows is correct, and only reads as a contradiction unlabelled. */}
      {runs.length > 0 ? (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <div className="text-sm font-medium text-[var(--sg-text)]">Recent runs</div>
            <button
              {...router.nav("/runs")}
              className="inline-flex cursor-pointer items-center gap-1 text-sm text-[var(--sg-accent)] hover:underline"
            >
              View all <ArrowRight className="h-3.5 w-3.5" />
            </button>
          </div>
          <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden divide-y divide-[var(--sg-border)]">
            {runs.map((r) => (
              <button
                key={`${r.provider}-${r.id}`}
                {...router.nav(`/runs/wm?id=${r.id}`)}
                className="flex w-full cursor-pointer items-start gap-3 px-4 py-2.5 text-left hover:bg-[var(--sg-bg-2)] sm:items-center"
              >
                <StateChip state={r.state} />
                <span className="flex min-w-0 flex-1 flex-col gap-1 sm:flex-row sm:items-center sm:gap-3">
                  <span className="min-w-0 break-all font-mono text-xs text-[var(--sg-text-muted)] sm:max-w-[40%] sm:truncate">
                    {r.repo || "—"}
                  </span>
                  <span className="text-xs text-[var(--sg-text-muted)]">
                    {r.runType}
                    {r.runKind ? <span className="text-[var(--sg-text-dim)]"> · {r.runKind}</span> : null}
                  </span>
                  {r.pullNumber ? (
                    <span className="text-xs text-[var(--sg-text-dim)]">{prSigil(r.provider)}{r.pullNumber}</span>
                  ) : null}
                  <span className="text-xs text-[var(--sg-text-muted)] sm:ml-auto sm:shrink-0">
                    {formatRelativeTime(r.createdAt)}
                  </span>
                </span>
              </button>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}

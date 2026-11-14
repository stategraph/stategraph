"use client";

import { ArrowRight, GitPullRequest, GitCompare, Play } from "lucide-react";
import { useDeepLinkRouter } from "@/hooks";
import { StateChip } from "@/components/plans/StateChip";
import { prSigil, providerName } from "@/lib/vcs/links";
import { cn } from "@/lib/utils";
import { formatRelativeTime } from "@/lib/utils/time";
import { SETUP_COPY } from "@/lib/getting-started/setup-progress";
import { DRIFT_CAP } from "@/app/(console)/drift/mqlQueries";
import { ActivityChart } from "./ActivityChart";
import type { HomeOrchestration } from "./useHomeOrchestration";

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
 * The Orchestration activity on Home: the run, pull request and drift tiles, the plans and applies
 * of the last days, and the newest runs, deep-linking into the Orchestration views. Renders nothing
 * when there is no activity: no zeroed-tile flash, no all-clear derived from empty data. With
 * `wide` the chart and the recent runs sit side by side on large screens.
 */
export function HomeOrchestrationBand({ data, wide }: { data: HomeOrchestration; wide: boolean }) {
  const router = useDeepLinkRouter();
  const { runs, runsFailed, counts, countsFailed, activity, activityFailed } = data;

  const hasActivity =
    runs.length > 0 ||
    (counts !== null && (counts.runs24h > 0 || counts.openPrs > 0 || counts.drifted > 0));
  if (!hasActivity) return null;

  const drifted = counts?.drifted ?? 0;
  const driftCapped = counts?.driftCapped ?? false;

  return (
    <div className="space-y-4">
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

      {counts !== null ? (
        <div className="flex flex-wrap gap-3">
          <Tile
            label="Runs (24h)"
            value={String(counts.runs24h)}
            icon={Play}
            {...router.nav("/runs")}
          />
          <Tile
            label="Open pull requests"
            value={String(counts.openPrs)}
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

      <div className={cn("grid gap-4", wide && "lg:grid-cols-2 lg:items-start")}>
        {activity !== null ? (
          <div className="space-y-2">
            {activityFailed.length > 0 ? (
              <div className="p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
                {SETUP_COPY.activity.partial(activityFailed.map(providerName).join(", "))}
              </div>
            ) : null}
            <ActivityChart days={activity} />
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
    </div>
  );
}

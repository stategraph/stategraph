"use client";

import { Suspense, useCallback, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowLeft, Lock, RefreshCw } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { StatCard } from "@/components/page";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import { prSigil, type VcsProvider } from "@/lib/vcs/links";
import { asNumber, asText, orchestrationUnavailable } from "@/lib/mql/providers";
import { sqlLiteral } from "@/lib/mql/escape";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { OUTCOME_LABEL, OutcomeChip } from "@/components/wm";
import { runOutcomeFromSuccess, runKindLabel } from "@/lib/wm/decode";
import { workspaceLockedQuery } from "../mqlQueries";

/** Newest runs shown in the history table; the "Runs" card counts them all. */
const HISTORY_CAP = 100;

interface RunRow {
  id: string;
  state: string;
  runType: string;
  runKind: string;
  createdAt: string;
  username: string;
  pullNumber: string;
  success: boolean | null;
}
interface Overview {
  runCount: number;
  locked: boolean;
  pendingChanges: boolean;
  stateId: string | null;
}

function WorkspaceDetailContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const rawProvider = searchParams.get("provider") ?? "";
  const provider: VcsProvider = rawProvider === "gitlab" ? "gitlab" : "github";
  const owner = searchParams.get("owner") ?? "";
  const repo = searchParams.get("repo") ?? "";
  const dir = searchParams.get("dir") ?? "";
  const workspace = searchParams.get("workspace") ?? "";

  const [runs, setRuns] = useState<RunRow[] | null>(null);
  const [overview, setOverview] = useState<Overview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);

  const missing = !owner || !repo || !dir || !workspace;

  const load = useCallback(async () => {
    if (missing) return;
    try {
      const o = sqlLiteral(owner), rp = sqlLiteral(repo), d = sqlLiteral(dir), w = sqlLiteral(workspace);
      const dirspace = `wmds.path = ${d} and wmds.workspace = ${w} and gwm.repo_owner = ${o} and gwm.repo_name = ${rp}`;
      const [hist, total, plans, lock, states] = await Promise.all([
        executeMQL(
          `select gwm.id as id, gwm.state as state, gwm.run_type as run_type, gwm.run_kind as run_kind, gwm.created_at as created_at, gwm.username as username, gwm.pull_number as pull_number, wmr.success as success from work_manifest_dirspaceflows as wmds inner join ${provider}_work_manifests as gwm on gwm.id = wmds.work_manifest left join work_manifest_results as wmr on wmr.work_manifest = wmds.work_manifest and wmr.path = wmds.path and wmr.workspace = wmds.workspace where ${dirspace} order by gwm.created_at desc limit ${HISTORY_CAP}`,
        ),
        // The history table is capped; the card must count every run.
        executeMQL(
          `select count(*) as c from work_manifest_dirspaceflows as wmds inner join ${provider}_work_manifests as gwm on gwm.id = wmds.work_manifest where ${dirspace}`,
        ),
        // Repo-scoped + newest first: plans is tenant-scoped and carries no repo
        // column, so join through the work manifest and take the latest.
        executeMQL(`select p.has_changes as has_changes from plans as p inner join ${provider}_work_manifests as wm on wm.id = p.work_manifest where p.path = ${d} and p.workspace = ${w} and wm.repo_owner = ${o} and wm.repo_name = ${rp} order by p.created_at desc limit 1`),
        executeMQL(workspaceLockedQuery(provider, owner, repo, dir, workspace)),
        executeMQL(`select id as id, name as name from states where name = ${d} order by updated_at desc limit 1`),
      ]);
      const runRows: RunRow[] = hist.data.map((r) => {
        const x = r as Record<string, unknown>;
        return {
          id: asText(x.id),
          state: asText(x.state),
          runType: asText(x.run_type),
          runKind: asText(x.run_kind),
          createdAt: asText(x.created_at),
          username: asText(x.username),
          pullNumber: asText(x.pull_number),
          success: typeof x.success === "boolean" ? x.success : null,
        };
      });
      setRuns(runRows);
      const pendingChanges = (plans.data[0] as Record<string, unknown> | undefined)?.has_changes === true;
      const st = states.data[0] as Record<string, unknown> | undefined;
      setOverview({
        runCount: asNumber((total.data[0] as Record<string, unknown> | undefined)?.c),
        locked: lock.data.length > 0,
        pendingChanges,
        stateId: st ? asText(st.id) : null,
      });
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load workspace");
    }
  }, [missing, provider, owner, repo, dir, workspace]);
  useInitialLoad(load);

  const lastRun = useMemo(() => (runs && runs.length > 0 ? runs[0] : null), [runs]);
  const shownError = error ?? (missing ? "Missing workspace parameters." : null);

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <header className="px-6 pt-6 pb-3 border-b border-[var(--sg-border)] flex items-center gap-3">
        <button
          {...router.nav("/workspaces")}
          className="p-1 rounded hover:bg-[var(--sg-bg-2)]"
          aria-label="Back to workspaces"
        >
          <ArrowLeft className="w-4 h-4 text-[var(--sg-text-muted)]" />
        </button>
        <div className="min-w-0">
          <h1 className="text-lg font-semibold text-[var(--sg-text)] truncate">
            <span className="font-mono">{dir || "."}</span>{" "}
            <span className="text-[var(--sg-text-muted)] text-sm">· {workspace}</span>
          </h1>
          <div className="text-xs text-[var(--sg-text-muted)]">
            {owner}/{repo}
            {overview?.locked && (
              <span className="ml-2 inline-flex items-center gap-1 text-[var(--sg-warning)]">
                <Lock className="w-3 h-3" /> locked
              </span>
            )}
          </div>
        </div>
        <button
          onClick={() => void load()}
          className="ml-auto p-1 rounded hover:bg-[var(--sg-bg-2)]"
          aria-label="Refresh"
        >
          <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
        </button>
      </header>

      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-5">
        {shownError ? (
          <div className="p-3 rounded-lg bg-[var(--sg-error-bg)] border border-[var(--sg-error)]/30 text-sm text-[var(--sg-error)]">
            {shownError}
          </div>
        ) : runs === null ? (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>
        ) : (
          <>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
              <StatCard
                label="Last run"
                value={lastRun ? OUTCOME_LABEL[runOutcomeFromSuccess(lastRun.state, lastRun.success)] : "—"}
                sub={lastRun ? formatRelativeTime(lastRun.createdAt) : undefined}
              />
              <StatCard label="Runs" value={String(overview?.runCount ?? 0)} />
              <StatCard
                label="Pending plan"
                value={overview?.pendingChanges ? "changes waiting" : "up to date"}
              />
              <StatCard label="Lock" value={overview?.locked ? "locked" : "unlocked"} />
              {/* Heuristic bridge: the Stategraph state whose name equals the directory. */}
              {overview?.stateId ? (
                <StatCard
                  label="Stategraph state"
                  value={dir}
                  sub="matched by directory name"
                  href={`/states/detail?id=${overview.stateId}`}
                />
              ) : (
                <StatCard label="Stategraph state" value="—" sub="no state named like this directory" />
              )}
            </div>

            <div>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2">
                Run history
                {(overview?.runCount ?? 0) > HISTORY_CAP && (
                  <span className="ml-2 text-xs font-normal text-[var(--sg-text-dim)]">
                    showing the latest {HISTORY_CAP} of {overview?.runCount}
                  </span>
                )}
              </div>
              {runs.length === 0 ? (
                <div className="p-8 text-sm text-[var(--sg-text-muted)]">
                  No runs recorded for this workspace.
                </div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Outcome</TableHead>
                        <TableHead>Type</TableHead>
                        <TableHead>When</TableHead>
                        <TableHead>By</TableHead>
                        <TableHead>PR</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {runs.map((r) => (
                        <TableRow
                          key={r.id}
                          className="cursor-pointer"
                          {...router.nav(`/runs/wm?id=${r.id}`)}
                        >
                          <TableCell>
                            <OutcomeChip outcome={runOutcomeFromSuccess(r.state, r.success)} />
                          </TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]">
                            {r.runType}
                            {r.runKind ? <span className="text-[var(--sg-text-dim)]"> · {runKindLabel(r.runKind)}</span> : null}
                          </TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]" title={formatAbsoluteTime(r.createdAt)}>
                            {formatRelativeTime(r.createdAt)}
                          </TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]">{r.username || "—"}</TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]">
                            {r.pullNumber ? `${prSigil(provider)}${r.pullNumber}` : "—"}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default function WorkspaceDetailPage() {
  return (
    <Suspense fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}>
      <WorkspaceDetailContent />
    </Suspense>
  );
}

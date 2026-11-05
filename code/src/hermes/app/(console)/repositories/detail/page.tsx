"use client";

import { Suspense, useCallback, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowLeft, ExternalLink, GitCompare, GitPullRequest, Layers, PlayCircle, RefreshCw } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { CopyButton } from "@/components/ui/copy-button";
import { toYaml } from "@/lib/config/yaml";
import { Breadcrumbs } from "@/components/list/Breadcrumbs";
import { WorkflowEnvHeader } from "@/components/list";
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
import { prNoun, prSigil, projectUrl, providerName, type VcsProvider } from "@/lib/vcs/links";
import { asNumber, asText, orchestrationUnavailable } from "@/lib/mql/providers";
import { sqlLiteral } from "@/lib/mql/escape";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { FormattedOutput, OutcomeChip } from "@/components/wm";
import { runListOutcome, runKindLabel } from "@/lib/wm/decode";
import { withFailCounts } from "@/lib/wm/failCounts";
import { redactRepoConfig } from "../redactRepoConfig";

const enc = encodeURIComponent;
/** Workspaces listed on the page; the "Workspaces" card counts them all. */
const WS_LIST_CAP = 500;

interface WsRow { dir: string; workspace: string; env: string; lastRun: string; runCount: number; }
interface RunRow { id: string; state: string; failCount: number; runType: string; runKind: string; createdAt: string; pullNumber: string; }
interface Overview { workspaces: number; openPullRequests: number; drift: number; totalRuns: number; lastActivity: string; }

interface RepoConfig { sha: string; kind: string; branch: string; data: Record<string, unknown> | null; }


function ConfigPanel({ config }: { config: RepoConfig }) {
  // The derived config is the committed one, so it can carry literal secrets
  // (hook env maps, the S3 plan-store key); mask them before rendering.
  const yaml = useMemo(() => toYaml(redactRepoConfig(config.data ?? {})), [config.data]);
  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
      <div className="px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-sm flex items-center gap-2 flex-wrap">
        <span className="text-[var(--sg-text)]">Effective configuration</span>
        <span className="text-xs text-[var(--sg-text-dim)]">
          resolved from <span className="font-mono">{config.branch}</span> @{" "}
          <span className="font-mono">{config.sha.slice(0, 7)}</span>
        </span>
        <span className="ml-auto">
          <CopyButton text={yaml} />
        </span>
      </div>
      <div className="px-4 pt-2 text-xs text-[var(--sg-text-dim)]">Credential-bearing values are masked.</div>
      <div className="max-h-[36rem] overflow-auto">
        <FormattedOutput text={yaml} format={{ kind: "code", lang: "yaml" }} />
      </div>
    </div>
  );
}

function RepositoryDetailContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const rawProvider = searchParams.get("provider") ?? "";
  const provider: VcsProvider = rawProvider === "gitlab" ? "gitlab" : "github";
  const owner = searchParams.get("owner") ?? "";
  const repo = searchParams.get("repo") ?? "";

  const [workspaces, setWorkspaces] = useState<WsRow[] | null>(null);
  const [runs, setRuns] = useState<RunRow[]>([]);
  const [overview, setOverview] = useState<Overview | null>(null);
  const [config, setConfig] = useState<RepoConfig | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);

  const missing = !owner || !repo;

  const load = useCallback(async () => {
    if (missing) return;
    try {
      const o = sqlLiteral(owner), r = sqlLiteral(repo);
      const scope = `gwm.repo_owner = ${o} and gwm.repo_name = ${r}`;
      const dirspaces = `select wmds.path as dir, wmds.workspace as workspace from work_manifest_dirspaceflows as wmds inner join ${provider}_work_manifests as gwm on gwm.id = wmds.work_manifest where ${scope} group by wmds.path, wmds.workspace`;
      const [ws, wsTotal, recent, total, drift, openPrs, configRes] = await Promise.all([
        executeMQL(`select wmds.path as dir, wmds.workspace as workspace, max(gwm.environment) as environment, max(gwm.created_at) as last_run, count(*) as c from work_manifest_dirspaceflows as wmds inner join ${provider}_work_manifests as gwm on gwm.id = wmds.work_manifest where ${scope} group by wmds.path, wmds.workspace order by max(gwm.created_at) desc limit ${WS_LIST_CAP}`),
        // The list is capped; the card must count every dirspace.
        executeMQL(`with ws as (${dirspaces}) select count(*) as c from ws`),
        executeMQL(`select gwm.id as id, gwm.state as state, gwm.run_type as run_type, gwm.run_kind as run_kind, gwm.created_at as created_at, gwm.pull_number as pull_number from ${provider}_work_manifests as gwm where ${scope} order by gwm.created_at desc limit 30`).then((res) => withFailCounts(res.data)),
        executeMQL(`select count(*) as c from ${provider}_work_manifests as gwm where ${scope}`),
        executeMQL(`select count(*) as c from ${provider}_work_manifests as gwm where ${scope} and gwm.run_kind = 'drift'`),
        executeMQL(`select count(*) as c from ${provider}_pull_requests as gpr inner join ${provider}_installation_repositories as gir on gir.id = gpr.repository where gir.owner = ${o} and gir.name = ${r} and gpr.state = 'open'`),
        executeMQL(`select rc.sha as sha, rc.kind as kind, rc.branch as branch, rc.created_at as created_at, rc.data as data from repo_configs as rc inner join ${provider}_repositories_map as rm on rm.core_id = rc.repo inner join ${provider}_installation_repositories as gir on gir.id = rm.repository_id where gir.owner = ${o} and gir.name = ${r} order by rc.created_at desc limit 1`),
      ]);
      const wsRows: WsRow[] = ws.data.map((x) => {
        const w = x as Record<string, unknown>;
        return { dir: asText(w.dir), workspace: asText(w.workspace), env: asText(w.environment), lastRun: asText(w.last_run), runCount: asNumber(w.c) };
      });
      const runRows: RunRow[] = recent.map((x) => {
        const w = x as Record<string, unknown>;
        return { id: asText(w.id), state: asText(w.state), failCount: asNumber(w.fail_count), runType: asText(w.run_type), runKind: asText(w.run_kind), createdAt: asText(w.created_at), pullNumber: asText(w.pull_number) };
      });
      const c1 = (res: { data: unknown[] }) => asNumber((res.data[0] as Record<string, unknown> | undefined)?.c);
      const cfg = configRes.data[0] as Record<string, unknown> | undefined;
      setConfig(cfg ? {
        sha: asText(cfg.sha), kind: asText(cfg.kind), branch: asText(cfg.branch),
        data: (cfg.data ?? null) as Record<string, unknown> | null,
      } : null);
      setWorkspaces(wsRows);
      setRuns(runRows);
      setOverview({
        workspaces: c1(wsTotal),
        openPullRequests: c1(openPrs),
        drift: c1(drift),
        totalRuns: c1(total),
        lastActivity: runRows[0]?.createdAt ?? "",
      });
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load repository");
    }
  }, [missing, provider, owner, repo]);
  useInitialLoad(load);

  if (unavailable) return <OrchestrationUnavailable />;
  const shownError = error ?? (missing ? "Missing repository parameters." : null);
  const openWorkspace = (w: WsRow) =>
    router.push(`/workspaces/detail?provider=${provider}&owner=${enc(owner)}&repo=${enc(repo)}&dir=${enc(w.dir)}&workspace=${enc(w.workspace)}`);
  const hasEnv = (workspaces ?? []).some((w) => Boolean(w.env) && w.env !== "—");
  const externalUrl = projectUrl(provider, owner, repo);

  return (
    <div className="flex flex-col h-full">
      <header className="px-4 sm:px-6 pt-6 pb-3 border-b border-[var(--sg-border)]">
        <Breadcrumbs items={[{ label: "Repositories", href: "/repositories" }, { label: `${owner}/${repo}` }]} />
        <div className="flex items-center gap-3 mt-2">
          <button {...router.nav("/repositories")} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Back to repositories">
            <ArrowLeft className="w-4 h-4 text-[var(--sg-text-muted)]" />
          </button>
          <h1 className="text-lg font-semibold text-[var(--sg-text)] font-mono truncate">{owner}/{repo}</h1>
          {externalUrl && (
            <a href={externalUrl} target="_blank" rel="noopener noreferrer" className="shrink-0 whitespace-nowrap inline-flex items-center gap-1 text-xs text-[var(--sg-accent)] hover:underline">
              View on {providerName(provider)} <ExternalLink className="w-3 h-3" />
            </a>
          )}
          <button onClick={() => void load()} className="ml-auto p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
            <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-4 sm:px-6 py-4 space-y-5">
        {shownError ? (
          <div className="p-3 rounded-lg bg-[var(--sg-error-bg)] border border-[var(--sg-error)]/30 text-sm text-[var(--sg-error)]">{shownError}</div>
        ) : workspaces === null ? (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>
        ) : (
          <>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              {/* Each card opens the matching list, pre-filtered through that list's own URL params. */}
              <StatCard
                label="Workspaces"
                value={String(overview?.workspaces ?? 0)}
                icon={Layers}
                href={`/workspaces?q=${enc(`${owner}/${repo}`)}`}
              />
              <StatCard
                label={`Open ${prNoun(provider)}s`}
                value={String(overview?.openPullRequests ?? 0)}
                icon={GitPullRequest}
                href={`/pull-requests?repo=${enc(`${owner}/${repo}`)}&status=open`}
              />
              <StatCard
                label="Drift runs"
                value={String(overview?.drift ?? 0)}
                icon={GitCompare}
                href={`/runs?repo=${enc(`${owner}/${repo}`)}&rkind=drift`}
              />
              <StatCard
                label="Total runs"
                value={(overview?.totalRuns ?? 0).toLocaleString()}
                icon={PlayCircle}
                href={`/runs?repo=${enc(`${owner}/${repo}`)}`}
              />
            </div>
            {overview?.lastActivity && (
              <div className="text-xs text-[var(--sg-text-muted)]" title={formatAbsoluteTime(overview.lastActivity)}>
                Last activity {formatRelativeTime(overview.lastActivity)}
              </div>
            )}

            <div>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2">
                Workspaces
                {(overview?.workspaces ?? 0) > WS_LIST_CAP && (
                  <span className="ml-2 text-xs font-normal text-[var(--sg-text-dim)]">
                    showing the {WS_LIST_CAP} most recently run of {overview?.workspaces}
                  </span>
                )}
              </div>
              {workspaces.length === 0 ? (
                <div className="p-6 text-sm text-[var(--sg-text-muted)]">No workspaces in this repository yet.</div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Workspace</TableHead>
                        {hasEnv && (
                          <WorkflowEnvHeader />
                        )}
                        <TableHead>Runs</TableHead>
                        <TableHead>Last run</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {workspaces.map((w) => (
                        <TableRow key={`${w.dir}|${w.workspace}`} className="cursor-pointer" onClick={() => openWorkspace(w)}>
                          <TableCell className="font-medium text-[var(--sg-text)]">
                            <span className="font-mono">{w.dir || "."}</span>{" "}
                            <span className="text-[var(--sg-text-muted)]">· {w.workspace}</span>
                          </TableCell>
                          {hasEnv && <TableCell className="text-[var(--sg-text-muted)]">{w.env || "—"}</TableCell>}
                          <TableCell className="text-[var(--sg-text-muted)]">{w.runCount}</TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]" title={w.lastRun ? formatAbsoluteTime(w.lastRun) : undefined}>
                            {w.lastRun ? formatRelativeTime(w.lastRun) : "—"}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </div>

            <div>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2">Recent runs</div>
              {runs.length === 0 ? (
                <div className="p-6 text-sm text-[var(--sg-text-muted)]">No runs yet.</div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden divide-y divide-[var(--sg-border)]">
                  {runs.map((r) => (
                    <button
                      key={r.id}
                      {...router.nav(`/runs/wm?id=${r.id}`)}
                      className="w-full flex items-center gap-3 px-4 py-2 text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                    >
                      <OutcomeChip outcome={runListOutcome(r.state, r.failCount)} rawState={r.state} />
                      <span className="text-xs text-[var(--sg-text-muted)]">{r.runType}<span className="text-[var(--sg-text-dim)]"> · {runKindLabel(r.runKind)}</span></span>
                      {r.pullNumber ? <span className="text-xs text-[var(--sg-text-dim)]">{prSigil(provider)}{r.pullNumber}</span> : null}
                      <span className="ml-auto text-xs text-[var(--sg-text-muted)]">{formatRelativeTime(r.createdAt)}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            {config && (
              <div>
                <div className="text-sm font-medium text-[var(--sg-text)] mb-2">Configuration</div>
                <ConfigPanel config={config} />
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export default function RepositoryDetailPage() {
  return (
    <Suspense fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}>
      <RepositoryDetailContent />
    </Suspense>
  );
}

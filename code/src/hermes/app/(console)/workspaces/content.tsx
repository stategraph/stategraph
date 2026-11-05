"use client";

import { useCallback, useMemo, useState } from "react";
import { RefreshCw, Lock, ArrowUpRight } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks";
import { OutcomeChip } from "@/components/wm";
import { runOutcomeFromSuccess } from "@/lib/wm/decode";
import { VCS_PROVIDERS, asText, orchestrationUnavailable } from "@/lib/mql/providers";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import type { VcsProvider } from "@/lib/vcs/links";
import { IDENTITY_CELL_WIDTH, ListToolbar, WorkflowEnvHeader } from "@/components/list";
import { AsyncSection, PageHeader } from "@/components/page";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { matchesOwner, ownerFacetOptions } from "@/lib/vcs/ownerFacet";
import { matchesSearch } from "@/lib/ui/search";
import { usePagination } from "@/hooks/usePagination";
import { PaginationControls } from "@/components/instances/PaginationControls";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import { formatRelativeTime } from "@/lib/utils/time";
import {
  WS_CAP,
  lockKey,
  mapWsGroupRow,
  workspaceLocksQuery,
  workspacesQuery,
} from "./mqlQueries";

const PAGE_SIZE = 50;

// One breakpoint for the Workflow env column: the header and the cell must
// agree or the column misaligns, so they read it from here rather than
// repeating the literal.
const ENV_COL = "hidden xl:table-cell";

const enc = encodeURIComponent;

interface WsRow {
  key: string;
  provider: VcsProvider;
  owner: string;
  repoName: string;
  repo: string;
  dir: string;
  workspace: string;
  state: string;
  /** The latest run's dirspace result (null when it has no result row); folded
   *  with its lifecycle state into an outcome, as the workspace page does. */
  success: boolean | null;
  runType: string;
  env: string;
  when: string;
  runCount: number;
  locked: boolean;
  stateId: string | null;
}

function StatePill({ state, success }: { state: string; success: boolean | null }) {
  if (!state) {
    return (
      <span className="inline-flex items-center rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-2 py-0.5 text-xs text-[var(--sg-text-muted)]">
        —
      </span>
    );
  }
  return <OutcomeChip outcome={runOutcomeFromSuccess(state, success)} rawState={state} />;
}

export function WorkspacesContent() {
  const router = useDeepLinkRouter();
  const [rows, setRows] = useState<WsRow[] | null>(null);
  const [failed, setFailed] = useState<VcsProvider[]>([]);
  const [capped, setCapped] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [query, setQuery] = useUrlSyncedParam("q", "");
  const [owner, setOwner] = useUrlSyncedParam("owner", "");
  const [env, setEnv] = useUrlSyncedParam("env", "");

  const load = useCallback(async () => {
    try {
      // `grouped` dedups server-side (GROUP BY) so the count is correct past the
      // WS_CAP row cap and carries the latest run's state/type; `locks` is
      // repo-scoped through the PR map. The work-manifest queries run per
      // provider (their tables are twinned); Stategraph states are native.
      let sawTableAccessErr = false;
      let firstFailure: unknown = null;
      const perProvider = await Promise.all(
        VCS_PROVIDERS.map(async (p) => {
          try {
            const [grouped, locks] = await Promise.all([
              executeMQL(workspacesQuery(p)),
              executeMQL(workspaceLocksQuery(p)),
            ]);
            return { provider: p, grouped: grouped.data, locks: locks.data, ok: true };
          } catch (e) {
            if (orchestrationUnavailable(e)) sawTableAccessErr = true;
            firstFailure ??= e;
            return { provider: p, grouped: [] as unknown[], locks: [] as unknown[], ok: false };
          }
        }),
      );

      // One provider failing only drops its rows (surfaced via `failed`);
      // every provider failing is either orchestration being off or a real
      // error, which must not render as "no workspaces yet".
      if (!perProvider.some((r) => r.ok)) {
        if (sawTableAccessErr) {
          setUnavailable(true);
          return;
        }
        throw firstFailure;
      }

      const states = await executeMQL(
        "select id, name, workspace from states order by updated_at desc limit 1000",
      ).catch(() => ({ data: [] as unknown[] }));

      // Best-effort state bridge: a workspace's directory maps to a Stategraph
      // state of the same name. Heuristic (matches on name only, first hit by
      // recency wins) until a firm correlation key exists — labeled in the UI.
      const stateByName = new Map<string, string>();
      for (const r of states.data) {
        const o = r as Record<string, unknown>;
        const name = asText(o.name);
        if (name && !stateByName.has(name)) stateByName.set(name, asText(o.id));
      }

      const out: WsRow[] = [];
      const seen = new Set<string>();
      for (const { provider, grouped, locks } of perProvider) {
        const locked = new Set<string>();
        for (const r of locks) {
          const o = r as Record<string, unknown>;
          locked.add(lockKey(asText(o.owner), asText(o.name), asText(o.path), asText(o.workspace)));
        }
        for (const raw of grouped) {
          const g = mapWsGroupRow(raw);
          const repo = `${g.repoOwner}/${g.repoName}`;
          const key = `${provider}|${repo}|${g.dir}|${g.workspace}`;
          // Two runs of one dirspace sharing a created_at would both join back
          // as "latest"; keep one row per key so React keys stay unique.
          if (seen.has(key)) continue;
          seen.add(key);
          out.push({
            key,
            provider,
            owner: g.repoOwner,
            repoName: g.repoName,
            repo,
            dir: g.dir,
            workspace: g.workspace,
            state: g.state,
            success: g.success,
            runType: g.runType,
            env: g.environment,
            when: g.lastRun,
            runCount: g.runCount,
            locked: locked.has(lockKey(g.repoOwner, g.repoName, g.dir, g.workspace)),
            stateId: stateByName.get(g.dir) ?? null,
          });
        }
      }
      out.sort((a, b) => b.when.localeCompare(a.when));
      setRows(out);
      setFailed(perProvider.filter((r) => !r.ok).map((r) => r.provider));
      setCapped(perProvider.some((r) => r.grouped.length >= WS_CAP));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load workspaces");
    }
  }, []);
  useInitialLoad(load);

  const openDetail = (r: WsRow) =>
    router.push(
      `/workspaces/detail?provider=${r.provider}&owner=${enc(r.owner)}&repo=${enc(r.repoName)}&dir=${enc(r.dir)}&workspace=${enc(r.workspace)}`,
    );

  const envs = useMemo(() => [...new Set((rows ?? []).map((r) => r.env).filter((e) => e && e !== "—"))].sort(), [rows]);
  const owners = useMemo(() => ownerFacetOptions(rows ?? []), [rows]);
  const hasEnv = envs.length > 0;
  const filtered = useMemo(() => {
    return (rows ?? []).filter((r) => {
      if (!matchesOwner(owner, r.provider, r.owner)) return false;
      if (env && r.env !== env) return false;
      if (!matchesSearch(query, `${r.repo} ${r.dir} ${r.workspace}`)) return false;
      return true;
    });
  }, [rows, query, owner, env]);
  const page = usePagination(filtered, PAGE_SIZE, `${query}|${owner}|${env}`);

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Workspaces"
        subtitle="Every (repo, directory, workspace) under management and its latest run"
      >
        <button onClick={() => void load()} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
          <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
        </button>
      </PageHeader>
      <div className="flex-1 overflow-y-auto px-4 sm:px-6 py-4">
        <AsyncSection
          loading={rows === null && !error}
          error={error}
          empty={rows?.length === 0}
          emptyState={
            <OrchestrationEmptyState>
              <div className="p-8 text-sm text-[var(--sg-text-muted)]">
                No workspaces yet. They appear once Stategraph Orchestration runs plans or applies on your
                repositories.
              </div>
            </OrchestrationEmptyState>
          }
          onRetry={() => void load()}
        >
            {failed.length > 0 && (
              <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
                Could not load {failed.join(", ")} workspaces — showing the rest.
              </div>
            )}
            <ListToolbar
              search={query}
              onSearch={setQuery}
              placeholder="Search by repo, directory, workspace…"
              filters={[
                ...(owners.length > 1 || owner ? [{ label: "Owners", value: owner, onChange: setOwner, options: owners }] : []),
                ...(envs.length > 1 || env ? [{ label: "Environments", value: env, onChange: setEnv, options: envs.map((e) => ({ label: e, value: e })) }] : []),
              ]}
            />
            {capped && (
              <div className="mb-2 text-xs text-[var(--sg-text-dim)]">
                Showing up to {WS_CAP} workspaces per provider.
              </div>
            )}
            {filtered.length === 0 ? (
              <div className="p-8 text-sm text-[var(--sg-text-muted)]">No workspaces match these filters.</div>
            ) : (
              <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Workspace</TableHead>
                      <TableHead className="hidden md:table-cell">Repository</TableHead>
                      <TableHead>Last run</TableHead>
                      <TableHead className="hidden xl:table-cell">Runs</TableHead>
                      {hasEnv && (
                        <WorkflowEnvHeader className={ENV_COL} />
                      )}
                      <TableHead className="hidden xl:table-cell">Updated</TableHead>
                      <TableHead className="hidden md:table-cell">State</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {page.pageItems.map((r) => (
                      <TableRow key={r.key} className="cursor-pointer" onClick={() => openDetail(r)}>
                        <TableCell className="font-medium text-[var(--sg-text)]">
                          <div className={`flex items-center gap-1.5 ${IDENTITY_CELL_WIDTH}`}>
                            <span
                              className="truncate"
                              title={`${r.dir || "."} · ${r.workspace}${r.locked ? " · locked" : ""}`}
                            >
                              <span className="font-mono">{r.dir || "."}</span>{" "}
                              <span className="text-[var(--sg-text-muted)]">· {r.workspace}</span>
                            </span>
                            {r.locked ? (
                              <Lock
                                className="shrink-0 h-3 w-3 text-[var(--sg-warning)]"
                                aria-label="Locked"
                              />
                            ) : null}
                          </div>
                        </TableCell>
                        <TableCell className="hidden md:table-cell">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              router.push(`/repositories/detail?provider=${r.provider}&owner=${enc(r.owner)}&repo=${enc(r.repoName)}`);
                            }}
                            className="text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] hover:underline"
                          >
                            {r.repo}
                          </button>
                        </TableCell>
                        <TableCell>
                          <StatePill state={r.state} success={r.success} />{" "}
                          {r.runType ? (
                            <span className="text-xs text-[var(--sg-text-dim)]">{r.runType}</span>
                          ) : null}
                        </TableCell>
                        <TableCell className="hidden xl:table-cell text-[var(--sg-text-muted)]">{r.runCount}</TableCell>
                        {hasEnv && <TableCell className={`${ENV_COL} text-[var(--sg-text-muted)]`}>{r.env || "—"}</TableCell>}
                        <TableCell className="hidden xl:table-cell text-[var(--sg-text-muted)]">
                          {r.when ? formatRelativeTime(r.when) : "—"}
                        </TableCell>
                        <TableCell className="hidden md:table-cell">
                          {r.stateId ? (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                router.push(`/states/detail?id=${r.stateId}`);
                              }}
                              title="Matched to a Stategraph state by directory name (heuristic)"
                              className="inline-flex items-center gap-1 text-xs text-[var(--sg-accent)] hover:underline"
                            >
                              View <ArrowUpRight className="h-3 w-3" />
                            </button>
                          ) : (
                            <span className="text-xs text-[var(--sg-text-dim)]">—</span>
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
                {page.totalPages > 1 && (
                  <PaginationControls
                    currentPage={page.page}
                    totalPages={page.totalPages}
                    totalResults={page.total}
                    pageSize={PAGE_SIZE}
                    hasNext={page.hasNext}
                    hasPrevious={page.hasPrevious}
                    onNext={page.next}
                    onPrevious={page.previous}
                  />
                )}
              </div>
            )}
        </AsyncSection>
      </div>
    </div>
  );
}

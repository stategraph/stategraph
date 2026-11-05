"use client";

import { useCallback, useMemo, useState } from "react";
import { GitPullRequest, RefreshCw } from "lucide-react";
import { MQL_MAX_LIMIT, asNumber, asText, loadAcrossProviders, orchestrationUnavailable } from "@/lib/mql/providers";
import { groupRepoOptions, matchesOwner, ownerFacetOptions } from "@/lib/vcs/ownerFacet";
import { matchesSearch } from "@/lib/ui/search";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import { PageHeader } from "@/components/page";
import { prSigil, type VcsProvider } from "@/lib/vcs/links";
import { useDeepLinkRouter } from "@/hooks";
import { usePagination } from "@/hooks/usePagination";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import {
  formatAbsoluteTime,
  formatRelativeTime,
} from "@/lib/utils/time";
import { OutcomeChip } from "@/components/wm";
import { runListOutcome, runKindLabel } from "@/lib/wm/decode";
import { withFailCounts } from "@/lib/wm/failCounts";
import { ListToolbar } from "@/components/list/ListToolbar";
import { PaginationControls } from "@/components/instances/PaginationControls";

const PAGE_SIZE = 25;
/** Newest runs fetched per provider; the list filters and pages locally. */
const WM_RUNS_CAP = Math.min(500, MQL_MAX_LIMIT);
const enc = encodeURIComponent;

// A Terrateam orchestration run (work-manifest), read via MQL. Hand-written
// type: these tables live outside api.json, so no generated type exists.
interface WmRow {
  provider: VcsProvider;
  id: string;
  state: string;
  created_at: string;
  completed_at: string | null;
  username: string | null;
  run_type: string | null;
  run_kind: string | null;
  branch: string | null;
  repo_owner: string | null;
  repo_name: string | null;
  pull_number: string | null;
  /** Failed step rows joined in the list query; folds state into an outcome. */
  fail_count: number;
}

const wmOpt = (v: unknown): string | null =>
  typeof v === "string" ? v : typeof v === "number" ? String(v) : null;

function toWmRow(provider: VcsProvider, r: unknown): WmRow {
  const o = (r ?? {}) as Record<string, unknown>;
  return {
    provider,
    id: asText(o.id),
    state: asText(o.state),
    created_at: asText(o.created_at),
    completed_at: wmOpt(o.completed_at),
    username: wmOpt(o.username),
    run_type: wmOpt(o.run_type),
    run_kind: wmOpt(o.run_kind),
    branch: wmOpt(o.branch),
    repo_owner: wmOpt(o.repo_owner),
    repo_name: wmOpt(o.repo_name),
    pull_number: wmOpt(o.pull_number),
    fail_count: asNumber(o.fail_count),
  };
}

// Renders one orchestration run. Row click opens the work-manifest detail;
// the repository and pull-request cells are their own links (stopPropagation).
function OrchestrationRow({ wm }: { wm: WmRow }) {
  const router = useDeepLinkRouter();
  const isDrift = wm.run_kind === "drift";
  return (
    <tr
      {...router.nav(`/runs/wm?id=${wm.id}`)}
      className="border-b border-[var(--sg-border-light)] cursor-pointer hover:bg-[var(--sg-bg-2)]"
    >
      <td className="px-4 sm:px-6 py-2">
        <OutcomeChip outcome={runListOutcome(wm.state, wm.fail_count)} rawState={wm.state} />
      </td>
      <td className="hidden md:table-cell px-4 sm:px-6 py-2 text-[var(--sg-text)]">
        {wm.repo_owner && wm.repo_name ? (
          <span className="font-mono text-xs">{wm.repo_owner}/{wm.repo_name}</span>
        ) : (
          "—"
        )}
      </td>
      <td className="px-4 sm:px-6 py-2">
        {isDrift ? (
          <span className="inline-block px-2 py-0.5 text-[10px] uppercase tracking-wide font-medium rounded border bg-[var(--sg-warning-bg)] text-[var(--sg-warning)] border-[var(--sg-warning)]">
            Drift
          </span>
        ) : (
          <span className="font-mono text-xs text-[var(--sg-text-dim)]">
            {wm.run_type ?? "run"}
          </span>
        )}
      </td>
      <td className="hidden xl:table-cell px-4 sm:px-6 py-2 text-[var(--sg-text)]">
        {wm.pull_number && wm.repo_owner && wm.repo_name ? (
          <button
            type="button"
            {...router.nav(
              `/pull-requests/detail?provider=${wm.provider}&owner=${enc(wm.repo_owner)}&repo=${enc(wm.repo_name)}&pr=${enc(wm.pull_number)}`,
            )}
            className="inline-flex items-center gap-1 text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] hover:underline"
          >
            <GitPullRequest className="w-3 h-3" /> {prSigil(wm.provider)}{wm.pull_number}
          </button>
        ) : isDrift ? (
          <span className="text-[var(--sg-text-muted)]">scheduled</span>
        ) : (
          <span className="font-mono text-xs text-[var(--sg-text-muted)]">
            {wm.branch ?? "—"}
          </span>
        )}
      </td>
      <td className="hidden xl:table-cell px-4 sm:px-6 py-2 text-[var(--sg-text)]">{wm.username ?? "—"}</td>
      <td
        className="px-4 sm:px-6 py-2 text-[var(--sg-text-muted)]"
        title={formatAbsoluteTime(wm.created_at)}
      >
        {formatRelativeTime(wm.created_at)}
      </td>
    </tr>
  );
}

/**
 * Runs screen: Terrateam VCS work-manifest runs (plan/apply/drift), read via
 * MQL. The search and the owner/repo/run-type/kind facets sync to the URL
 * (?q=/?owner=/?repo=/?rtype=/?rkind=) so a filtered list is shareable.
 */
export function RunsContent() {
  const [rows, setRows] = useState<WmRow[] | null>(null);
  const [failed, setFailed] = useState<VcsProvider[]>([]);
  const [capped, setCapped] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [query, setQuery] = useUrlSyncedParam("q", "");
  const [ownerFacet, setOwnerFacet] = useUrlSyncedParam("owner", "");
  const [repoFacet, setRepoFacet] = useUrlSyncedParam("repo", "");
  const [runTypeFacet, setRunTypeFacet] = useUrlSyncedParam("rtype", "");
  const [kindFacet, setKindFacet] = useUrlSyncedParam("rkind", "");

  const load = useCallback(async () => {
    try {
      const res = await loadAcrossProviders(
        (p) =>
          `select wm.id as id, wm.state as state, wm.created_at as created_at, wm.completed_at as completed_at, wm.username as username, wm.run_type as run_type, wm.run_kind as run_kind, wm.branch as branch, wm.repo_owner as repo_owner, wm.repo_name as repo_name, wm.pull_number as pull_number from ${p}_work_manifests as wm order by wm.created_at desc limit ${WM_RUNS_CAP}`,
        toWmRow,
        WM_RUNS_CAP,
        // work_manifests only carry a lifecycle state (queued/running/
        // completed/aborted); success or failure lives on the run's step
        // outputs, counted for the listed runs only.
        (rows) => withFailCounts(rows),
      );
      res.rows.sort((a, b) => b.created_at.localeCompare(a.created_at));
      setRows(res.rows);
      setFailed(res.failed);
      setCapped(res.capped);
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) {
        setUnavailable(true);
        return;
      }
      setError(e instanceof Error ? e.message : "Failed to load orchestration runs");
    }
  }, []);
  useInitialLoad(load);

  const owners = useMemo(
    () =>
      ownerFacetOptions(
        (rows ?? []).map((r) => ({ provider: r.provider, owner: r.repo_owner ?? "" })),
      ),
    [rows],
  );
  const repos = useMemo(
    () =>
      [
        ...new Set(
          (rows ?? [])
            .filter((r) => r.repo_owner && r.repo_name)
            .map((r) => `${r.repo_owner}/${r.repo_name}`),
        ),
      ].sort(),
    [rows],
  );
  const repoGroups = useMemo(
    () =>
      groupRepoOptions(
        (rows ?? []).map((r) => ({
          provider: r.provider,
          owner: r.repo_owner ?? "",
          name: r.repo_name ?? "",
        })),
      ),
    [rows],
  );
  const types = useMemo(
    () => [...new Set((rows ?? []).map((r) => r.run_type).filter((v): v is string => !!v))].sort(),
    [rows],
  );
  const kinds = useMemo(
    () => [...new Set((rows ?? []).map((r) => r.run_kind).filter((v): v is string => !!v))].sort(),
    [rows],
  );

  const filtered = useMemo(() => {
    return (rows ?? []).filter((r) => {
      if (!matchesOwner(ownerFacet, r.provider, r.repo_owner ?? "")) return false;
      if (repoFacet && `${r.repo_owner}/${r.repo_name}` !== repoFacet) return false;
      if (runTypeFacet && r.run_type !== runTypeFacet) return false;
      if (kindFacet && r.run_kind !== kindFacet) return false;
      if (
        !matchesSearch(
          query,
          `${r.repo_owner}/${r.repo_name} ${r.run_type ?? ""} ${r.run_kind ?? ""} ${r.branch ?? ""} ${r.username ?? ""} ${r.pull_number ?? ""}`,
        )
      )
        return false;
      return true;
    });
  }, [rows, query, ownerFacet, repoFacet, runTypeFacet, kindFacet]);

  const page = usePagination(
    filtered,
    PAGE_SIZE,
    `${query}|${ownerFacet}|${repoFacet}|${runTypeFacet}|${kindFacet}`,
  );

  if (unavailable) {
    return <OrchestrationUnavailable />;
  }
  if (error) {
    return <div className="p-8 text-[var(--sg-error)]">{error}</div>;
  }
  if (rows === null) {
    return <div className="p-8 text-[var(--sg-text-muted)]">Loading runs…</div>;
  }

  const filtersActive =
    query.trim() !== "" ||
    ownerFacet !== "" ||
    repoFacet !== "" ||
    runTypeFacet !== "" ||
    kindFacet !== "";

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Runs"
        subtitle="Plan and apply runs triggered from version control, plus scheduled drift; newest first"
      >
        <button onClick={() => void load()} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
          <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
        </button>
      </PageHeader>
      <div className="px-4 sm:px-6 pt-4 pb-3 border-b border-[var(--sg-border)]">
        {failed.length > 0 && (
          <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
            Could not load {failed.join(", ")} runs — showing the rest.
          </div>
        )}
        <ListToolbar
          search={query}
          onSearch={setQuery}
          placeholder="Search by repo, branch, author, run type…"
          filters={[
            ...(owners.length > 1 || ownerFacet
              ? [
                  {
                    label: "Owners",
                    value: ownerFacet,
                    onChange: setOwnerFacet,
                    options: owners,
                  },
                ]
              : []),
            ...(repos.length > 1 || repoFacet
              ? [
                  {
                    label: "Repositories",
                    value: repoFacet,
                    onChange: setRepoFacet,
                    options: repos.map((x) => ({ label: x, value: x })),
                    groups: repoGroups,
                  },
                ]
              : []),
            ...(types.length > 1 || runTypeFacet
              ? [
                  {
                    label: "Run types",
                    value: runTypeFacet,
                    onChange: setRunTypeFacet,
                    options: types.map((x) => ({ label: x, value: x })),
                  },
                ]
              : []),
            ...(kinds.length > 1 || kindFacet
              ? [
                  {
                    label: "Kinds",
                    value: kindFacet,
                    onChange: setKindFacet,
                    options: kinds.map((x) => ({ label: runKindLabel(x), value: x })),
                  },
                ]
              : []),
          ]}
        />
        <div className="text-xs text-[var(--sg-text-muted)]">
          <strong className="text-[var(--sg-text)]">{filtered.length}</strong>{" "}
          {filtered.length === 1 ? "run" : "runs"}
          {filtersActive && rows.length !== filtered.length && (
            <> (of {rows.length} loaded)</>
          )}
          {capped && <> · showing the latest {WM_RUNS_CAP} per provider</>}
        </div>
      </div>

      {rows.length === 0 ? (
        <OrchestrationEmptyState>
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">
            No orchestration runs yet.
          </div>
        </OrchestrationEmptyState>
      ) : filtered.length === 0 ? (
        <div className="p-8 text-sm text-[var(--sg-text-muted)]">
          No orchestration runs match the current filters.
        </div>
      ) : (
        <div className="flex-1 overflow-auto">
          <table className="w-full text-sm">
            <thead className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)] bg-[var(--sg-bg-2)] border-b border-[var(--sg-border)]">
              <tr>
                <th className="text-left px-4 sm:px-6 py-2 font-medium">State</th>
                <th className="hidden md:table-cell text-left px-4 sm:px-6 py-2 font-medium">Repository</th>
                <th className="text-left px-4 sm:px-6 py-2 font-medium">Run</th>
                <th className="hidden xl:table-cell text-left px-4 sm:px-6 py-2 font-medium">Trigger</th>
                <th className="hidden xl:table-cell text-left px-4 sm:px-6 py-2 font-medium">By</th>
                <th className="text-left px-4 sm:px-6 py-2 font-medium">Created</th>
              </tr>
            </thead>
            <tbody>
              {page.pageItems.map((wm) => (
                <OrchestrationRow key={wm.id} wm={wm} />
              ))}
            </tbody>
          </table>
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
    </div>
  );
}

"use client";

import { useCallback, useMemo, useState } from "react";
import { ExternalLink, RefreshCw } from "lucide-react";
import { pullRequestUrl, prSigil, providerName } from "@/lib/vcs/links";
import { loadAcrossProviders, orchestrationUnavailable } from "@/lib/mql/providers";
import { groupRepoOptions, matchesOwner, ownerFacetOptions } from "@/lib/vcs/ownerFacet";
import { matchesSearch } from "@/lib/ui/search";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import { AsyncSection, PageHeader } from "@/components/page";
import { IDENTITY_CELL_WIDTH, ListToolbar } from "@/components/list";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { useDeepLinkRouter } from "@/hooks";
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
import { mapPrRow, PRS_CAP, pullRequestsQuery, effectiveStatusFilter, type PrRow } from "./mqlQueries";
import { PR_STATE_TONE, TONE_CLASS, toneOf } from "@/components/status/tones";

const PAGE_SIZE = 50;

const ts = (iso: string): number => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : 0;
};

function StatePill({ state }: { state: string }) {
  return (
    <span
      className={`inline-flex items-center rounded-md border px-2 py-0.5 text-xs ${TONE_CLASS[toneOf(PR_STATE_TONE, state)]}`}
    >
      {state || "unknown"}
    </span>
  );
}

export function PullRequestsContent() {
  const router = useDeepLinkRouter();
  const [rows, setRows] = useState<PrRow[] | null>(null);
  const [failed, setFailed] = useState<string[]>([]);
  const [capped, setCapped] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [query, setQuery] = useUrlSyncedParam("q", "");
  // Defaults to open PRs; "all" is an explicit value so clearing the filter
  // survives the URL round-trip instead of re-defaulting to open.
  const [status, setStatus] = useUrlSyncedParam("status", "open");
  const [owner, setOwner] = useUrlSyncedParam("owner", "");
  const [repo, setRepo] = useUrlSyncedParam("repo", "");
  const [author, setAuthor] = useUrlSyncedParam("author", "");

  const load = useCallback(async () => {
    try {
      const res = await loadAcrossProviders(pullRequestsQuery, mapPrRow, PRS_CAP);
      // Newest first. Pull numbers only break ties (and order GitLab rows,
      // which carry no created_at): across repositories and providers the
      // numbering sequences are unrelated, so a bare pull_number sort would
      // interleave them meaninglessly.
      res.rows.sort(
        (a, b) =>
          ts(b.createdAt) - ts(a.createdAt) ||
          (Number(b.pullNumber) || 0) - (Number(a.pullNumber) || 0),
      );
      setRows(res.rows);
      setFailed(res.failed);
      setCapped(res.capped);
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load pull requests");
    }
  }, []);
  useInitialLoad(load);

  const states = useMemo(() => [...new Set((rows ?? []).map((r) => r.state).filter(Boolean))].sort(), [rows]);
  const owners = useMemo(() => ownerFacetOptions(rows ?? []), [rows]);
  const repos = useMemo(() => [...new Set((rows ?? []).map((r) => `${r.owner}/${r.name}`).filter(Boolean))].sort(), [rows]);
  const repoGroups = useMemo(() => groupRepoOptions(rows ?? []), [rows]);
  const authors = useMemo(() => [...new Set((rows ?? []).map((r) => r.username).filter(Boolean))].sort(), [rows]);
  const filtered = useMemo(() => {
    return (rows ?? []).filter((r) => {
      const statusFilter = effectiveStatusFilter(status);
      if (statusFilter && r.state !== statusFilter) return false;
      if (!matchesOwner(owner, r.provider, r.owner)) return false;
      if (repo && `${r.owner}/${r.name}` !== repo) return false;
      if (author && r.username !== author) return false;
      if (!matchesSearch(query, `${r.owner}/${r.name} ${prSigil(r.provider)}${r.pullNumber} ${r.title} ${r.branch} ${r.username}`)) return false;
      return true;
    });
  }, [rows, query, status, owner, repo, author]);
  const page = usePagination(filtered, PAGE_SIZE, `${query}|${status}|${owner}|${repo}|${author}`);

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Pull Requests"
        subtitle="Pull requests with their plan and apply status"
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
            <OrchestrationEmptyState centered>
              <div className="p-8 text-center text-sm text-[var(--sg-text-muted)]">No pull requests yet.</div>
            </OrchestrationEmptyState>
          }
          onRetry={() => void load()}
        >
          {failed.length > 0 && (
            <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
              Could not load {failed.join(", ")} pull requests — showing the rest.
            </div>
          )}
          <ListToolbar
            search={query}
            onSearch={setQuery}
            placeholder="Search by repo, title, branch, author…"
            filters={[
              ...(owners.length > 1 || owner ? [{ label: "Owners", value: owner, onChange: setOwner, options: owners }] : []),
              ...(repos.length > 1 || repo ? [{ label: "Repositories", value: repo, onChange: setRepo, options: repos.map((x) => ({ label: x, value: x })), groups: repoGroups }] : []),
              ...(states.length > 1 || effectiveStatusFilter(status)
                ? [{
                    label: "States",
                    // "all" renders as the toolbar's built-in All option. The
                    // effective filter (open when ?status= is absent or empty)
                    // is always offered, so the select never reads "All
                    // states" -- or disappears -- over a list filtered to open.
                    value: effectiveStatusFilter(status),
                    onChange: (v: string) => setStatus(v === "" ? "all" : v),
                    options: [...new Set([effectiveStatusFilter(status), ...states].filter(Boolean))]
                      .sort()
                      .map((x) => ({ label: x, value: x })),
                  }]
                : []),
              ...(authors.length > 1 || author ? [{ label: "Authors", value: author, onChange: setAuthor, options: authors.map((x) => ({ label: x, value: x })) }] : []),
            ]}
          />
          {capped && (
            <div className="mb-2 text-xs text-[var(--sg-text-dim)]">
              Showing the most recent {PRS_CAP} pull requests per provider.
            </div>
          )}
          {filtered.length === 0 ? (
            <div className="p-8 text-sm text-[var(--sg-text-muted)]">No pull requests match these filters.</div>
          ) : (
            <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Pull request</TableHead>
                    <TableHead className="hidden md:table-cell">Repository</TableHead>
                    <TableHead className="hidden xl:table-cell">Branch</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="hidden xl:table-cell">Author</TableHead>
                    <TableHead className="hidden xl:table-cell"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {page.pageItems.map((r) => {
                    const url = pullRequestUrl(r.provider, r.owner, r.name, r.pullNumber);
                    return (
                      <TableRow
                        key={`${r.provider}-${r.repoId}-${r.pullNumber}`}
                        className="cursor-pointer"
                        {...router.nav(`/pull-requests/detail?provider=${r.provider}&owner=${encodeURIComponent(r.owner)}&repo=${encodeURIComponent(r.name)}&pr=${encodeURIComponent(r.pullNumber)}`)}
                      >
                        <TableCell className="font-medium text-[var(--sg-text)]">
                          <div className={`truncate ${IDENTITY_CELL_WIDTH}`} title={r.title}>
                            {prSigil(r.provider)}{r.pullNumber} {r.title}
                          </div>
                        </TableCell>
                        <TableCell className="hidden md:table-cell text-[var(--sg-text-muted)] font-mono">{r.owner}/{r.name}</TableCell>
                        <TableCell className="hidden xl:table-cell text-[var(--sg-text-muted)]"><div className="truncate max-w-[200px]" title={`${r.branch} → ${r.baseBranch}`}>{r.branch} → {r.baseBranch}</div></TableCell>
                        <TableCell><StatePill state={r.state} /></TableCell>
                        <TableCell className="hidden xl:table-cell text-[var(--sg-text-muted)]">{r.username || "—"}</TableCell>
                        <TableCell className="hidden xl:table-cell">
                          {url && (
                            <a
                              href={url}
                              target="_blank"
                              rel="noopener noreferrer"
                              onClick={(e) => e.stopPropagation()}
                              className="inline-flex items-center gap-1 text-xs text-[var(--sg-accent)] hover:underline"
                            >
                              View on {providerName(r.provider)} <ExternalLink className="w-3 h-3" />
                            </a>
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })}
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

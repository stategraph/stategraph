"use client";

import { useCallback, useMemo, useState } from "react";
import { ExternalLink, RefreshCw } from "lucide-react";
import { projectUrl, providerName } from "@/lib/vcs/links";
import { loadAcrossProviders, orchestrationUnavailable } from "@/lib/mql/providers";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import { AsyncSection, PageHeader } from "@/components/page";
import { ListToolbar } from "@/components/list";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { useDeepLinkRouter } from "@/hooks";
import { usePagination } from "@/hooks/usePagination";
import { matchesSearch } from "@/lib/ui/search";
import { PaginationControls } from "@/components/instances/PaginationControls";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import { mapRepoRow, REPOS_CAP, repositoriesQuery, type RepoRow } from "./mqlQueries";

const PAGE_SIZE = 50;

export function RepositoriesContent() {
  const router = useDeepLinkRouter();
  const [rows, setRows] = useState<RepoRow[] | null>(null);
  const [failed, setFailed] = useState<string[]>([]);
  const [capped, setCapped] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [query, setQuery] = useUrlSyncedParam("q", "");
  const [owner, setOwner] = useUrlSyncedParam("owner", "");

  const load = useCallback(async () => {
    try {
      const res = await loadAcrossProviders(repositoriesQuery, mapRepoRow, REPOS_CAP);
      res.rows.sort((a, b) => `${a.owner}/${a.name}`.localeCompare(`${b.owner}/${b.name}`));
      setRows(res.rows);
      setFailed(res.failed);
      setCapped(res.capped);
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load repositories");
    }
  }, []);
  useInitialLoad(load);

  const owners = useMemo(() => [...new Set((rows ?? []).map((r) => r.owner).filter(Boolean))].sort(), [rows]);
  const filtered = useMemo(() => {
    return (rows ?? []).filter((r) => {
      if (owner && r.owner !== owner) return false;
      if (!matchesSearch(query, `${r.owner}/${r.name}`)) return false;
      return true;
    });
  }, [rows, query, owner]);
  const page = usePagination(filtered, PAGE_SIZE, `${query}|${owner}`);

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Repositories"
        subtitle="Repositories under infrastructure automation"
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
              <div className="p-8 text-center text-sm text-[var(--sg-text-muted)]">No repositories under automation yet.</div>
            </OrchestrationEmptyState>
          }
          onRetry={() => void load()}
        >
          {failed.length > 0 && (
            <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
              Could not load {failed.join(", ")} repositories — showing the rest.
            </div>
          )}
          <ListToolbar
            search={query}
            onSearch={setQuery}
            placeholder="Search repositories…"
            filters={owners.length > 1 || owner ? [{ label: "Owners", value: owner, onChange: setOwner, options: owners.map((o) => ({ label: o, value: o })) }] : undefined}
          />
          {capped && (
            <div className="mb-2 text-xs text-[var(--sg-text-dim)]">
              Showing {REPOS_CAP} repositories per provider.
            </div>
          )}
          {filtered.length === 0 ? (
            <div className="p-8 text-sm text-[var(--sg-text-muted)]">No repositories match these filters.</div>
          ) : (
            <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Repository</TableHead>
                    <TableHead className="hidden md:table-cell">Owner</TableHead>
                    <TableHead className="hidden md:table-cell">Provider</TableHead>
                    <TableHead>Updated</TableHead>
                    <TableHead className="hidden md:table-cell"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {page.pageItems.map((r) => {
                    const url = projectUrl(r.provider, r.owner, r.name);
                    return (
                      <TableRow
                        key={`${r.provider}-${r.id}`}
                        className="cursor-pointer"
                        {...router.nav(`/repositories/detail?provider=${r.provider}&owner=${encodeURIComponent(r.owner)}&repo=${encodeURIComponent(r.name)}`)}
                      >
                        <TableCell className="font-medium text-[var(--sg-text)] font-mono">{r.name}</TableCell>
                        <TableCell className="hidden md:table-cell text-[var(--sg-text-muted)]">{r.owner}</TableCell>
                        <TableCell className="hidden md:table-cell text-[var(--sg-text-muted)]">{r.provider}</TableCell>
                        <TableCell className="text-[var(--sg-text-muted)]" title={r.updatedAt ? formatAbsoluteTime(r.updatedAt) : undefined}>
                          {r.updatedAt ? formatRelativeTime(r.updatedAt) : "—"}
                        </TableCell>
                        <TableCell className="hidden md:table-cell">
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

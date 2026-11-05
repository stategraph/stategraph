"use client";

import { useCallback, useMemo, useState } from "react";
import { OUTCOME_LABEL, OutcomeChip } from "@/components/wm";
import { runKindLabel, type Outcome } from "@/lib/wm/decode";
import { withFailCounts } from "@/lib/wm/failCounts";
import { Download, RefreshCw } from "lucide-react";
import { loadAcrossProviders, orchestrationUnavailable } from "@/lib/mql/providers";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import { AsyncSection, PageHeader } from "@/components/page";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { usePagination } from "@/hooks/usePagination";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { matchesOwner, ownerFacetOptions } from "@/lib/vcs/ownerFacet";
import { matchesSearch } from "@/lib/ui/search";
import { PaginationControls } from "@/components/instances/PaginationControls";
import { IDENTITY_CELL_WIDTH, ListToolbar } from "@/components/list";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import { prSigil, pullRequestUrl } from "@/lib/vcs/links";
import { downloadFile, timestampedFilename, toCsv } from "@/lib/export";
import { AUDIT_CAP, auditQuery, mapAuditRow, type AuditRow } from "./mqlQueries";

const PAGE_SIZE = 50;

const COLUMNS: { key: keyof AuditRow; label: string }[] = [
  { key: "createdAt", label: "created_at" },
  { key: "completedAt", label: "completed_at" },
  { key: "provider", label: "provider" },
  { key: "repoOwner", label: "repo_owner" },
  { key: "repoName", label: "repo_name" },
  { key: "runType", label: "run_type" },
  { key: "runKind", label: "run_kind" },
  { key: "state", label: "state" },
  { key: "outcome", label: "outcome" },
  { key: "username", label: "actor" },
  { key: "branch", label: "branch" },
  { key: "pullNumber", label: "pull_request" },
  { key: "id", label: "id" },
];

const toRecords = (rows: AuditRow[]): Record<string, unknown>[] =>
  rows.map((r) => Object.fromEntries(COLUMNS.map((c) => [c.label, r[c.key]])));

const uniq = (xs: string[]): string[] => [...new Set(xs.filter(Boolean))].sort();
const ts = (iso: string): number => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : 0;
};

export function AuditContent() {
  const [rows, setRows] = useState<AuditRow[] | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [failed, setFailed] = useState<string[]>([]);
  const [capped, setCapped] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [query, setQuery] = useUrlSyncedParam("q", "");
  const [owner, setOwner] = useUrlSyncedParam("owner", "");
  const [runType, setRunType] = useUrlSyncedParam("type", "");
  const [status, setStatus] = useUrlSyncedParam("status", "");

  const load = useCallback(async () => {
    setRefreshing(true);
    try {
      const res = await loadAcrossProviders(auditQuery, mapAuditRow, AUDIT_CAP, (rows) =>
        withFailCounts(rows),
      );
      res.rows.sort((a, b) => ts(b.createdAt) - ts(a.createdAt));
      setRows(res.rows);
      setFailed(res.failed);
      setCapped(res.capped);
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load audit stream");
    } finally {
      setRefreshing(false);
    }
  }, []);
  useInitialLoad(load);

  const runTypes = useMemo(() => (rows ? uniq(rows.map((r) => r.runType)) : []), [rows]);
  // The State column shows the run outcome, so filtering is by outcome too.
  const outcomes = useMemo(() => (rows ? uniq(rows.map((r) => r.outcome)) : []), [rows]);
  const owners = useMemo(
    () => ownerFacetOptions((rows ?? []).map((r) => ({ provider: r.provider, owner: r.repoOwner }))),
    [rows],
  );

  const filtered = useMemo(() => {
    if (!rows) return [];
    return rows.filter((r) => {
      if (!matchesOwner(owner, r.provider, r.repoOwner)) return false;
      if (runType && r.runType !== runType) return false;
      if (status && r.outcome !== status) return false;
      if (!matchesSearch(query, `${r.repoOwner}/${r.repoName} ${r.username} ${r.branch} ${r.pullNumber}`)) return false;
      return true;
    });
  }, [rows, query, owner, runType, status]);

  const page = usePagination(filtered, PAGE_SIZE, `${query}|${owner}|${runType}|${status}`);

  // An audit export is exactly the artifact that gets forwarded, so a partial
  // file must say so in the file itself, not only on screen (the doctrine in
  // lib/resource-types/export.ts). The JSON carries a self-describing
  // envelope; CSV has nowhere to put one without breaking parsers, so the
  // capped state goes in the filename.
  const exportBase = capped ? "audit-partial" : "audit";
  const exportCsv = () =>
    downloadFile(
      toCsv(
        COLUMNS.map((c) => c.label),
        filtered.map((r) => COLUMNS.map((c) => r[c.key])),
      ),
      timestampedFilename(exportBase, "csv"),
      "text/csv;charset=utf-8;",
    );
  const exportJson = () =>
    downloadFile(
      JSON.stringify(
        {
          schema: "stategraph.audit.v1",
          exported_at: new Date().toISOString(),
          scope: capped ? "most-recent-per-provider" : "all",
          per_provider_cap: AUDIT_CAP,
          row_count: filtered.length,
          rows: toRecords(filtered),
        },
        null,
        2,
      ),
      timestampedFilename(exportBase, "json"),
      "application/json;charset=utf-8;",
    );

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Audit"
        subtitle="Every run — who ran what, when, and how it ended"
      >
        <button onClick={() => void load()} disabled={refreshing} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
          <RefreshCw className={`w-3.5 h-3.5 text-[var(--sg-text-muted)] ${refreshing ? "animate-spin" : ""}`} />
        </button>
      </PageHeader>

      <div className="flex-1 overflow-y-auto px-4 sm:px-6 py-4">
        <AsyncSection
          loading={rows === null && !error}
          error={error}
          empty={rows?.length === 0}
          emptyState={
            <OrchestrationEmptyState centered>
              <div className="p-8 text-center text-sm text-[var(--sg-text-muted)]">No runs yet.</div>
            </OrchestrationEmptyState>
          }
          onRetry={() => void load()}
        >
          {failed.length > 0 && (
            <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
              Could not load {failed.join(", ")} runs — showing the rest.
            </div>
          )}
          <ListToolbar
            search={query}
            onSearch={setQuery}
            placeholder="Filter by repo, actor, branch, PR…"
            filters={[
              ...(owners.length > 1 || owner
                ? [{ label: "Owners", value: owner, onChange: setOwner, options: owners }]
                : []),
              ...(runTypes.length > 1 || runType
                ? [{ label: "Types", value: runType, onChange: setRunType, options: runTypes.map((t) => ({ label: t, value: t })) }]
                : []),
              ...(outcomes.length > 1 || status
                ? [{ label: "States", value: status, onChange: setStatus, options: outcomes.map((t) => ({ label: OUTCOME_LABEL[t as Outcome] ?? t, value: t })) }]
                : []),
            ]}
          >
            <button
              onClick={exportCsv}
              disabled={filtered.length === 0}
              className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-40 cursor-pointer"
            >
              <Download className="w-3 h-3" /> CSV
            </button>
            <button
              onClick={exportJson}
              disabled={filtered.length === 0}
              className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-40 cursor-pointer"
            >
              <Download className="w-3 h-3" /> JSON
            </button>
          </ListToolbar>
          <div className="mb-2 text-xs text-[var(--sg-text-muted)]">
            {filtered.length.toLocaleString()} of {(rows ?? []).length.toLocaleString()} runs
            {capped && <span className="text-[var(--sg-text-dim)]"> · showing most recent {AUDIT_CAP} per provider</span>}
          </div>
          {filtered.length === 0 ? (
            <div className="p-8 text-sm text-[var(--sg-text-muted)]">No runs match these filters.</div>
          ) : (
            <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>When</TableHead>
                    <TableHead>Repository</TableHead>
                    <TableHead className="hidden md:table-cell">Type</TableHead>
                    <TableHead className="hidden md:table-cell">Actor</TableHead>
                    <TableHead className="hidden xl:table-cell">Branch</TableHead>
                    <TableHead className="hidden md:table-cell">PR</TableHead>
                    <TableHead>State</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {page.pageItems.map((r) => {
                    const prUrl = pullRequestUrl(r.provider, r.repoOwner, r.repoName, r.pullNumber);
                    return (
                    <TableRow key={`${r.provider}-${r.id}`}>
                      <TableCell className="text-[var(--sg-text-muted)]" title={formatAbsoluteTime(r.createdAt)}>
                        {formatRelativeTime(r.createdAt)}
                      </TableCell>
                      <TableCell className="text-[var(--sg-text-muted)]">
                        <div className={`truncate ${IDENTITY_CELL_WIDTH}`} title={`${r.repoOwner}/${r.repoName}`}>
                          {r.repoOwner}/{r.repoName}
                        </div>
                      </TableCell>
                      <TableCell className="hidden md:table-cell text-[var(--sg-text-muted)]">
                        {r.runType}
                        {r.runKind ? <span className="text-[var(--sg-text-dim)]"> · {runKindLabel(r.runKind)}</span> : null}
                      </TableCell>
                      <TableCell className="hidden md:table-cell text-[var(--sg-text-muted)]">{r.username || "—"}</TableCell>
                      <TableCell className="hidden xl:table-cell font-mono text-xs text-[var(--sg-text-muted)]">{r.branch || "—"}</TableCell>
                      <TableCell className="hidden md:table-cell text-[var(--sg-text-muted)]">
                        {r.pullNumber ? (
                          prUrl ? (
                            <a
                              href={prUrl}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-[var(--sg-accent)] hover:underline"
                            >
                              {prSigil(r.provider)}{r.pullNumber}
                            </a>
                          ) : (
                            `${prSigil(r.provider)}${r.pullNumber}`
                          )
                        ) : (
                          "—"
                        )}
                      </TableCell>
                      <TableCell>
                        <OutcomeChip outcome={r.outcome} rawState={r.state} />
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

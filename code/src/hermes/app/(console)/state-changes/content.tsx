"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { RefreshCw } from "lucide-react";
import { useTenant } from "@/contexts/TenantContext";
import { PageHeader } from "@/components/page";
import {
  getTenantTransactionsPaginated,
  type Transaction,
} from "@/lib/api/client";
import { parseLinkHeader } from "@/lib/api/pagination";
import { useDeepLinkRouter } from "@/hooks";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import {
  formatAbsoluteTime,
  formatDuration,
  formatRelativeTime,
} from "@/lib/utils/time";
import { RunsDateRangeFilter, StateChip } from "@/components/plans";
import { InfoTip } from "@/components/ui/info-tip";
import {
  RANGE_PRESET_IDS,
  resolveRange,
  type RangePreset,
} from "@/lib/plan/date-range";
import { PaginationControls } from "@/components/instances/PaginationControls";
import { isAwaitingApply, isRunning } from "@/lib/plan/state";

const PAGE_SIZE = 10;
// Don't re-hit the API on every tab focus — if we refreshed in the last 5s,
// trust what's on screen.
const VISIBILITY_REFRESH_MIN_MS = 5000;
// How long to wait after the user stops typing in the custom date inputs
// before applying the range. Datetime-local commits a value per segment, so
// without debouncing a single date pick triggers several refetches.
const CUSTOM_RANGE_DEBOUNCE_MS = 400;

const STATUS_FILTERS = ["all", "running", "awaiting", "applied", "failed"] as const;
type StatusFilter = (typeof STATUS_FILTERS)[number];
const STATUS_LABEL: Record<StatusFilter, string> = {
  all: "All",
  running: "Running",
  awaiting: "Planned",
  applied: "Applied",
  failed: "Failed",
};

function isStatusFilter(v: string): v is StatusFilter {
  return (STATUS_FILTERS as readonly string[]).includes(v);
}

function isRangePreset(v: string): v is RangePreset {
  return (RANGE_PRESET_IDS as readonly string[]).includes(v);
}

function matchesStatus(tx: Transaction, status: StatusFilter): boolean {
  switch (status) {
    case "all":
      return true;
    case "running":
      return isRunning(tx);
    case "awaiting":
      return isAwaitingApply(tx);
    case "applied":
      return tx.state === "committed";
    case "failed":
      return tx.state === "failed";
  }
}

/**
 * State Changes screen: Stategraph engine transactions (the API-backed run
 * log), with server cursor pagination.
 */
export function StateChangesContent() {
  const { currentTenant } = useTenant();
  const router = useDeepLinkRouter();
  const [runs, setRuns] = useState<Transaction[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [lastLoaded, setLastLoaded] = useState<number | null>(null);
  // Pagination via the backend's cursor Link header. `currentCursor` is what
  // we sent to get the current page (undefined = first page). Prev/next
  // cursors come back from the server and feed the PaginationControls.
  const [currentCursor, setCurrentCursor] = useState<string[] | undefined>(undefined);
  const [nextCursor, setNextCursor] = useState<string[] | null>(null);
  const [prevCursor, setPrevCursor] = useState<string[] | null>(null);
  const [pageNumber, setPageNumber] = useState(1);
  const [paging, setPaging] = useState(false);
  // Filters live in the URL (?status=/?sname=/?range=/?from=/?to=) so a run
  // list is shareable; the raw params are validated on read.
  const [statusParam, setStatusFilter] = useUrlSyncedParam("status", "all");
  const statusFilter: StatusFilter = isStatusFilter(statusParam) ? statusParam : "all";
  const [stateNameFilter, setStateNameFilter] = useUrlSyncedParam("sname", "");
  const [rangeParam, setRangeParam] = useUrlSyncedParam("range", "");
  // Custom from/to are kept as datetime-local strings ("YYYY-MM-DDTHH:mm")
  // since that's what the input emits and what the URL stores. We convert to
  // ISO when we hand them off to the API.
  const [customFrom, setCustomFrom] = useUrlSyncedParam("from", "");
  const [customTo, setCustomTo] = useUrlSyncedParam("to", "");
  // Deep-link with from/to but no explicit range: surface as custom so the
  // inputs are visible and the filter actually applies.
  const rangePreset: RangePreset = isRangePreset(rangeParam)
    ? rangeParam
    : customFrom || customTo
      ? "custom"
      : "anytime";
  // Debounced shadows of the custom inputs. The visible inputs update on
  // every keystroke (responsive UI + URL sync), but the *applied* range only
  // catches up after the user pauses typing. Without this, each segment the
  // browser commits to a datetime-local input fires a full refetch.
  const [appliedCustomFrom, setAppliedCustomFrom] = useState(customFrom);
  const [appliedCustomTo, setAppliedCustomTo] = useState(customTo);
  useEffect(() => {
    const id = window.setTimeout(() => {
      setAppliedCustomFrom(customFrom);
      setAppliedCustomTo(customTo);
    }, CUSTOM_RANGE_DEBOUNCE_MS);
    return () => window.clearTimeout(id);
  }, [customFrom, customTo]);

  const setRangePreset = useCallback(
    (next: RangePreset) => {
      setRangeParam(next === "anytime" ? "" : next);
      // Switching away from custom drops the custom dates so a stale URL
      // ?from=&to= doesn't keep filtering after the user picked a preset.
      if (next !== "custom") {
        setCustomFrom("");
        setCustomTo("");
      }
    },
    [setRangeParam, setCustomFrom, setCustomTo],
  );

  // Resolved each fetch (not just when deps change) so "last 24h" tracks the
  // wall clock instead of freezing at preset-selection time.
  const fetchPage = useCallback(
    async (cursor: string[] | undefined) => {
      if (!currentTenant) return;
      try {
        const range = resolveRange(rangePreset, appliedCustomFrom, appliedCustomTo);
        const { data, linkHeader } = await getTenantTransactionsPaginated(
          currentTenant.id,
          {
            limit: PAGE_SIZE,
            ...(cursor ? { page: cursor } : {}),
            ...(range.fromIso ? { from: range.fromIso } : {}),
            ...(range.toIso ? { to: range.toIso } : {}),
          },
        );
        // Backend already orders by created_at desc — the same key the
        // pagination cursor uses. Don't re-sort client-side or the cursor
        // semantics would disagree with what's on screen.
        setRuns(data.results);
        const links = parseLinkHeader(linkHeader);
        setNextCursor(links.next ?? null);
        setPrevCursor(links.prev ?? null);
        setError(null);
        setLastLoaded(Date.now());
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to load runs");
      }
    },
    [currentTenant, rangePreset, appliedCustomFrom, appliedCustomTo],
  );

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await fetchPage(currentCursor);
    } finally {
      setRefreshing(false);
    }
  }, [fetchPage, currentCursor]);

  const goNext = useCallback(async () => {
    if (!nextCursor) return;
    setPaging(true);
    setCurrentCursor(nextCursor);
    setPageNumber((n) => n + 1);
    try {
      await fetchPage(nextCursor);
    } finally {
      setPaging(false);
    }
  }, [fetchPage, nextCursor]);

  const goPrev = useCallback(async () => {
    if (!prevCursor) return;
    setPaging(true);
    setCurrentCursor(prevCursor);
    setPageNumber((n) => Math.max(1, n - 1));
    try {
      await fetchPage(prevCursor);
    } finally {
      setPaging(false);
    }
  }, [fetchPage, prevCursor]);

  // Reset to the first page whenever the tenant or applied range changes.
  // fetchPage identity already encodes those deps, so we rely on it directly.
  useEffect(() => {
    if (!currentTenant) return;
    setCurrentCursor(undefined);
    setPageNumber(1);
    setRefreshing(true);
    fetchPage(undefined).finally(() => setRefreshing(false));
  }, [currentTenant, fetchPage]);

  // Re-fetch when the user returns to the tab. visibilitychange alone covers
  // both hide/show and focus transitions — adding a `focus` listener would
  // double-fire on every tab return.
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState !== "visible") return;
      if (refreshing) return;
      if (lastLoaded && Date.now() - lastLoaded < VISIBILITY_REFRESH_MIN_MS) return;
      void refresh();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [refresh, refreshing, lastLoaded]);

  // Unique state names across loaded rows, sorted for stable select order.
  const stateNameOptions = useMemo(() => {
    if (!runs) return [];
    const set = new Set<string>();
    for (const tx of runs) for (const n of (tx.state_names ?? [])) set.add(n);
    return [...set].sort();
  }, [runs]);

  const filteredRuns = useMemo(() => {
    if (!runs) return null;
    return runs.filter((tx) => {
      if (!matchesStatus(tx, statusFilter)) return false;
      if (stateNameFilter && !(tx.state_names ?? []).includes(stateNameFilter)) return false;
      return true;
    });
  }, [runs, statusFilter, stateNameFilter]);

  if (error) {
    return <div className="p-8 text-[var(--sg-error)]">{error}</div>;
  }
  if (runs === null || filteredRuns === null) {
    return <div className="p-8 text-[var(--sg-text-muted)]">Loading runs…</div>;
  }

  // Counters are global health signals, not filter mirrors. Running = truly
  // executing; awaiting = sitting waiting for a user to kick apply.
  const runningCount = runs.filter(isRunning).length;
  const awaitingCount = runs.filter(isAwaitingApply).length;
  const filtersActive =
    statusFilter !== "all" ||
    stateNameFilter !== "" ||
    rangePreset !== "anytime";

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="State Changes"
        subtitle="Stategraph engine transactions: every plan and apply committed to state, newest first"
      >
        <button onClick={() => void refresh()} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
          <RefreshCw className={`w-3.5 h-3.5 text-[var(--sg-text-muted)] ${refreshing ? "animate-spin" : ""}`} />
        </button>
      </PageHeader>
      <div className="px-6 pt-4 pb-3 border-b border-[var(--sg-border)]">
        <div className="flex flex-wrap items-center gap-3 mt-3">
          <div
            role="tablist"
            aria-label="Filter by status"
            className="inline-flex rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-xs overflow-hidden"
          >
            {STATUS_FILTERS.map((st) => {
              const selected = statusFilter === st;
              return (
                <button
                  key={st}
                  role="tab"
                  aria-selected={selected}
                  onClick={() => setStatusFilter(st)}
                  className={`px-3 py-1 cursor-pointer border-l border-[var(--sg-border)] first:border-l-0 ${
                    selected
                      ? "bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]"
                      : "text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)]"
                  }`}
                >
                  {STATUS_LABEL[st]}
                </button>
              );
            })}
          </div>
          {stateNameOptions.length > 0 && (
            <label className="text-xs text-[var(--sg-text-muted)] flex items-center gap-2">
              <span className="sr-only">Filter by state</span>
              <select
                value={stateNameFilter}
                onChange={(e) => setStateNameFilter(e.target.value)}
                className="px-2 py-1 text-xs bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-[var(--sg-text)] cursor-pointer"
              >
                <option value="">All states</option>
                {stateNameOptions.map((n) => (
                  <option key={n} value={n}>
                    {n}
                  </option>
                ))}
              </select>
            </label>
          )}
          <RunsDateRangeFilter
            preset={rangePreset}
            customFrom={customFrom}
            customTo={customTo}
            onPresetChange={setRangePreset}
            onCustomFromChange={setCustomFrom}
            onCustomToChange={setCustomTo}
          />
        </div>
        <div className="text-xs text-[var(--sg-text-muted)] mt-2">
          <strong className="text-[var(--sg-text)]">{filteredRuns.length}</strong>{" "}
          {filteredRuns.length === 1 ? "change" : "changes"} on this page
          {filtersActive && runs.length !== filteredRuns.length && (
            <> (of {runs.length} loaded)</>
          )}
          {runningCount > 0 && (
            <>
              {" · "}
              <strong className="text-[var(--sg-warning)]">{runningCount}</strong>{" "}
              running right now
            </>
          )}
          {awaitingCount > 0 && (
            <>
              {" · "}
              <strong className="text-[var(--sg-accent)]">{awaitingCount}</strong>{" "}
              planned
            </>
          )}
        </div>
      </div>

      {filteredRuns.length === 0 && !filtersActive ? (
        <div className="p-8 text-sm text-[var(--sg-text-muted)]">
          No state changes yet. Run{" "}
          <code className="font-mono">stategraph tf plan</code> to create one.
        </div>
      ) : filteredRuns.length === 0 ? (
        <div className="p-8 text-sm text-[var(--sg-text-muted)]">
          No state changes match the current filters.
        </div>
      ) : (
        <div className="flex-1 overflow-auto">
          <table className="w-full text-sm">
            <thead className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)] bg-[var(--sg-bg-2)] border-b border-[var(--sg-border)]">
              <tr>
                <th className="text-left px-6 py-2 font-medium">State</th>
                <th className="text-left px-6 py-2 font-medium">Changes</th>
                <th className="text-left px-6 py-2 font-medium">
                  <span className="inline-flex items-center gap-1">
                    By
                    <InfoTip label="About the “By” column">
                      Runs executed by CI are authored by the Stategraph service
                      account — the API user whose token CI uses to run{" "}
                      <code className="font-mono">stategraph tf plan</code> /{" "}
                      <code className="font-mono">apply</code>. An actor like
                      “service_account” is expected here. A change authored
                      directly by a person shows that person&apos;s own name.
                    </InfoTip>
                  </span>
                </th>
                <th className="text-left px-6 py-2 font-medium">States</th>
                <th className="text-left px-6 py-2 font-medium">Created</th>
                <th className="text-left px-6 py-2 font-medium">Applied · Duration</th>
              </tr>
            </thead>
            <tbody>
              {filteredRuns.map((tx) => {
                // Instance-level counts from terraform's "Plan:" line, parsed
                // server-side and served on the tx. Absent when a run has no
                // captured plan output (e.g. a state-write tx).
                const counts = tx.plan_summary;
                const states =
                  (tx.state_names ?? []).length === 0 ? "—" : (tx.state_names ?? []).join(", ");
                const creator = tx.created_by_name ?? tx.created_by;
                const duration = tx.completed_at
                  ? formatDuration(tx.created_at, tx.completed_at)
                  : isRunning(tx) || isAwaitingApply(tx)
                    ? formatDuration(tx.created_at)
                    : null;
                return (
                  <tr
                    key={tx.id}
                    {...router.nav(`/runs/detail?tx=${tx.id}`)}
                    className="border-b border-[var(--sg-border-light)] cursor-pointer hover:bg-[var(--sg-bg-2)]"
                  >
                    <td className="px-6 py-2">
                      <StateChip state={tx.state} />
                    </td>
                    <td className="px-6 py-2 font-mono text-xs">
                      {counts ? (
                        <>
                          <span
                            className="text-[var(--sg-op-create)]"
                            title={`${counts.add} to add`}
                          >
                            +{counts.add}
                          </span>{" "}
                          <span
                            className="text-[var(--sg-op-update)]"
                            title={`${counts.change} to change`}
                          >
                            ~{counts.change}
                          </span>{" "}
                          <span
                            className="text-[var(--sg-op-destroy)]"
                            title={`${counts.destroy} to destroy`}
                          >
                            -{counts.destroy}
                          </span>
                        </>
                      ) : (
                        <span
                          className="text-[var(--sg-text-dim)]"
                          title="No plan output"
                        >
                          —
                        </span>
                      )}
                    </td>
                    <td
                      className="px-6 py-2 text-[var(--sg-text)]"
                      title={tx.created_by}
                    >
                      {creator}
                    </td>
                    <td className="px-6 py-2 text-[var(--sg-text)]">{states}</td>
                    <td
                      className="px-6 py-2 text-[var(--sg-text-muted)]"
                      title={formatAbsoluteTime(tx.created_at)}
                    >
                      {formatRelativeTime(tx.created_at)}
                    </td>
                    <td
                      className="px-6 py-2 text-[var(--sg-text-muted)]"
                      title={
                        tx.completed_at ? formatAbsoluteTime(tx.completed_at) : ""
                      }
                    >
                      <div>
                        {tx.completed_at
                          ? formatRelativeTime(tx.completed_at)
                          : isRunning(tx)
                            ? "running"
                            : isAwaitingApply(tx)
                              ? "planned"
                              : "—"}
                      </div>
                      {duration && (
                        <div className="text-[var(--sg-text-dim)] text-xs">
                          {duration}
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {(nextCursor || prevCursor || pageNumber > 1) && (
            <PaginationControls
              currentPage={pageNumber}
              hasNext={!!nextCursor}
              hasPrevious={!!prevCursor}
              onNext={() => void goNext()}
              onPrevious={() => void goPrev()}
              pageSize={PAGE_SIZE}
              isLoading={paging}
            />
          )}
        </div>
      )}
    </div>
  );
}

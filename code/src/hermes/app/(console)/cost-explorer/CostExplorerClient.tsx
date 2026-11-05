"use client";

import { DeepLink } from "@/components/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Download } from "lucide-react";

import {
  CostBasisSelector,
  CostDisabledNotice,
  CostRangeSelector,
  DeltaBadge,
  PillGroup,
  TenantActualsSections,
  TenantCostHistoryChart,
} from "@/components/cost";
import { Button } from "@/components/ui/button";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { useTenant } from "@/contexts";
import { useCostAvailability, useCostBasis, useTenantCostRange } from "@/hooks";
import { useTenantCostHistory } from "@/hooks/useTenantCostHistory";
import { useTenantCosts } from "@/hooks/useTenantCosts";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { getTenantCostTagKeys, type CostBreakdownEntry } from "@/lib/api/client";
import { formatCurrency, parseCost, tenantCurrencyFor } from "@/lib/cost/format";
import {
  deltaAbsolute,
  groupDeltasOverRange,
  type CostDelta,
} from "@/lib/cost/delta";
import { downloadCsv } from "@/lib/cost/export";

// The dimension to pivot on. provider/type/tag map to the history group_by;
// state has no history grouping (the API groups by provider/type/tag only), so
// it shows the table + links to each state's Cost Analysis instead of a trend.
type ExplorerDim = "provider" | "type" | "tag" | "state";
type SortBy = "monthly" | "delta" | "resources" | "name";

const DIMS: { id: ExplorerDim; label: string }[] = [
  { id: "provider", label: "Provider" },
  { id: "type", label: "Resource type" },
  { id: "tag", label: "Tag" },
  { id: "state", label: "State" },
];

function isExplorerDim(v: string | null): v is ExplorerDim {
  return v === "provider" || v === "type" || v === "tag" || v === "state";
}

interface PivotRow {
  name: string;
  monthly: number | null;
  resourceCount: number;
  delta: CostDelta | null;
  stateId?: string;
}

function ShareBar({ fraction }: { fraction: number }) {
  const pct = Math.max(0, Math.min(100, fraction * 100));
  return (
    <div className="flex items-center gap-2">
      <div className="w-24 h-1.5 bg-[var(--sg-bg-2)] rounded overflow-hidden">
        <div className="h-full bg-[var(--sg-accent)]" style={{ width: `${pct}%` }} />
      </div>
      <span className="text-xs text-[var(--sg-text-muted)] font-mono w-10 text-right">
        {pct.toFixed(0)}%
      </span>
    </div>
  );
}

export function CostExplorerClient() {
  const { currentTenant, isLoading: tenantLoading } = useTenant();
  const { capability: costCapability, isLoading: costLoading } = useCostAvailability();
  const [basis, setBasis] = useCostBasis();
  const [range, setRange] = useTenantCostRange();

  const [dimRaw, setDimRaw] = useUrlSyncedParam("dim", "provider");
  const dim: ExplorerDim = isExplorerDim(dimRaw) ? dimRaw : "provider";
  const [tagKey, setTagKey] = useUrlSyncedParam("tag_key", "");
  // Switching the dimension away from "tag" must also clear ?tag_key from the URL --
  // otherwise the URL keeps a phantom tag_key that the page no longer reads, and
  // pasting the URL into another tab shows a misleading param next to the active dim.
  const setDim = useCallback(
    (next: ExplorerDim) => {
      setDimRaw(next);
      if (next !== "tag") setTagKey("");
    },
    [setDimRaw, setTagKey]
  );
  const [minStr, setMinStr] = useUrlSyncedParam("min", "");
  const [sortBy, setSortBy] = useState<SortBy>("monthly");

  // When cost is disabled on the server, show the shared "enable cost" notice
  // (see below) -- the same one Analysis and Overview show.
  const costSupported = !costLoading && costCapability?.enabled === true;

  const needsTagKey = dim === "tag" && !tagKey;
  const rollupTagKey = dim === "tag" && tagKey ? tagKey : undefined;
  // Explorer only uses history when the dimension is one of the three the
  // backend supports as a `group_by`. For `state` (per-state pivot) and for
  // tag-without-tag-key, history is left as `null` and the chart surface is
  // gated upstream.
  const historyGroupBy =
    dim === "state" || needsTagKey
      ? undefined
      : (dim as "provider" | "type" | "tag");
  const historyTagKey =
    historyGroupBy === "tag" && tagKey ? tagKey : undefined;

  // On the pure-actual basis nothing estimated is rendered; skip the fetches.
  const skipEstimates = basis === "actual";
  const {
    rollup,
    isLoading: rollupLoading,
    error: rollupError,
  } = useTenantCosts({ tagKey: rollupTagKey, skip: skipEstimates });
  const { history, isLoading: historyLoading } = useTenantCostHistory({
    range,
    groupBy: historyGroupBy,
    tagKey: historyTagKey,
    skip: skipEstimates,
  });
  // The Δ column has three states: a delta to render, "loading" (we're
  // waiting on history, so a real delta might be coming), or "no comparable
  // data" (the row genuinely doesn't have a previous-window value). Without
  // the loading branch the column reads as "no data" the entire time the
  // request is in flight.
  const showDeltaLoading = historyLoading && historyGroupBy !== undefined;

  const [tagKeys, setTagKeys] = useState<string[]>([]);

  useEffect(() => {
    const tenant = currentTenant;
    if (!tenant || dim !== "tag") return;
    let cancelled = false;
    async function loadTagKeys(tenantId: string) {
      try {
        const res = await getTenantCostTagKeys(tenantId);
        if (!cancelled) setTagKeys(res.tag_keys);
      } catch {
        if (!cancelled) setTagKeys([]);
      }
    }
    loadTagKeys(tenant.id);
    return () => {
      cancelled = true;
    };
  }, [currentTenant, dim]);

  const { currency } = tenantCurrencyFor(rollup);

  const rows = useMemo<PivotRow[]>(() => {
    if (!rollup) return [];
    if (dim === "state") {
      return rollup.states.map((s) => ({
        name: s.state_name,
        monthly: parseCost(s.monthly_cost),
        resourceCount: s.resource_count ?? 0,
        delta: null,
        stateId: s.state_id,
      }));
    }
    const entries: CostBreakdownEntry[] =
      dim === "provider" ? rollup.by_provider : dim === "type" ? rollup.by_type : rollup.by_tag;
    const deltas = groupDeltasOverRange(history?.points ?? []);
    return entries.map((e) => ({
      name: e.name,
      monthly: parseCost(e.monthly_cost),
      resourceCount: e.resource_count,
      delta: deltas.get(e.name) ?? null,
    }));
  }, [rollup, dim, history]);

  const total = useMemo(() => rows.reduce((sum, r) => sum + (r.monthly ?? 0), 0), [rows]);
  const minCost = Number(minStr) || 0;

  const visibleRows = useMemo(() => {
    const filtered = rows.filter((r) => (r.monthly ?? 0) >= minCost);
    const sorted = [...filtered].sort((a, b) => {
      switch (sortBy) {
        case "name":
          return a.name.localeCompare(b.name);
        case "resources":
          return b.resourceCount - a.resourceCount;
        case "delta": {
          const da = a.delta ? deltaAbsolute(a.delta) ?? 0 : 0;
          const db = b.delta ? deltaAbsolute(b.delta) ?? 0 : 0;
          return db - da;
        }
        case "monthly":
        default:
          return (b.monthly ?? 0) - (a.monthly ?? 0);
      }
    });
    return sorted;
  }, [rows, minCost, sortBy]);

  const topDrivers = useMemo(
    () =>
      [...rows]
        .filter((r) => r.monthly !== null)
        .sort((a, b) => (b.monthly ?? 0) - (a.monthly ?? 0))
        .slice(0, 3),
    [rows]
  );

  const handleExport = useCallback(() => {
    const headers = ["name", "monthly_cost", "share_percent", "delta_monthly", "resource_count"];
    const csvRows = visibleRows.map((r) => [
      r.name,
      r.monthly ?? "",
      total > 0 && r.monthly !== null ? ((r.monthly / total) * 100).toFixed(2) : "",
      r.delta ? deltaAbsolute(r.delta)?.toFixed(2) ?? "" : "",
      r.resourceCount,
    ]);
    downloadCsv(`cost-explorer-${dim}-${currentTenant?.id ?? "tenant"}.csv`, headers, csvRows);
  }, [visibleRows, total, dim, currentTenant]);

  if (tenantLoading || costLoading) {
    return (
      <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
        Loading…
      </div>
    );
  }
  if (!costSupported) {
    return <CostDisabledNotice />;
  }
  if (!currentTenant) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[40vh] gap-2 text-center px-4">
        <div className="text-[var(--sg-text)] font-medium">No tenant available</div>
        <div className="text-sm text-[var(--sg-text-muted)] max-w-md">
          Cost Explorer needs a tenant to aggregate over.
        </div>
      </div>
    );
  }

  // Shared cell renderers so the desktop table and the mobile card list stay in
  // sync (same deep link + delta states).
  const renderName = (r: PivotRow) =>
    r.stateId ? (
      <DeepLink
        href={`/cost-analysis?state=${encodeURIComponent(r.stateId)}`}
        className="text-[var(--sg-accent)] hover:underline"
      >
        {r.name}
      </DeepLink>
    ) : (
      r.name
    );

  const renderDelta = (r: PivotRow) =>
    r.delta ? (
      <DeltaBadge
        current={r.delta.current}
        previous={r.delta.previous}
        currency={currency}
      />
    ) : showDeltaLoading ? (
      <span
        className="text-xs text-[var(--sg-text-dim)] animate-pulse"
        aria-busy="true"
        aria-label="Loading delta"
      >
        …
      </span>
    ) : (
      <span className="text-xs text-[var(--sg-text-dim)]">—</span>
    );

  return (
    <div className="flex flex-col">
      <PageHeader title="Explorer" subtitle="Slice tenant cost by any dimension">
        {basis !== "actual" && (
          <Button
            variant="outline"
            size="sm"
            onClick={handleExport}
            disabled={visibleRows.length === 0}
          >
            <Download className="w-4 h-4 mr-2" />
            Export CSV
          </Button>
        )}
      </PageHeader>

      <PageSection className="mx-4 sm:mx-6">
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
            <CostBasisSelector value={basis} onChange={setBasis} />
            {basis !== "actual" && (
            <>
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                Dimension
              </span>
              <PillGroup options={DIMS} value={dim} onChange={setDim} />
              {dim === "tag" && (
                <select
                  value={tagKey}
                  onChange={(e) => setTagKey(e.target.value)}
                  aria-label="Tag key"
                  className="h-8 px-2 text-sm rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] text-[var(--sg-text)]"
                >
                  <option value="">Select tag key</option>
                  {tagKeys.map((k) => (
                    <option key={k} value={k}>
                      {k}
                    </option>
                  ))}
                </select>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                Period
              </span>
              <CostRangeSelector value={range} onChange={setRange} />
            </div>
            <label className="flex items-center gap-1 text-xs text-[var(--sg-text-muted)]">
              Min $/mo
              <input
                type="number"
                min={0}
                value={minStr}
                onChange={(e) => setMinStr(e.target.value)}
                placeholder="0"
                className="h-8 w-24 px-2 text-sm rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] text-[var(--sg-text)]"
              />
            </label>
            <label className="flex items-center gap-1 text-xs text-[var(--sg-text-muted)]">
              Sort
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortBy)}
                className="h-8 px-2 text-sm rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] text-[var(--sg-text)]"
              >
                <option value="monthly">Monthly ↓</option>
                <option value="delta">Δ over range ↓</option>
                <option value="resources">Resources ↓</option>
                <option value="name">Name</option>
              </select>
            </label>
            </>
            )}
          </div>

          {basis !== "estimated" && (
            <TenantActualsSections
              compare={basis === "both"}
              estimatedMonthly={parseCost(rollup?.monthly_cost)}
              estimatedByProvider={rollup?.by_provider ?? null}
              estimatedCurrency={currency}
              showUnmanagedPanel
            />
          )}

          {basis !== "actual" && (
          <>
          {rollupError && <div className="text-sm text-[var(--sg-error)]">{rollupError}</div>}

          {topDrivers.length > 0 && (
            <div className="flex flex-wrap items-center gap-2 text-sm">
              <span
                className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide"
                title="The three highest-cost rows across the whole rollup. Not affected by the Min $/mo filter or the Sort dropdown -- those reshape the table below."
              >
                Top drivers
              </span>
              {topDrivers.map((r) => (
                <span
                  key={r.name}
                  className="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)]"
                >
                  <span className="text-[var(--sg-text)] truncate max-w-[160px]" title={r.name}>
                    {r.name}
                  </span>
                  <span className="font-mono text-[var(--sg-text-muted)]">
                    {r.monthly !== null ? formatCurrency(r.monthly, currency) : "—"}
                  </span>
                </span>
              ))}
            </div>
          )}

          {dim !== "state" && (
            <PageSurface>
              {needsTagKey ? (
                <div className="flex flex-col items-center justify-center h-[280px] gap-2 text-center px-4">
                  <div className="text-[var(--sg-text)] font-medium">Pick a tag key</div>
                  <div className="text-sm text-[var(--sg-text-muted)]">
                    Choose a tag key to break cost down by that tag value.
                  </div>
                </div>
              ) : history && history.points.length > 0 ? (
                <TenantCostHistoryChart points={history.points} grouped currency={currency} />
              ) : (
                <div className="flex items-center justify-center h-[280px] text-[var(--sg-text-muted)]">
                  No history in this window.
                </div>
              )}
            </PageSurface>
          )}

          {needsTagKey ? null : (
            <>
              {/* Desktop / tablet table (lg+) */}
              <div className="hidden lg:block bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
                      <th className="text-left px-3 py-2 font-medium">{DIMS.find((d) => d.id === dim)?.label}</th>
                      <th className="text-right px-3 py-2 font-medium">Monthly</th>
                      <th className="text-left px-3 py-2 font-medium">Share</th>
                      <th className="text-right px-3 py-2 font-medium">Δ range</th>
                      <th className="text-right px-3 py-2 font-medium">Resources</th>
                    </tr>
                  </thead>
                  <tbody>
                    {visibleRows.length === 0 && (
                      <tr>
                        <td colSpan={5} className="px-3 py-6 text-center text-[var(--sg-text-muted)]">
                          {rollupLoading ? "Loading…" : "No rows match."}
                        </td>
                      </tr>
                    )}
                    {visibleRows.map((r) => (
                      <tr
                        key={r.stateId ?? r.name}
                        className="border-b last:border-b-0 border-[var(--sg-border-light)]"
                      >
                        <td className="px-3 py-2 text-[var(--sg-text)] truncate max-w-[280px]" title={r.name}>
                          {renderName(r)}
                        </td>
                        <td className="px-3 py-2 text-right font-mono">
                          {r.monthly !== null ? formatCurrency(r.monthly, currency) : "—"}
                        </td>
                        <td className="px-3 py-2">
                          <ShareBar fraction={total > 0 && r.monthly !== null ? r.monthly / total : 0} />
                        </td>
                        <td className="px-3 py-2 text-right">{renderDelta(r)}</td>
                        <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                          {r.resourceCount}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Mobile card list (below lg) */}
              <div className="lg:hidden space-y-3">
                {visibleRows.length === 0 ? (
                  <div className="rounded-lg border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] p-6 text-center text-[var(--sg-text-muted)]">
                    {rollupLoading ? "Loading…" : "No rows match."}
                  </div>
                ) : (
                  visibleRows.map((r) => (
                    <div
                      key={r.stateId ?? r.name}
                      className="rounded-lg border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] p-3"
                    >
                      <div
                        className="font-medium text-[var(--sg-text)] break-all min-w-0"
                        title={r.name}
                      >
                        {renderName(r)}
                      </div>
                      <div className="mt-2 space-y-1.5 text-sm">
                        <div className="flex items-center justify-between gap-3">
                          <span className="text-[var(--sg-text-muted)]">Monthly</span>
                          <span className="font-mono text-[var(--sg-text)]">
                            {r.monthly !== null ? formatCurrency(r.monthly, currency) : "—"}
                          </span>
                        </div>
                        <div className="flex items-center justify-between gap-3">
                          <span className="text-[var(--sg-text-muted)]">Share</span>
                          <ShareBar
                            fraction={total > 0 && r.monthly !== null ? r.monthly / total : 0}
                          />
                        </div>
                        <div className="flex items-center justify-between gap-3">
                          <span className="text-[var(--sg-text-muted)]">Δ range</span>
                          <span>{renderDelta(r)}</span>
                        </div>
                        <div className="flex items-center justify-between gap-3">
                          <span className="text-[var(--sg-text-muted)]">Resources</span>
                          <span className="font-mono text-[var(--sg-text-muted)]">
                            {r.resourceCount}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </>
          )}

          {dim === "state" && (
            <div className="text-xs text-[var(--sg-text-dim)]">
              Cost over time isn&apos;t grouped by state — open a state&apos;s Cost Analysis for its
              history.
            </div>
          )}
          </>
          )}
        </div>
      </PageSection>
    </div>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import { useStates } from "@/contexts";
import { useCostAvailability, useCostBasis, useCostRange, useStateSelection } from "@/hooks";
import { useAutoSelectOnce } from "@/hooks/useAutoSelectOnce";
import {
  fetchStateCostHistory,
  type StateCostHistoryPoint,
} from "@/lib/cost/history";
import {
  fetchLatestCostPerState,
  type LatestStateCost,
} from "@/lib/cost/states";
import {
  getStateCostActuals,
  type StateCostActualResource,
  type StateCostActuals,
  type StateCosts,
  type StateCostUnsupported,
} from "@/lib/api/client";
import { fetchStateCost, deriveUnsupported } from "@/lib/cost/stateCost";
import { COST_RANGES, rangeToFromTo } from "@/lib/cost/range";
import { formatCurrency, parseCost } from "@/lib/cost/format";
import { formatWindow, monthlyRunRate, MIN_COMPARE_WINDOW_DAYS } from "@/lib/cost/actuals";
import { deltaOverRange } from "@/lib/cost/delta";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { DeepLink } from "@/components/navigation";
import { StateFilter } from "@/components/filters";
import {
  ActualResourceTable,
  CostBasisSelector,
  CostDisabledNotice,
  CostHistoryChart,
  CostRangeSelector,
  CoverageGapsPanel,
  DeltaBadge,
  KpiCard,
  ProvenanceBadge,
  RecalculateButton,
  ResourceCostTable,
} from "@/components/cost";

function formatRelative(iso: string): string {
  const then = new Date(iso).getTime();
  if (!Number.isFinite(then)) return iso;
  const seconds = Math.max(0, Math.round((Date.now() - then) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days < 30) return `${days}d ago`;
  const months = Math.round(days / 30);
  if (months < 12) return `${months}mo ago`;
  return `${Math.round(months / 12)}y ago`;
}

export function CostAnalysisClient() {
  const { states, isLoading: statesLoading } = useStates();
  const { capability: costCapability, isLoading: costLoading } = useCostAvailability();

  // Bumped by the Recalculate button to refetch latest cost + history + the
  // per-resource breakdown after a fresh snapshot lands.
  const [refreshKey, setRefreshKey] = useState(0);
  const refresh = useCallback(() => setRefreshKey((k) => k + 1), []);

  // Per-state latest cost summary, fetched once via MQL. On error we fall
  // back to an empty map (the "no cost data" empty-state surfaces of its own
  // accord) rather than blocking the page.
  const [latestCosts, setLatestCosts] = useState<Map<string, LatestStateCost> | null>(null);
  useEffect(() => {
    let cancelled = false;
    fetchLatestCostPerState()
      .then((map) => {
        if (!cancelled) setLatestCosts(map);
      })
      .catch(() => {
        if (!cancelled) setLatestCosts(new Map());
      });
    return () => {
      cancelled = true;
    };
  }, [refreshKey]);

  const latestCostsLoading = latestCosts === null;
  const hasCostData = useMemo(
    () => (id: string) => latestCosts?.has(id) ?? false,
    [latestCosts]
  );

  const statesWithCosts = useMemo(
    () => states.filter((s) => hasCostData(s.id)),
    [states, hasCostData]
  );
  const disabledStateIds = useMemo(
    () => states.filter((s) => !hasCostData(s.id)).map((s) => s.id),
    [states, hasCostData]
  );

  const [selectedStateId, setSelectedStateId] = useStateSelection({ allowAll: false });
  const selectedState = useMemo(
    () => (selectedStateId ? states.find((s) => s.id === selectedStateId) ?? null : null),
    [selectedStateId, states]
  );
  // Auto-pick the period from the selected state's data span -- by the backend's
  // carry-forward rule the series begins at the state's created_at -- unless the
  // URL already pins ?range=.
  const [range, setRange] = useCostRange(selectedState?.created_at ?? null);
  const [basis, setBasis] = useCostBasis();

  // First-mount default selection. Order of precedence:
  //   1. A `?state=` URL pin from another page (the "current state" concept) —
  //      respected even when that state has no cost data, so the inline
  //      empty-state can guide the user.
  //   2. The state with the most-recent snapshot — honours the
  //      "default to most-recent snapshot" requirement.
  // Only runs once per mount to avoid stomping on the user's later picks. Has
  // to wait for both states AND the MQL-driven latest-cost map to land.
  useAutoSelectOnce(
    () => {
      if (statesLoading) return false;
      if (latestCostsLoading) return false;
      if (statesWithCosts.length === 0) return false;
      const urlPinned =
        typeof window !== "undefined"
          ? new URLSearchParams(window.location.search).get("state")
          : null;
      if (urlPinned && states.some((s) => s.id === urlPinned)) return true;
      const mostRecent = [...statesWithCosts].sort((a, b) => {
        const aAt = latestCosts?.get(a.id)?.calculated_at ?? "";
        const bAt = latestCosts?.get(b.id)?.calculated_at ?? "";
        return bAt.localeCompare(aAt);
      })[0];
      if (mostRecent && mostRecent.id !== selectedStateId) {
        setSelectedStateId(mostRecent.id);
      }
      return true;
    },
    [
      statesLoading,
      latestCostsLoading,
      statesWithCosts,
      states,
      latestCosts,
      selectedStateId,
      setSelectedStateId,
    ]
  );

  const selectedLatestCost = useMemo(
    () => (selectedStateId ? latestCosts?.get(selectedStateId) ?? null : null),
    [selectedStateId, latestCosts]
  );
  const selectedHasData = selectedState ? hasCostData(selectedState.id) : false;

  const [points, setPoints] = useState<StateCostHistoryPoint[] | null>(null);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState<string | null>(null);

  useEffect(() => {
    const stateId = selectedStateId;
    // The chart is hidden on the pure-actual basis; don't fetch what can't render.
    if (!stateId || basis === "actual") return;
    let cancelled = false;
    const { from, to } = rangeToFromTo(range, new Date());
    async function loadHistory(id: string) {
      setHistoryLoading(true);
      setHistoryError(null);
      try {
        const result = await fetchStateCostHistory(id, { from, to });
        if (!cancelled) setPoints(result);
      } catch (err: unknown) {
        if (cancelled) return;
        setHistoryError(err instanceof Error ? err.message : "Failed to load cost history");
        setPoints(null);
      } finally {
        if (!cancelled) setHistoryLoading(false);
      }
    }
    loadHistory(stateId);
    return () => {
      cancelled = true;
    };
  }, [selectedStateId, range, refreshKey, basis]);

  // The full latest snapshot: per-resource instance_costs (ResourceCostTable),
  // coverage gaps (CoverageGapsPanel), and provenance/coverage counters for the
  // KPIs. Only fetched for a priced state; tolerant of a 404 / partial failure.
  const [stateCosts, setStateCosts] = useState<StateCosts | null>(null);
  const [unsupported, setUnsupported] = useState<StateCostUnsupported | null>(null);
  const [breakdownLoading, setBreakdownLoading] = useState(false);

  useEffect(() => {
    const stateId = selectedStateId;
    // The breakdown + coverage gaps are hidden on the pure-actual basis.
    if (!stateId || !selectedHasData || basis === "actual") return;
    let cancelled = false;
    async function loadBreakdown(id: string) {
      setBreakdownLoading(true);
      try {
        // One MQL read for the latest snapshot + breakdown; the unsupported
        // coverage-gap list is derived from it (no separate read).
        const costs = await fetchStateCost(id).catch(() => null);
        if (cancelled) return;
        setStateCosts(costs);
        setUnsupported(costs ? deriveUnsupported(costs) : null);
      } finally {
        if (!cancelled) setBreakdownLoading(false);
      }
    }
    loadBreakdown(stateId);
    return () => {
      cancelled = true;
    };
  }, [selectedStateId, selectedHasData, refreshKey, basis]);

  // Actual (FOCUS) spend attributed to the selected state. Deliberately not
  // gated on selectedHasData: attribution is independent of the pricing
  // pipeline, so a never-priced state can still have billed actuals.
  const [actuals, setActuals] = useState<StateCostActuals | null>(null);
  const [actualsLoading, setActualsLoading] = useState(false);

  // Depend on the boolean, not the basis: "actual" and "both" want the same
  // response, so toggling between them must not refetch.
  const wantActuals = basis !== "estimated";
  useEffect(() => {
    const stateId = selectedStateId;
    if (!stateId || !wantActuals) return;
    let cancelled = false;
    setActualsLoading(true);
    getStateCostActuals(stateId)
      .then((res) => {
        if (!cancelled) setActuals(res);
      })
      .catch(() => {
        if (!cancelled) setActuals(null);
      })
      .finally(() => {
        if (!cancelled) setActualsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [selectedStateId, wantActuals, refreshKey]);

  const actualsByAddress = useMemo(() => {
    if (!actuals || actuals.resources.length === 0) return undefined;
    return new Map<string, StateCostActualResource>(
      actuals.resources.map((r) => [r.address, r])
    );
  }, [actuals]);

  // When cost is disabled on the server (capabilities.costs.enabled is false),
  // show the shared "enable cost" notice -- the same one Overview and Explorer
  // show, so every cost page stays consistent. A supported-but-empty tenant
  // still renders the normal UI: the StateFilter greys out states without data
  // and the chart surface shows the inline "No cost data yet" empty state.
  const costSupported = !costLoading && costCapability?.enabled === true;
  if (!costLoading && !costSupported) {
    return <CostDisabledNotice />;
  }

  if (statesLoading || costLoading || latestCostsLoading) {
    return (
      <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
        Loading…
      </div>
    );
  }

  // monthly_cost is a decimal string (precision-preserving wire format);
  // coerce for display only.
  const latestMonthly = parseCost(selectedLatestCost?.monthly_cost ?? null);
  const latestCurrency = selectedLatestCost?.currency ?? "USD";
  const latestCalculatedAt = selectedLatestCost?.calculated_at;
  const latestCoverage = selectedLatestCost?.coverage_percent;
  const footerCurrency = stateCosts?.currency || latestCurrency;
  const historyDelta = deltaOverRange(points ?? []);
  const provenance =
    stateCosts?.triggered_by ??
    (points && points.length > 0 ? points[points.length - 1].triggered_by : null);
  const unpricedCount = stateCosts
    ? Math.max(0, stateCosts.resource_count - stateCosts.priced_count)
    : null;
  // currency absent means mixed (bare numbers) or nothing attributed at all.
  const actualsCurrency = actuals?.currency ?? "";
  const actualBilled = parseCost(actuals?.billed_cost ?? null);
  const actualsWindow = actuals ? formatWindow(actuals.window_start, actuals.window_end) : null;
  const stateRunRate = actuals
    ? monthlyRunRate(actuals.billed_cost, actuals.window_start, actuals.window_end)
    : null;

  return (
    <div className="flex flex-col">
      <PageHeader
        title="Analysis"
        subtitle={
          basis === "actual"
            ? "Actual billed spend per state, from FOCUS exports"
            : basis === "both"
              ? "Estimated vs actual cloud spend per state"
              : "Estimated cloud spend per state, over time"
        }
      >
        <div className="flex flex-wrap items-center gap-2">
          <StateFilter
            value={selectedStateId}
            onChange={setSelectedStateId}
            // Attribution is independent of pricing: in the actual basis a
            // never-priced state can still have billed spend, so nothing is
            // greyed out there.
            disabledStateIds={basis === "actual" ? [] : disabledStateIds}
            disabledLabel="No cost data yet"
            className="min-w-[220px]"
          />
          {basis !== "actual" && selectedStateId && selectedHasData && (
            <RecalculateButton stateId={selectedStateId} onDone={refresh} />
          )}
        </div>
      </PageHeader>

      <PageSection className="mx-4 sm:mx-6">
        <div className="flex flex-col gap-4">
          {basis !== "actual" && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <KpiCard
              label="Latest monthly"
              value={
                latestMonthly !== null ? formatCurrency(latestMonthly, latestCurrency) : "—"
              }
              hint={selectedHasData ? `${latestCurrency} projection` : undefined}
              accessory={
                selectedHasData ? (
                  <DeltaBadge
                    current={historyDelta.current}
                    previous={historyDelta.previous}
                    currency={latestCurrency}
                  />
                ) : undefined
              }
            />
            <KpiCard
              label="Snapshot taken"
              value={latestCalculatedAt ? formatRelative(latestCalculatedAt) : "—"}
              hint={latestCalculatedAt ? new Date(latestCalculatedAt).toLocaleString() : undefined}
              accessory={provenance ? <ProvenanceBadge triggeredBy={provenance} /> : undefined}
            />
            <KpiCard
              label="Pricing coverage"
              value={typeof latestCoverage === "number" ? `${latestCoverage.toFixed(1)}%` : "—"}
              hint={
                typeof unpricedCount === "number" && unpricedCount > 0
                  ? `${unpricedCount} resource${unpricedCount === 1 ? "" : "s"} unpriced`
                  : typeof latestCoverage === "number" && latestCoverage < 100
                    ? "Some resources have no pricing"
                    : undefined
              }
            />
            <KpiCard
              label="Range"
              value={COST_RANGES.find((r) => r.id === range)?.label ?? range}
              hint={`${points?.length ?? 0} snapshot${points?.length === 1 ? "" : "s"}`}
            />
            {basis === "both" && (
              <KpiCard
                label="Actual ≈ monthly"
                value={
                  stateRunRate !== null ? formatCurrency(stateRunRate, actualsCurrency) : "—"
                }
                hint={
                  stateRunRate !== null
                    ? actualsWindow
                      ? `billed ${actualsWindow}, normalised to a month`
                      : "billed window normalised to a month"
                    : actuals && actuals.line_count > 0
                      ? `billed window under ${MIN_COMPARE_WINDOW_DAYS} days — see per-resource billed sums`
                      : "no billed spend attributed yet"
                }
                accessory={
                  stateRunRate !== null ? (
                    <DeltaBadge
                      current={stateRunRate}
                      previous={latestMonthly}
                      currency={latestCurrency}
                      title="Actual run rate vs estimated monthly"
                    />
                  ) : undefined
                }
              />
            )}
          </div>
          )}

          {basis === "actual" && (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              <KpiCard
                label="Billed (window)"
                value={actualBilled !== null ? formatCurrency(actualBilled, actualsCurrency) : "—"}
                hint={actualsWindow ?? undefined}
              />
              <KpiCard
                label="Actual ≈ monthly"
                value={
                  stateRunRate !== null ? formatCurrency(stateRunRate, actualsCurrency) : "—"
                }
                hint={
                  stateRunRate !== null
                    ? "billed window normalised to a month"
                    : `window under ${MIN_COMPARE_WINDOW_DAYS} days — too short to normalise`
                }
              />
              <KpiCard
                label="Billing lines"
                value={`${actuals?.line_count ?? "—"}`}
                hint={
                  actuals?.computed_at
                    ? `attributed ${new Date(actuals.computed_at).toLocaleString()}`
                    : undefined
                }
              />
              <KpiCard
                label="Resources matched"
                value={`${actuals?.resources.length ?? "—"}`}
                hint="managed addresses the bill named"
              />
            </div>
          )}

          <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
            {basis !== "actual" && <CostRangeSelector value={range} onChange={setRange} />}
            <CostBasisSelector value={basis} onChange={setBasis} />
          </div>

          {basis !== "actual" && (
          <PageSurface>
            {!selectedState && (
              <div className="flex items-center justify-center h-[320px] text-[var(--sg-text-muted)]">
                Select a state to view its cost history.
              </div>
            )}
            {selectedState && !selectedHasData && (
              <div className="flex flex-col items-center justify-center h-[320px] gap-2 text-center px-4">
                <div className="text-[var(--sg-text)] font-medium">
                  No cost data yet for {selectedState.name}
                </div>
                <div className="text-sm text-[var(--sg-text-muted)] max-w-md">
                  This state has not been priced yet. Pick a different state from the
                  dropdown to compare.
                </div>
              </div>
            )}
            {selectedState && selectedHasData && historyLoading && (
              <div className="flex items-center justify-center h-[320px] text-[var(--sg-text-muted)]">
                Loading cost history…
              </div>
            )}
            {selectedState && selectedHasData && historyError && (
              <div className="flex items-center justify-center h-[320px] text-[var(--sg-error)]">
                {historyError}
              </div>
            )}
            {selectedState &&
              selectedHasData &&
              !historyLoading &&
              !historyError &&
              points !== null &&
              points.length === 0 && (
                <div className="flex flex-col items-center justify-center h-[320px] gap-2 text-center px-4">
                  <div className="text-[var(--sg-text)] font-medium">
                    No snapshots in this window
                  </div>
                  <div className="text-sm text-[var(--sg-text-muted)]">
                    {'Try a longer range — e.g. "Since oldest data".'}
                  </div>
                </div>
              )}
            {selectedState &&
              selectedHasData &&
              !historyLoading &&
              !historyError &&
              points !== null &&
              points.length > 0 && <CostHistoryChart points={points} />}
          </PageSurface>
          )}

          {basis !== "actual" && selectedState && selectedHasData && (
            <>
              {breakdownLoading && (
                <div className="text-sm text-[var(--sg-text-muted)]">
                  Loading resource breakdown…
                </div>
              )}
              {!breakdownLoading && unsupported && <CoverageGapsPanel data={unsupported} />}
              {!breakdownLoading && stateCosts && stateCosts.instance_costs.length > 0 && (
                <div className="flex flex-col gap-2">
                  <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
                    Resources
                  </div>
                  <ResourceCostTable
                    instanceCosts={stateCosts.instance_costs}
                    currency={footerCurrency}
                    actuals={basis === "both" ? actualsByAddress : undefined}
                  />
                </div>
              )}
              <div className="text-xs text-[var(--sg-text-dim)]">
                Estimate · list pricing · {footerCurrency} · not actual billed cost.
                {basis === "both" &&
                  " The Actual column is billed (FOCUS) spend attributed by cloud identifier; — means no billing line matched that resource."}
              </div>
            </>
          )}

          {basis === "actual" && !selectedState && (
            <div className="flex items-center justify-center h-[200px] text-[var(--sg-text-muted)]">
              Select a state to view its billed spend.
            </div>
          )}
          {basis === "actual" &&
            selectedState &&
            (actualsLoading && !actuals ? (
              <div className="text-sm text-[var(--sg-text-muted)]">Loading actual spend…</div>
            ) : actuals && actuals.line_count > 0 ? (
              <>
                <div className="flex flex-col gap-2">
                  <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
                    Resources · billed
                  </div>
                  <ActualResourceTable
                    resources={actuals.resources}
                    fallbackCurrency={actualsCurrency}
                  />
                </div>
                <div className="text-xs text-[var(--sg-text-dim)]">
                  Actual billed cost from your FOCUS billing exports
                  {actualsWindow ? ` · ${actualsWindow}` : ""} — not an estimate. Managed
                  resources absent here matched none of the bill&apos;s identifiers.
                </div>
              </>
            ) : (
              <div className="flex flex-col items-center justify-center min-h-[200px] gap-2 text-center px-4 bg-[var(--sg-bg-1)] border border-dashed border-[var(--sg-border-light)] rounded-md">
                <div className="text-[var(--sg-text)] font-medium">
                  No billed spend attributed to {selectedState.name} yet
                </div>
                <div className="text-sm text-[var(--sg-text-muted)] max-w-lg">
                  Attribution needs a synced FOCUS billing export with lines naming this
                  state&apos;s cloud resources, and refreshes within a day or so of each sync.
                  Tenant-wide actuals — including spend on resources Stategraph doesn&apos;t
                  manage — live in the cost overview.
                </div>
                <DeepLink
                  href="/cost-overview?basis=actual"
                  className="text-sm text-[var(--sg-accent)] hover:underline"
                >
                  View tenant actuals →
                </DeepLink>
              </div>
            ))}
        </div>
      </PageSection>
    </div>
  );
}

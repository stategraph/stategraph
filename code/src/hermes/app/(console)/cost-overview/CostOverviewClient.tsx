"use client";

import { DeepLink } from "@/components/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Download } from "lucide-react";

import {
  BreakdownTable,
  CostBasisSelector,
  CostRangeSelector,
  CostDisabledNotice,
  DeltaBadge,
  KpiCard,
  PillGroup,
  TenantActualsSections,
  TenantCostHistoryChart,
} from "@/components/cost";
import { Button } from "@/components/ui/button";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { useTenant } from "@/contexts";
import {
  useCostAvailability,
  useCostBasis,
  useTenantCostRange,
  useTenantHistoryGrouping,
} from "@/hooks";
import type { TenantHistoryGroupBy } from "@/hooks/useTenantHistoryGrouping";
import { useTenantCostHistory } from "@/hooks/useTenantCostHistory";
import { useTenantCosts } from "@/hooks/useTenantCosts";
import { useUrlSyncedNullable } from "@/hooks/useUrlSyncedParam";
import { getTenantCostTagKeys, type TenantCostState } from "@/lib/api/client";
import { formatCurrency, parseCost, tenantCurrencyFor } from "@/lib/cost/format";
import { COST_RANGES } from "@/lib/cost/range";
import {
  deltaAbsolute,
  deltaOverRange,
  groupDeltasOverRange,
  type CostDelta,
} from "@/lib/cost/delta";
import { downloadCsv } from "@/lib/cost/export";
import { getProviderLabel } from "@/lib/instances/attributes";

const GROUP_BY_OPTIONS: { id: TenantHistoryGroupBy; label: string }[] = [
  { id: "none", label: "Total" },
  { id: "provider", label: "By provider" },
  { id: "type", label: "By type" },
  { id: "tag", label: "By tag" },
];

const DIMENSION_LABEL: Record<Exclude<TenantHistoryGroupBy, "none">, string> = {
  provider: "provider",
  type: "resource type",
  tag: "tag value",
};

function TagKeyPicker({
  tagKeys,
  value,
  onChange,
  isLoading,
}: {
  tagKeys: string[];
  value: string | null;
  onChange: (next: string | null) => void;
  isLoading: boolean;
}) {
  return (
    <select
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value || null)}
      disabled={isLoading}
      className="h-8 px-2 text-sm rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] text-[var(--sg-text)]"
    >
      <option value="">{isLoading ? "Loading…" : "Select tag key"}</option>
      {tagKeys.map((k) => (
        <option key={k} value={k}>
          {k}
        </option>
      ))}
    </select>
  );
}

/** A small list of group movers (name + signed delta), used for top movers. */
function MoversList({
  title,
  movers,
  currency,
  emptyLabel,
}: {
  title: string;
  movers: { name: string; delta: CostDelta }[];
  currency: string;
  emptyLabel: string;
}) {
  return (
    <div className="flex flex-col gap-2">
      <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">{title}</div>
      <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
        {movers.length === 0 ? (
          <div className="px-3 py-2 text-sm text-[var(--sg-text-muted)]">{emptyLabel}</div>
        ) : (
          movers.map((m) => (
            <div
              key={m.name}
              className="flex items-center justify-between gap-3 px-3 py-2 border-b last:border-b-0 border-[var(--sg-border-light)]"
            >
              <span className="text-sm text-[var(--sg-text)] truncate" title={m.name}>
                {m.name}
              </span>
              <DeltaBadge current={m.delta.current} previous={m.delta.previous} currency={currency} />
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function HighestSpendStates({
  rows,
  currency,
}: {
  rows: { s: TenantCostState; monthly: number }[];
  currency: string;
}) {
  return (
    <div className="flex flex-col gap-2">
      <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
        Highest spend · states
      </div>
      <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
        {rows.length === 0 ? (
          <div className="px-3 py-2 text-sm text-[var(--sg-text-muted)]">No priced states.</div>
        ) : (
          rows.map(({ s, monthly }) => (
            <div
              key={s.state_id}
              className="flex items-center justify-between gap-3 px-3 py-2 border-b last:border-b-0 border-[var(--sg-border-light)]"
            >
              <span className="text-sm text-[var(--sg-text)] truncate" title={s.state_name}>
                {s.state_name}
              </span>
              <span className="text-sm font-mono text-[var(--sg-text-muted)]">
                {formatCurrency(monthly, currency)}
              </span>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function StatesTable({
  states,
  currency,
}: {
  states: TenantCostState[];
  currency: string;
}) {
  // Shared cell formatters so the table and the mobile cards stay in sync.
  const monthlyText = (s: TenantCostState) => {
    const monthly = parseCost(s.monthly_cost);
    return monthly !== null ? formatCurrency(monthly, currency) : "—";
  };
  const coverageText = (s: TenantCostState) =>
    typeof s.coverage_percent === "number" ? `${s.coverage_percent.toFixed(1)}%` : "—";
  const resourcesText = (s: TenantCostState) =>
    typeof s.resource_count === "number" ? String(s.resource_count) : "—";
  const computedText = (s: TenantCostState) =>
    s.calculated_at ? new Date(s.calculated_at).toLocaleString() : "—";
  const stateLink = (s: TenantCostState, className: string) => (
    <DeepLink
      href={`/cost-analysis?state=${encodeURIComponent(s.state_id)}`}
      className={className}
      title="Open per-state cost analysis"
    >
      {s.state_name}
    </DeepLink>
  );

  return (
    <>
      {/* Desktop / tablet table (lg+) */}
      <div className="hidden lg:block bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
              <th className="text-left px-3 py-2 font-medium">State</th>
              <th className="text-right px-3 py-2 font-medium">Monthly</th>
              <th className="text-right px-3 py-2 font-medium">Coverage</th>
              <th className="text-right px-3 py-2 font-medium">Resources</th>
              <th className="text-right px-3 py-2 font-medium">Last computed</th>
            </tr>
          </thead>
          <tbody>
            {states.map((s) => (
              <tr
                key={s.state_id}
                className="border-b last:border-b-0 border-[var(--sg-border-light)]"
              >
                <td className="px-3 py-2 text-[var(--sg-text)]">
                  {stateLink(s, "text-[var(--sg-accent)] hover:underline")}
                </td>
                <td className="px-3 py-2 text-right font-mono">{monthlyText(s)}</td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {coverageText(s)}
                </td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {resourcesText(s)}
                </td>
                <td className="px-3 py-2 text-right text-[var(--sg-text-muted)]">
                  {computedText(s)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile card list (below lg) */}
      <div className="lg:hidden space-y-3">
        {states.map((s) => (
          <div
            key={s.state_id}
            className="rounded-lg border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] p-3"
          >
            {stateLink(s, "text-[var(--sg-accent)] hover:underline font-medium break-all")}
            <div className="mt-2 space-y-1.5 text-sm">
              <div className="flex items-center justify-between gap-3">
                <span className="text-[var(--sg-text-muted)]">Monthly</span>
                <span className="font-mono text-[var(--sg-text)]">{monthlyText(s)}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span className="text-[var(--sg-text-muted)]">Coverage</span>
                <span className="font-mono text-[var(--sg-text-muted)]">{coverageText(s)}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span className="text-[var(--sg-text-muted)]">Resources</span>
                <span className="font-mono text-[var(--sg-text-muted)]">{resourcesText(s)}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span className="text-[var(--sg-text-muted)]">Last computed</span>
                <span className="text-right text-[var(--sg-text-muted)]">{computedText(s)}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}

export function CostOverviewClient() {
  const { currentTenant, isLoading: tenantLoading } = useTenant();
  const { capability: costCapability, isLoading: costLoading } = useCostAvailability();
  const [basis, setBasis] = useCostBasis();
  const [range, setRange] = useTenantCostRange();
  const { groupBy, tagKey, setGroupBy, setTagKey } = useTenantHistoryGrouping();
  const [focus, setFocus] = useUrlSyncedNullable("focus");

  // When cost is disabled on the server, show the shared "enable cost" notice
  // (see below) -- the same one Analysis and Explorer show.
  const costSupported = !costLoading && costCapability?.enabled === true;

  // The tag_key flowing into the rollup is only meaningful when group_by=tag.
  const rollupTagKey = groupBy === "tag" ? tagKey ?? undefined : undefined;
  const historyGroupBy = groupBy === "none" ? undefined : groupBy;
  const historyTagKey = groupBy === "tag" && tagKey ? tagKey : undefined;

  // On the pure-actual basis nothing estimated is rendered; skip the fetches.
  const skipEstimates = basis === "actual";
  const {
    rollup,
    isLoading: rollupLoading,
    error: rollupError,
  } = useTenantCosts({ tagKey: rollupTagKey, skip: skipEstimates });
  const {
    history,
    isLoading: historyLoading,
    error: historyError,
  } = useTenantCostHistory({
    range,
    groupBy: historyGroupBy,
    tagKey: historyTagKey,
    skip: skipEstimates,
  });

  const [tagKeys, setTagKeys] = useState<string[]>([]);
  const [tagKeysLoading, setTagKeysLoading] = useState(false);

  // Load available tag keys lazily when group_by=tag is picked.
  useEffect(() => {
    const tenant = currentTenant;
    if (!tenant || groupBy !== "tag") return;
    let cancelled = false;
    async function loadTagKeys(tenantId: string) {
      setTagKeysLoading(true);
      try {
        const res = await getTenantCostTagKeys(tenantId);
        if (!cancelled) setTagKeys(res.tag_keys);
      } catch {
        if (!cancelled) setTagKeys([]);
      } finally {
        if (!cancelled) setTagKeysLoading(false);
      }
    }
    loadTagKeys(tenant.id);
    return () => {
      cancelled = true;
    };
  }, [currentTenant, groupBy]);

  const handleGroupByChange = useCallback(
    (next: TenantHistoryGroupBy) => {
      setGroupBy(next);
      setFocus(null);
    },
    [setGroupBy, setFocus]
  );

  // Clicking a breakdown row pivots the trend chart onto that dimension and
  // focuses the series (toggling off if it's already the focused one).
  const focusFromBreakdown = useCallback(
    (dim: Exclude<TenantHistoryGroupBy, "none">, name: string) => {
      if (groupBy === dim && focus === name) {
        setFocus(null);
        return;
      }
      if (groupBy !== dim) setGroupBy(dim);
      setFocus(name);
    },
    [groupBy, focus, setGroupBy, setFocus]
  );

  // The rollup omits `currency` in two cases: the empty-rollup case (no
  // priced state) and the mixed-currency case (snapshots span >1 currency,
  // so the summed money fields aren't expressible in a single unit -- see
  // string_agg/totals_of_row on the backend). Distinguish: empty vs mixed
  // matters for the UI, which should *label* the mixed case rather than
  // silently fall back to a single currency.
  const { currency, isMixedCurrency } = tenantCurrencyFor(rollup);
  const currencyHint = isMixedCurrency ? "Mixed currencies" : `${currency} projection`;
  const monthly = parseCost(rollup?.monthly_cost);
  const hourly = parseCost(rollup?.hourly_cost);
  // A state appears in the rollup with calculated_at set iff it has ever been
  // priced (and so contributed to the totals).
  const pricedStates = useMemo(
    () => (rollup?.states ?? []).filter((s) => typeof s.calculated_at === "string").length,
    [rollup]
  );
  const coverage = rollup?.coverage_percent;
  // group_by=tag without a tag_key suppresses the history fetch (the call
  // would 400); the chart surface shows a "pick a tag key" empty state in
  // that case, and the generic "no snapshots" empty state hides while it's
  // true.
  const needsTagKey = groupBy === "tag" && !tagKey;

  // Period-over-period deltas for the headline KPIs, from the history series.
  const historyPoints = useMemo(() => history?.points ?? [], [history]);
  const monthlyDelta = useMemo(() => deltaOverRange(historyPoints), [historyPoints]);
  const hourlyDelta = useMemo(
    () => deltaOverRange(historyPoints, (p) => p.hourly_cost),
    [historyPoints]
  );

  // Top movers: per-group change over the range (only when grouped) + the
  // highest-spend states (current spend, since per-state deltas need N calls).
  const groupMovers = useMemo(() => {
    if (groupBy === "none") return { increases: [], decreases: [] };
    const arr = [...groupDeltasOverRange(historyPoints).entries()]
      .map(([name, delta]) => ({ name, delta, abs: deltaAbsolute(delta) }))
      .filter((m): m is { name: string; delta: CostDelta; abs: number } => m.abs !== null);
    const increases = arr.filter((m) => m.abs > 0).sort((a, b) => b.abs - a.abs).slice(0, 5);
    const decreases = arr.filter((m) => m.abs < 0).sort((a, b) => a.abs - b.abs).slice(0, 5);
    return { increases, decreases };
  }, [groupBy, historyPoints]);
  const topStates = useMemo(() => {
    return (rollup?.states ?? [])
      .map((s) => ({ s, monthly: parseCost(s.monthly_cost) }))
      .filter((x): x is { s: TenantCostState; monthly: number } => x.monthly !== null)
      .sort((a, b) => b.monthly - a.monthly)
      .slice(0, 5);
  }, [rollup]);

  // When a series is focused, filter every day's groups down to it so the
  // chart draws that single band (reusing the grouped renderer).
  const focusedPoints = useMemo(() => {
    if (!focus || !history) return null;
    return history.points.map((p) => ({
      ...p,
      groups: (p.groups ?? []).filter((g) => g.name === focus),
    }));
  }, [focus, history]);

  const handleExport = useCallback(() => {
    if (!rollup) return;
    const headers = [
      "state_id",
      "state_name",
      "monthly_cost",
      "hourly_cost",
      "coverage_percent",
      "resource_count",
      "supported_count",
      "calculated_at",
      "currency",
    ];
    const rows = rollup.states.map((s) => [
      s.state_id,
      s.state_name,
      s.monthly_cost ?? "",
      s.hourly_cost ?? "",
      typeof s.coverage_percent === "number" ? s.coverage_percent.toFixed(2) : "",
      s.resource_count ?? "",
      s.supported_count ?? "",
      s.calculated_at ?? "",
      isMixedCurrency ? "mixed" : currency,
    ]);
    downloadCsv(`tenant-costs-${currentTenant?.id ?? "tenant"}.csv`, headers, rows);
  }, [rollup, currency, isMixedCurrency, currentTenant]);

  if (tenantLoading || costLoading) {
    return (
      <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
        Loading…
      </div>
    );
  }

  // Cost disabled on the server -- show the shared notice (consistent with
  // Analysis and Explorer).
  if (!costSupported) {
    return <CostDisabledNotice />;
  }

  if (!currentTenant) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[40vh] gap-2 text-center px-4">
        <div className="text-[var(--sg-text)] font-medium">No tenant available</div>
        <div className="text-sm text-[var(--sg-text-muted)] max-w-md">
          Create or join a tenant first; tenant cost overview needs at least one tenant to
          aggregate over.
        </div>
      </div>
    );
  }

  const showMovers = groupBy !== "none";
  const dimLabel = groupBy === "none" ? "" : DIMENSION_LABEL[groupBy];
  const periodLabel = COST_RANGES.find((r) => r.id === range)?.label ?? range;

  return (
    <div className="flex flex-col">
      <PageHeader
        title="Overview"
        subtitle="Aggregated cost across all states in this tenant"
      >
        {basis !== "actual" && (
          <Button
            variant="outline"
            size="sm"
            onClick={handleExport}
            disabled={!rollup || rollup.states.length === 0}
          >
            <Download className="w-4 h-4 mr-2" />
            Export CSV
          </Button>
        )}
      </PageHeader>

      <PageSection className="mx-4 sm:mx-6">
        <div className="flex flex-col gap-4">
          <CostBasisSelector value={basis} onChange={setBasis} />

          {basis !== "actual" && (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
            <KpiCard
              label="Total monthly"
              value={monthly !== null ? formatCurrency(monthly, currency) : "—"}
              hint={currencyHint}
              accessory={
                <DeltaBadge
                  current={monthlyDelta.current}
                  previous={monthlyDelta.previous}
                  currency={currency}
                />
              }
            />
            <KpiCard
              label="Total hourly"
              value={hourly !== null ? formatCurrency(hourly, currency) : "—"}
              hint={isMixedCurrency ? "Mixed currencies" : undefined}
              accessory={
                <DeltaBadge
                  current={hourlyDelta.current}
                  previous={hourlyDelta.previous}
                  currency={currency}
                />
              }
            />
            <KpiCard
              label="Priced states"
              value={`${pricedStates}/${rollup?.states.length ?? 0}`}
              hint={
                rollup && rollup.states.length > 0
                  ? `${rollup.states.length} live in tenant`
                  : undefined
              }
            />
            <KpiCard
              label="Pricing coverage"
              value={typeof coverage === "number" ? `${coverage.toFixed(1)}%` : "—"}
              hint={
                typeof coverage === "number" && coverage < 100
                  ? "Some resources have no pricing"
                  : undefined
              }
            />
            <KpiCard
              label="Resources"
              value={`${rollup?.resource_count ?? "—"}`}
              hint={
                rollup
                  ? `${rollup.supported_count} supported, ${rollup.priced_count} priced`
                  : undefined
              }
            />
          </div>
          )}

          {basis !== "estimated" && (
            <TenantActualsSections
              compare={basis === "both"}
              estimatedMonthly={monthly}
              estimatedByProvider={rollup?.by_provider ?? null}
              estimatedCurrency={currency}
            />
          )}

          {basis !== "actual" && (
          <>
          <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                Period
              </span>
              <CostRangeSelector value={range} onChange={setRange} />
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                Group by
              </span>
              <PillGroup options={GROUP_BY_OPTIONS} value={groupBy} onChange={handleGroupByChange} />
              {groupBy === "tag" && (
                <TagKeyPicker
                  tagKeys={tagKeys}
                  value={tagKey}
                  onChange={setTagKey}
                  isLoading={tagKeysLoading}
                />
              )}
            </div>
          </div>

          {rollupError && <div className="text-sm text-[var(--sg-error)]">{rollupError}</div>}

          {focus && (
            <div className="flex items-center gap-2 text-xs">
              <span className="text-[var(--sg-text-muted)]">Trend filtered to</span>
              <span className="font-mono text-[var(--sg-text)]">{focus}</span>
              <button
                onClick={() => setFocus(null)}
                className="text-[var(--sg-accent)] hover:underline"
              >
                clear
              </button>
            </div>
          )}

          <PageSurface>
            {historyLoading && (
              <div className="flex items-center justify-center h-[320px] text-[var(--sg-text-muted)]">
                Loading cost history…
              </div>
            )}
            {!historyLoading && historyError && (
              <div className="flex items-center justify-center h-[320px] text-[var(--sg-error)]">
                {historyError}
              </div>
            )}
            {!historyLoading && !historyError && needsTagKey && (
              <div className="flex flex-col items-center justify-center h-[320px] gap-2 text-center px-4">
                <div className="text-[var(--sg-text)] font-medium">Pick a tag key</div>
                <div className="text-sm text-[var(--sg-text-muted)]">
                  Choose a tag key from the dropdown to break cost down by that tag value.
                </div>
              </div>
            )}
            {!historyLoading &&
              !historyError &&
              !needsTagKey &&
              history &&
              history.points.length === 0 && (
                <div className="flex flex-col items-center justify-center h-[320px] gap-2 text-center px-4">
                  <div className="text-[var(--sg-text)] font-medium">
                    No snapshots in this window
                  </div>
                  <div className="text-sm text-[var(--sg-text-muted)]">
                    {'Try a longer range — e.g. "Since oldest data".'}
                  </div>
                </div>
              )}
            {!historyLoading && !historyError && history && history.points.length > 0 && (
              <div className="flex flex-col gap-2">
                {groupBy !== "none" && !focus && (
                  <div className="text-xs text-[var(--sg-text-dim)]">
                    Stacked by {dimLabel} — largest series shown, smaller ones combined as Other.
                  </div>
                )}
                <TenantCostHistoryChart
                  points={focus && focusedPoints ? focusedPoints : history.points}
                  grouped={focus ? true : groupBy !== "none"}
                  currency={currency}
                />
              </div>
            )}
          </PageSurface>

          {rollup && (
            <div className="flex flex-col gap-2">
              <div className="flex items-baseline gap-2 flex-wrap">
                <span className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
                  Top movers
                </span>
                <span className="text-xs text-[var(--sg-text-dim)]">
                  {showMovers
                    ? `Largest changes by ${dimLabel} over ${periodLabel.toLowerCase()}`
                    : "Use the Group by control above to rank providers, types, or tags by change"}
                </span>
              </div>
              {showMovers ? (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                  <MoversList
                    title="Biggest increases"
                    movers={groupMovers.increases}
                    currency={currency}
                    emptyLabel="No increases over this range."
                  />
                  <MoversList
                    title="Biggest decreases"
                    movers={groupMovers.decreases}
                    currency={currency}
                    emptyLabel="No decreases over this range."
                  />
                  <HighestSpendStates rows={topStates} currency={currency} />
                </div>
              ) : (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                  <div className="lg:col-span-2 flex items-center justify-center text-center px-4 py-6 rounded-md border border-dashed border-[var(--sg-border-light)] text-sm text-[var(--sg-text-muted)]">
                    Pick a Group by dimension above to see your biggest cost increases and decreases.
                  </div>
                  <HighestSpendStates rows={topStates} currency={currency} />
                </div>
              )}
            </div>
          )}

          {rollup && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <BreakdownTable
                title="By provider"
                entries={rollup.by_provider}
                currency={currency}
                formatName={getProviderLabel}
                onRowClick={(name) => focusFromBreakdown("provider", name)}
                activeName={groupBy === "provider" ? focus : null}
              />
              <BreakdownTable
                title="By resource type"
                entries={rollup.by_type}
                currency={currency}
                onRowClick={(name) => focusFromBreakdown("type", name)}
                activeName={groupBy === "type" ? focus : null}
              />
              {groupBy === "tag" && (
                <div className="lg:col-span-2">
                  <BreakdownTable
                    title={tagKey ? `By tag "${tagKey}"` : "By tag"}
                    entries={rollup.by_tag}
                    currency={currency}
                    onRowClick={(name) => focusFromBreakdown("tag", name)}
                    activeName={groupBy === "tag" ? focus : null}
                  />
                </div>
              )}
            </div>
          )}

          {rollup && rollup.states.length > 0 && (
            <div className="flex flex-col gap-2">
              <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
                States
              </div>
              <StatesTable states={rollup.states} currency={currency} />
            </div>
          )}

          {rollupLoading && !rollup && (
            <div className="flex items-center justify-center h-[120px] text-[var(--sg-text-muted)]">
              Loading tenant rollup…
            </div>
          )}
          </>
          )}
        </div>
      </PageSection>
    </div>
  );
}

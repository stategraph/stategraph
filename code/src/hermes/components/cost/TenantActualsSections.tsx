"use client";

import { DeepLink } from "@/components/navigation";
import { useTenantCostAttribution } from "@/hooks/useTenantCostAttribution";
import type {
  CostBreakdownEntry,
  TenantCostAttributionProvider,
} from "@/lib/api/client";
import {
  attributionCurrencyFor,
  formatWindow,
  gapAnalysisHref,
  monthlyRunRate,
  MIN_COMPARE_WINDOW_DAYS,
} from "@/lib/cost/actuals";
import { formatCurrency, parseCost } from "@/lib/cost/format";

import { ActualsEmptyState } from "./ActualsEmptyState";
import { AttributionGapsPanel } from "./AttributionGapsPanel";
import { DeltaBadge } from "./DeltaBadge";
import { KpiCard } from "./KpiCard";
import { UnmanagedSpendPanel } from "./UnmanagedSpendPanel";

export interface TenantActualsSectionsProps {
  /** Also compare against the estimates ("both" basis) instead of actuals alone. */
  compare: boolean;
  /** Tenant estimated monthly (parsed), for the run-rate comparison when comparing. */
  estimatedMonthly?: number | null;
  /** Estimated per-provider breakdown, for the compare table when comparing. */
  estimatedByProvider?: CostBreakdownEntry[] | null;
  /** Currency the estimates are in (used for comparison deltas). */
  estimatedCurrency?: string;
  /** Show the paginated unmanaged-resources drill-down (Explorer). */
  showUnmanagedPanel?: boolean;
}

/**
 * The actual-spend (FOCUS) sections of the tenant cost pages: headline KPIs
 * with unmanaged spend leading into gap analysis, the per-provider split, the
 * attribution-gaps disclosure, and optionally the unmanaged drill-down.
 * Mount only on the actual/both bases -- pages gate on the basis, and
 * mounting is what triggers the attribution fetch. When `compare` is set the
 * per-provider table compares estimated monthly against the billed monthly
 * run rate -- aggregate-level only, and only when the billed window spans at
 * least {@link MIN_COMPARE_WINDOW_DAYS} days.
 */
export function TenantActualsSections({
  compare,
  estimatedMonthly,
  estimatedByProvider,
  estimatedCurrency,
  showUnmanagedPanel = false,
}: TenantActualsSectionsProps) {
  const { attribution, isLoading, error } = useTenantCostAttribution();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-[120px] text-[var(--sg-text-muted)]">
        Loading actual cost data…
      </div>
    );
  }
  if (error) {
    return <div className="text-sm text-[var(--sg-error)]">{error}</div>;
  }
  if (!attribution) return null;
  if (attribution.line_count === 0) {
    return <ActualsEmptyState />;
  }

  const { currency, isMixedCurrency } = attributionCurrencyFor(attribution);
  const windowLabel = formatWindow(attribution.window_start, attribution.window_end);
  const total = parseCost(attribution.total_cost);
  const attributed = parseCost(attribution.attributed_cost);
  const unmanaged = parseCost(attribution.unmanaged_cost);
  const managedRunRate = monthlyRunRate(
    attribution.attributed_cost,
    attribution.window_start,
    attribution.window_end
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-baseline gap-2 flex-wrap">
        <span className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
          Actual spend
        </span>
        <span className="text-xs text-[var(--sg-text-dim)]">
          billed via FOCUS exports{windowLabel ? ` · ${windowLabel}` : ""}
          {isMixedCurrency ? " · mixed currencies" : ""}
        </span>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <DeepLink
          href={gapAnalysisHref(attribution)}
          className="block rounded-md transition-shadow hover:ring-1 hover:ring-[var(--sg-warning)]"
          title="Open gap analysis to bring these resources under management"
        >
          <KpiCard
            label="Unmanaged spend"
            value={unmanaged !== null ? formatCurrency(unmanaged, currency) : "—"}
            hint="billed outside Stategraph · import it →"
            className="h-full border-[var(--sg-warning)]"
            valueClassName="text-[var(--sg-warning)]"
          />
        </DeepLink>
        <KpiCard
          label="Billed (window)"
          value={total !== null ? formatCurrency(total, currency) : "—"}
          hint={`${attribution.line_count} billing lines${windowLabel ? ` · ${windowLabel}` : ""}`}
        />
        {compare ? (
          <KpiCard
            label="Actual ≈ monthly (managed)"
            value={managedRunRate !== null ? formatCurrency(managedRunRate, currency) : "—"}
            hint={
              managedRunRate !== null
                ? "billed spend on managed resources, normalised to a month"
                : `window under ${MIN_COMPARE_WINDOW_DAYS} days — too short to compare`
            }
            accessory={
              managedRunRate !== null ? (
                <DeltaBadge
                  current={managedRunRate}
                  previous={estimatedMonthly ?? null}
                  currency={estimatedCurrency ?? currency}
                  title="Actual managed run rate vs estimated monthly"
                />
              ) : undefined
            }
          />
        ) : (
          <KpiCard
            label="Attributed to managed"
            value={attributed !== null ? formatCurrency(attributed, currency) : "—"}
            hint={`${attribution.attributed_count} billing lines matched managed resources`}
          />
        )}
        <KpiCard
          label="Attribution coverage"
          value={`${attribution.coverage_percent.toFixed(1)}%`}
          hint="share of billed spend pinned to a managed resource"
        />
      </div>

      <ProviderTable
        providers={attribution.by_provider}
        compare={compare}
        estimatedByProvider={estimatedByProvider ?? null}
        estimatedCurrency={estimatedCurrency ?? currency}
        fallbackCurrency={currency}
      />

      <AttributionGapsPanel attribution={attribution} />

      {showUnmanagedPanel && <UnmanagedSpendPanel attribution={attribution} />}

      <div className="text-xs text-[var(--sg-text-dim)]">
        Actual billed cost from your FOCUS billing exports — not an estimate.
        {compare
          ? ` Run rates normalise the billed window to a month; comparisons are only shown when the window spans at least ${MIN_COMPARE_WINDOW_DAYS} days.`
          : ""}
      </div>
    </div>
  );
}

function ProviderTable({
  providers,
  compare,
  estimatedByProvider,
  estimatedCurrency,
  fallbackCurrency,
}: {
  providers: TenantCostAttributionProvider[];
  compare: boolean;
  estimatedByProvider: CostBreakdownEntry[] | null;
  estimatedCurrency: string;
  fallbackCurrency: string;
}) {
  if (providers.length === 0) return null;
  return (
    <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
            <th className="text-left px-3 py-2 font-medium">Provider</th>
            {compare ? (
              <>
                <th className="text-right px-3 py-2 font-medium">Est. monthly</th>
                <th
                  className="text-right px-3 py-2 font-medium"
                  title={`Billed spend on managed resources, normalised to a month. Blank when the billed window spans under ${MIN_COMPARE_WINDOW_DAYS} days.`}
                >
                  Actual ≈/mo (managed)
                </th>
                <th className="text-right px-3 py-2 font-medium">vs estimate</th>
              </>
            ) : (
              <>
                <th className="text-right px-3 py-2 font-medium">Billed</th>
                <th className="text-right px-3 py-2 font-medium">Attributed</th>
                <th className="text-right px-3 py-2 font-medium">Unallocated</th>
              </>
            )}
            <th className="text-right px-3 py-2 font-medium">Unmanaged</th>
            <th className="text-right px-3 py-2 font-medium">Coverage</th>
          </tr>
        </thead>
        <tbody>
          {providers.map((p) => {
            const rowCurrency = p.currency ?? fallbackCurrency;
            const billed = parseCost(p.total_cost);
            const attributed = parseCost(p.attributed_cost);
            const unmanaged = parseCost(p.unmanaged_cost);
            const unallocated = parseCost(p.unallocated_cost);
            const runRate = monthlyRunRate(p.attributed_cost, p.window_start, p.window_end);
            const est = estimatedByProvider?.find((e) => e.name === p.provider);
            const estMonthly = est ? parseCost(est.monthly_cost) : null;
            return (
              <tr
                key={p.provider}
                className="border-b last:border-b-0 border-[var(--sg-border-light)]"
              >
                <td className="px-3 py-2 text-[var(--sg-text)]">{p.provider}</td>
                {compare ? (
                  <>
                    <td className="px-3 py-2 text-right font-mono">
                      {estMonthly !== null
                        ? formatCurrency(estMonthly, estimatedCurrency)
                        : "—"}
                    </td>
                    <td className="px-3 py-2 text-right font-mono">
                      {runRate !== null ? formatCurrency(runRate, rowCurrency) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right">
                      {runRate !== null && estMonthly !== null ? (
                        <DeltaBadge
                          current={runRate}
                          previous={estMonthly}
                          currency={estimatedCurrency}
                          title="Actual managed run rate vs estimated monthly"
                        />
                      ) : (
                        <span className="text-xs text-[var(--sg-text-dim)]">—</span>
                      )}
                    </td>
                  </>
                ) : (
                  <>
                    <td className="px-3 py-2 text-right font-mono">
                      {billed !== null ? formatCurrency(billed, rowCurrency) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                      {attributed !== null ? formatCurrency(attributed, rowCurrency) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                      {unallocated !== null ? formatCurrency(unallocated, rowCurrency) : "—"}
                    </td>
                  </>
                )}
                <td className="px-3 py-2 text-right font-mono" style={{ color: "var(--sg-warning)" }}>
                  {unmanaged !== null ? formatCurrency(unmanaged, rowCurrency) : "—"}
                </td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {p.coverage_percent.toFixed(1)}%
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

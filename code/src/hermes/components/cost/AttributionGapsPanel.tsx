"use client";

import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";

import type { TenantCostAttribution } from "@/lib/api/client";
import { attributionCurrencyFor } from "@/lib/cost/actuals";
import { formatCurrency, parseCost } from "@/lib/cost/format";

/**
 * Discloses the share of the bill that could not be pinned to a resource --
 * the actuals counterpart of {@link CoverageGapsPanel} on the estimated side:
 * unallocated spend (taxes, support, fees: nothing to match on), lines still
 * awaiting an attribution recompute, and the per-provider coverage split.
 * Renders nothing when attribution is complete.
 */
export function AttributionGapsPanel({ attribution }: { attribution: TenantCostAttribution }) {
  const [open, setOpen] = useState(false);

  const { currency } = attributionCurrencyFor(attribution);
  const unallocated = parseCost(attribution.unallocated_cost);
  const hasUnallocated = attribution.unallocated_count > 0;
  const hasUncomputed = attribution.uncomputed_count > 0;
  if (!hasUnallocated && !hasUncomputed) return null;

  return (
    <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
      <button
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center justify-between px-3 py-2 text-sm hover:bg-[var(--sg-bg-2)]"
      >
        <span className="flex items-center gap-2 text-[var(--sg-text)]">
          {open ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          Attribution gaps
          <span className="text-[var(--sg-text-muted)]">
            · {attribution.coverage_percent.toFixed(1)}% of billed spend attributed
          </span>
        </span>
        <span className="flex items-center gap-3 text-xs">
          {hasUnallocated && unallocated !== null && (
            <span style={{ color: "var(--sg-warning)" }}>
              {formatCurrency(unallocated, currency)} unallocated
            </span>
          )}
          {hasUncomputed && (
            <span style={{ color: "var(--sg-text-muted)" }}>
              {attribution.uncomputed_count} line
              {attribution.uncomputed_count === 1 ? "" : "s"} pending
            </span>
          )}
        </span>
      </button>
      {open && (
        <div className="px-3 py-3 border-t border-[var(--sg-border-light)] flex flex-col gap-4">
          {hasUnallocated && (
            <div className="flex flex-col gap-1">
              <div className="flex items-baseline gap-2 flex-wrap">
                <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                  Unallocated spend
                </span>
                <span className="text-xs text-[var(--sg-text-dim)]">
                  Taxes, support, fees, and account-level charges -- billing lines with no
                  resource identifier to match on.
                </span>
              </div>
              <div className="text-sm font-mono text-[var(--sg-text)]">
                {unallocated !== null ? formatCurrency(unallocated, currency) : "—"} across{" "}
                {attribution.unallocated_count} line
                {attribution.unallocated_count === 1 ? "" : "s"}
              </div>
            </div>
          )}
          {hasUncomputed && (
            <div className="flex flex-col gap-1">
              <div className="flex items-baseline gap-2 flex-wrap">
                <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                  Awaiting attribution
                </span>
                <span className="text-xs text-[var(--sg-text-dim)]">
                  Loaded since the last recompute; classified after the next billing sync.
                </span>
              </div>
              <div className="text-sm font-mono text-[var(--sg-text)]">
                {attribution.uncomputed_count} line
                {attribution.uncomputed_count === 1 ? "" : "s"}
              </div>
            </div>
          )}
          {attribution.by_provider.length > 1 && (
            <div className="flex flex-col gap-1">
              <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                Coverage by provider
              </span>
              <div className="flex flex-wrap gap-x-6 gap-y-1">
                {attribution.by_provider.map((p) => (
                  <span key={p.provider} className="text-xs font-mono text-[var(--sg-text)]">
                    {p.provider} · {p.coverage_percent.toFixed(1)}%
                  </span>
                ))}
              </div>
            </div>
          )}
          <div className="text-xs text-[var(--sg-text-muted)]">
            Unallocated spend can be attributed to no resource, so resource-level actuals add up
            to less than the total bill.
          </div>
        </div>
      )}
    </div>
  );
}

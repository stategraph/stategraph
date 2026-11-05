"use client";

import { useMemo } from "react";
import Link from "next/link";

import type { StateCostActualResource } from "@/lib/api/client";
import { formatWindow, monthlyRunRate, MIN_COMPARE_WINDOW_DAYS } from "@/lib/cost/actuals";
import { formatCurrency, parseCost } from "@/lib/cost/format";

/**
 * Per-resource actual spend for a state: one row per managed address the
 * bill's lines matched, with the billed sum over that resource's own
 * charge-period window and -- when the window is long enough -- a monthly run
 * rate. Rows are billed facts; resources without a row simply had no billing
 * line match their cloud identifiers. Sorted by billed cost descending (the
 * whole list is present, so the ordering is global, unlike the paginated
 * unmanaged table).
 */
export function ActualResourceTable({
  resources,
  fallbackCurrency,
}: {
  resources: StateCostActualResource[];
  fallbackCurrency: string;
}) {
  const rows = useMemo(
    () =>
      [...resources].sort(
        (a, b) => (parseCost(b.billed_cost) ?? 0) - (parseCost(a.billed_cost) ?? 0)
      ),
    [resources]
  );

  return (
    <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
            <th className="text-left px-3 py-2 font-medium">Resource</th>
            <th className="text-left px-3 py-2 font-medium">Window</th>
            <th className="text-right px-3 py-2 font-medium">Lines</th>
            <th className="text-right px-3 py-2 font-medium">Billed</th>
            <th
              className="text-right px-3 py-2 font-medium"
              title={`Billed sum normalised to a month; blank when the resource's billed window spans under ${MIN_COMPARE_WINDOW_DAYS} days`}
            >
              ≈ / mo
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => {
            const billed = parseCost(r.billed_cost);
            const currency = r.currency ?? fallbackCurrency;
            const rate = monthlyRunRate(r.billed_cost, r.window_start, r.window_end);
            const window = formatWindow(r.window_start, r.window_end);
            return (
              <tr
                key={r.address}
                className="border-b last:border-b-0 border-[var(--sg-border-light)]"
              >
                <td className="px-3 py-2">
                  <Link
                    href={`/instances?q=${encodeURIComponent(r.address)}`}
                    className="font-mono text-[var(--sg-accent)] hover:underline truncate max-w-[360px] inline-block align-bottom"
                    title={r.address}
                  >
                    {r.address}
                  </Link>
                </td>
                <td className="px-3 py-2 text-[var(--sg-text-muted)]">{window ?? "—"}</td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {r.line_count}
                </td>
                <td className="px-3 py-2 text-right font-mono">
                  {billed !== null ? formatCurrency(billed, currency) : "—"}
                </td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {rate !== null ? formatCurrency(rate, currency) : "—"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

"use client";

import { formatCurrency } from "@/lib/cost/format";
import type { CostEstimation } from "@/lib/wm/decode";

const money = (n: number | null, currency: string) =>
  n === null ? "—" : formatCurrency(n, currency);
const signed = (n: number | null, currency: string) => {
  if (n === null) return "—";
  return `${n > 0 ? "+" : ""}${formatCurrency(n, currency)}`;
};
const diffClass = (n: number | null) =>
  n === null || n === 0
    ? "text-[var(--sg-text)]"
    : n > 0
      ? "text-[var(--sg-op-destroy)]"
      : "text-[var(--sg-op-create)]";

/** Cost view fed by Terrateam's `tf/cost-estimation` step payload (Infracost).
 *  No budgets/policies — Terrateam's payload only carries the delta summary and
 *  a per-dirspace breakdown. */
export function WmCostPanel({ cost }: { cost: CostEstimation | null }) {
  if (!cost) {
    return (
      <div className="p-6 text-sm text-[var(--sg-text-muted)]">
        No cost estimate for this run. Cost estimation runs when Infracost is enabled
        and the plan has changes.
      </div>
    );
  }
  if (cost.failed) {
    return (
      <div className="p-6">
        <div className="text-sm text-[var(--sg-text-muted)] mb-2">Cost estimation failed:</div>
        <pre className="text-xs font-mono whitespace-pre-wrap bg-[var(--sg-bg-2)] rounded-md p-3 text-[var(--sg-text-muted)]">
          {cost.failed}
        </pre>
      </div>
    );
  }
  const c = cost.currency;
  return (
    <div className="flex flex-col gap-5 p-6">
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="rounded-md border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Monthly cost</div>
          <div className="mt-1 font-mono text-sm text-[var(--sg-text)]">
            {money(cost.prev, c)} → {money(cost.total, c)}
          </div>
        </div>
        <div className="rounded-md border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Change</div>
          <div className={`mt-1 font-mono text-lg font-semibold ${diffClass(cost.diff)}`}>
            {signed(cost.diff, c)}/mo
          </div>
        </div>
        <div className="rounded-md border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Dirspaces priced</div>
          <div className="mt-1 font-mono text-sm text-[var(--sg-text)]">{cost.dirspaces.length}</div>
        </div>
      </div>

      {cost.dirspaces.length > 0 && (
        <div className="flex flex-col gap-2">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Per dirspace</div>
          <div className="rounded-md border border-[var(--sg-border-light)] overflow-hidden">
            {cost.dirspaces.map((d, i) => (
              <div
                key={`${d.dir}|${d.workspace}|${i}`}
                className="flex items-center justify-between gap-3 border-b border-[var(--sg-border-light)] px-3 py-2 last:border-b-0"
              >
                <span className="truncate font-mono text-sm text-[var(--sg-text)]">
                  {d.dir || "."}
                  <span className="text-[var(--sg-text-muted)]"> · {d.workspace}</span>
                </span>
                <div className="flex items-center gap-3 shrink-0 font-mono text-sm">
                  <span className="text-[var(--sg-text-muted)]">
                    {money(d.prev, c)} → {money(d.total, c)}
                  </span>
                  <span className={diffClass(d.diff)}>{signed(d.diff, c)}/mo</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

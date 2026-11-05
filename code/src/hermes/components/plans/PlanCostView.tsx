"use client";

import { useEffect, useState } from "react";

import {
  getTxCostDelta,
  type TxCostDelta,
  type TxDetailResponse,
} from "@/lib/api/client";
import { formatCurrency, parseCost } from "@/lib/cost/format";

interface PlanCostViewProps {
  detail: TxDetailResponse;
}

function isDelta(v: TxCostDelta | { status?: string }): v is TxCostDelta {
  return (v as TxCostDelta).totals !== undefined;
}

const money = (s: string | undefined | null, currency: string) => {
  const n = parseCost(s ?? null);
  return n === null ? "—" : formatCurrency(n, currency);
};

const signedMoney = (s: string | undefined | null, currency: string) => {
  const n = parseCost(s ?? null);
  if (n === null) return "—";
  const sign = n > 0 ? "+" : "";
  return `${sign}${formatCurrency(n, currency)}`;
};

type DeltaState =
  | { kind: "loading" }
  | { kind: "ready"; delta: TxCostDelta }
  | { kind: "computing" }
  | { kind: "error"; message: string };

export function PlanCostView({ detail }: PlanCostViewProps) {
  const txId = detail.tx.id;
  // Settle the result together with its txId (the useStateCosts pattern) so
  // loading is derived, not set synchronously in the effect.
  const [settled, setSettled] = useState<{ txId: string; state: DeltaState } | null>(null);

  useEffect(() => {
    let cancelled = false;
    getTxCostDelta(txId)
      .then((res) => {
        if (cancelled) return;
        setSettled({
          txId,
          state: isDelta(res) ? { kind: "ready", delta: res } : { kind: "computing" },
        });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        // 404 = no preview for this tx (aborted, or a dashboard-only tx).
        const status = (err as { status?: number })?.status;
        setSettled({
          txId,
          state: {
            kind: "error",
            message:
              status === 404
                ? "No cost preview for this run."
                : err instanceof Error
                  ? err.message
                  : "Failed to load cost preview.",
          },
        });
      });
    return () => {
      cancelled = true;
    };
  }, [txId]);

  const state: DeltaState =
    settled !== null && settled.txId === txId ? settled.state : { kind: "loading" };

  if (state.kind === "loading") {
    return <div className="p-6 text-sm text-[var(--sg-text-muted)]">Loading cost preview…</div>;
  }
  if (state.kind === "error") {
    return <div className="p-6 text-sm text-[var(--sg-text-muted)]">{state.message}</div>;
  }
  if (state.kind === "computing") {
    return (
      <div className="p-6 text-sm text-[var(--sg-text-muted)]">
        Cost preview is still being calculated — check back in a moment.
      </div>
    );
  }

  const delta = state.delta;
  const t = delta.totals;
  const currency = t.currency ?? "USD";
  const changedStates = delta.states.filter((s) => parseCost(s.delta_monthly_cost ?? null) !== null);

  return (
    <div className="flex flex-col gap-5 p-6">
      {/* Totals */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="rounded-md border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Monthly cost</div>
          <div className="mt-1 font-mono text-sm text-[var(--sg-text)]">
            {money(t.current_monthly_cost, currency)} → {money(t.planned_monthly_cost, currency)}
          </div>
        </div>
        <div className="rounded-md border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Change</div>
          <div
            className={`mt-1 font-mono text-lg font-semibold ${
              (parseCost(t.delta_monthly_cost ?? null) ?? 0) > 0
                ? "text-[var(--sg-op-destroy)]"
                : (parseCost(t.delta_monthly_cost ?? null) ?? 0) < 0
                  ? "text-[var(--sg-op-create)]"
                  : "text-[var(--sg-text)]"
            }`}
          >
            {signedMoney(t.delta_monthly_cost, currency)}/mo
          </div>
        </div>
        <div className="rounded-md border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] px-4 py-3">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Resources</div>
          <div className="mt-1 font-mono text-sm text-[var(--sg-text)]">
            {t.current_resource_count} → {t.planned_resource_count}
          </div>
        </div>
      </div>

      {/* Per-state */}
      {changedStates.length > 0 && (
        <div className="flex flex-col gap-2">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Per state</div>
          <div className="rounded-md border border-[var(--sg-border-light)] overflow-hidden">
            {changedStates.map((s) => (
              <div
                key={s.state_id}
                className="flex items-center justify-between gap-3 border-b border-[var(--sg-border-light)] px-3 py-2 last:border-b-0"
              >
                <span className="truncate text-sm text-[var(--sg-text)]">{s.state_name}</span>
                <span className="font-mono text-sm text-[var(--sg-text-muted)]">
                  {signedMoney(s.delta_monthly_cost, currency)}/mo
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

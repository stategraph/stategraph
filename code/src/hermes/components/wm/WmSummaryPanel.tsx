"use client";

import { StatusPill } from "@/components/status/StatusPill";
import type { Tone } from "@/components/status/tones";
import {
  RESOURCE_SUMMARY_SLOTS,
  summaryCountsLine,
  summaryResult,
  type ResourceSummary,
  type RunSummary,
  type SummaryResult,
  type SummaryRow,
} from "@/lib/wm/decode";

/** The tab a row's directory link opens. */
export type SummaryTarget = "changes" | "apply" | "steps";

const RESULT_TONE: Record<SummaryResult, Tone> = {
  failed: "error",
  pending: "neutral",
  "not run": "neutral",
  applied: "success",
  changes: "accent",
  "no changes": "neutral",
  success: "success",
};

const SLOT_CLASS: Record<keyof ResourceSummary, string> = {
  imported: "text-[var(--sg-accent)]",
  created: "text-[var(--sg-op-create)]",
  updated: "text-[var(--sg-op-update)]",
  replaced: "text-[var(--sg-op-update)]",
  deleted: "text-[var(--sg-op-destroy)]",
};

function target(row: SummaryRow): SummaryTarget | null {
  if (row.success === null) return null;
  if (row.op === "apply") return "apply";
  if (row.op === "plan") return "changes";
  return "steps";
}

/** "0 import, 3 create, 5 update, 1 replace, 2 delete", each count in its operation's
 *  color; an unreported slot renders `-`. */
export function ResourceTotalsLine({ totals }: { totals: ResourceSummary }) {
  return (
    <span className="font-mono">
      {RESOURCE_SUMMARY_SLOTS.map(([slot, label], i) => (
        <span key={slot}>
          {i > 0 && ", "}
          <span className={totals[slot] ? SLOT_CLASS[slot] : undefined}>
            {totals[slot] ?? "-"} {label}
          </span>
        </span>
      ))}
    </span>
  );
}

function CountCells({ summary, bold }: { summary: ResourceSummary | null; bold?: boolean }) {
  return (
    <>
      {RESOURCE_SUMMARY_SLOTS.map(([slot]) => {
        const n = summary?.[slot] ?? null;
        return (
          <td
            key={slot}
            className={`px-3 py-2 text-right font-mono ${bold ? "font-semibold" : ""} ${
              n ? SLOT_CLASS[slot] : "text-[var(--sg-text-dim)]"
            }`}
          >
            {n ?? "-"}
          </td>
        );
      })}
    </>
  );
}

/** The run's summary, as in the PR comment: a counts line, then one row per
 *  dirspace. An apply run shows the result column only. */
export function WmSummaryPanel({
  summary,
  isApply,
  live,
  onOpen,
}: {
  summary: RunSummary;
  isApply: boolean;
  live: boolean;
  onOpen: (tab: SummaryTarget, row: SummaryRow) => void;
}) {
  if (summary.rows.length === 0) {
    return <div className="p-8 text-sm text-[var(--sg-text-muted)]">No dirspaces in this run.</div>;
  }
  return (
    <div className="p-4 space-y-3">
      <div className="text-sm font-medium text-[var(--sg-text)]">{summaryCountsLine(summary, isApply, live)}</div>
      <div className="rounded-lg border border-[var(--sg-border)] overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-[var(--sg-bg-2)] text-[10px] uppercase tracking-wider text-[var(--sg-text-dim)]">
            <tr className="border-b border-[var(--sg-border)]">
              <th className="px-3 py-2 text-left font-medium">Directory</th>
              <th className="px-3 py-2 text-left font-medium">Workspace</th>
              <th className="px-3 py-2 text-left font-medium">Result</th>
              {!isApply &&
                RESOURCE_SUMMARY_SLOTS.map(([slot, label]) => (
                  <th key={slot} className="px-3 py-2 text-right font-medium">
                    {label}
                  </th>
                ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-[var(--sg-border-light)]">
            {summary.rows.map((r) => {
              const result = summaryResult(r, live);
              const tab = target(r);
              return (
                <tr key={`${r.dir}|${r.workspace}`}>
                  <td className="px-3 py-2 font-mono text-xs text-[var(--sg-text)]">
                    {tab ? (
                      <button
                        onClick={() => onOpen(tab, r)}
                        className="hover:text-[var(--sg-accent)] hover:underline text-left"
                      >
                        {r.dir || "."}
                      </button>
                    ) : (
                      r.dir || "."
                    )}
                  </td>
                  <td className="px-3 py-2 font-mono text-xs text-[var(--sg-text)]">{r.workspace}</td>
                  <td className="px-3 py-2 whitespace-nowrap">
                    <StatusPill tone={RESULT_TONE[result]} label={result} ariaPrefix="Result" />
                  </td>
                  {!isApply && <CountCells summary={r.resources} />}
                </tr>
              );
            })}
          </tbody>
          {!isApply && (
            <tfoot className="border-t border-[var(--sg-border)] bg-[var(--sg-bg-2)]">
              <tr>
                <td colSpan={3} className="px-3 py-2 text-xs font-semibold text-[var(--sg-text)]">
                  Total
                </td>
                <CountCells summary={summary.totals} bold />
              </tr>
            </tfoot>
          )}
        </table>
      </div>
    </div>
  );
}

"use client";

import { CheckCircle2, Clock, ShieldCheck } from "lucide-react";
import { formatRelativeTime } from "@/lib/utils/time";
import { asText } from "@/lib/mql/providers";

export interface GateRow {
  name: string;
  dir: string;
  workspace: string;
  token: string;
  gate: Record<string, unknown> | null;
}
export interface ApprovalRow {
  approver: string;
  token: string;
  created_at: string;
}

function requiredTeams(gate: Record<string, unknown> | null): string[] {
  if (!gate) return [];
  const all = Array.isArray(gate.all_of) ? gate.all_of.map(asText) : [];
  const any = Array.isArray(gate.any_of) ? gate.any_of.map(asText) : [];
  return [...all, ...any].filter(Boolean);
}

/** Apply-gate visibility: which gates guard this run, who has approved, and
 *  which are still waiting. Terrateam gates are keyed by a per-gate token;
 *  approvals join back on that token. */
export function WmGatePanel({ gates, approvals }: { gates: GateRow[]; approvals: ApprovalRow[] }) {
  if (gates.length === 0) return null;
  const byToken = new Map<string, ApprovalRow[]>();
  for (const a of approvals) {
    const list = byToken.get(a.token) ?? [];
    list.push(a);
    byToken.set(a.token, list);
  }

  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
      <div className="px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-sm flex items-center gap-2">
        <ShieldCheck className="w-4 h-4 text-[var(--sg-text-muted)]" />
        <span className="text-[var(--sg-text)] font-medium">Approval gates</span>
      </div>
      <div className="divide-y divide-[var(--sg-border)]">
        {gates.map((g, i) => {
          const gateApprovals = byToken.get(g.token) ?? [];
          const approved = gateApprovals.length > 0;
          const teams = requiredTeams(g.gate);
          return (
            <div key={`${g.token}|${i}`} className="px-4 py-3 flex items-start gap-3">
              {approved ? (
                <CheckCircle2 className="w-4 h-4 mt-0.5 shrink-0 text-[var(--sg-success)]" />
              ) : (
                <Clock className="w-4 h-4 mt-0.5 shrink-0 text-[var(--sg-warning)]" />
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 flex-wrap text-sm">
                  <span className="font-mono text-[var(--sg-text)]">{g.name || "gate"}</span>
                  <span className="text-xs text-[var(--sg-text-muted)]">
                    {g.dir || "."} · {g.workspace}
                  </span>
                  {teams.length > 0 && (
                    <span className="text-xs text-[var(--sg-text-dim)]">
                      requires {teams.join(", ")}
                    </span>
                  )}
                </div>
                {approved ? (
                  <div className="mt-1 text-xs text-[var(--sg-success)]">
                    Approved by{" "}
                    {gateApprovals.map((a, j) => (
                      <span key={`${a.approver}|${j}`}>
                        {j > 0 ? ", " : ""}
                        <strong className="text-[var(--sg-text)]">{a.approver}</strong>{" "}
                        <span className="text-[var(--sg-text-muted)]" title={a.created_at}>
                          {formatRelativeTime(a.created_at)}
                        </span>
                      </span>
                    ))}
                  </div>
                ) : (
                  <div className="mt-1 text-xs text-[var(--sg-warning)]">
                    Waiting for approval
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

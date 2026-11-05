"use client";

import type { TxPlanOperation } from "@/lib/api/client";
import { OP_CLASS, opGlyphLabel } from "@/lib/plan/op-meta";
import { PlanOutput } from "./PlanOutput";

interface PlanTextViewProps {
  planOperations: TxPlanOperation[];
  /** tofu's plan text, when captured; otherwise the operations stand in. */
  planStdout?: string | null;
}

// Terraform/OpenTofu's stdout includes a long "Refreshing state…" preamble
// and a trailing "Saved the plan to…" footer. Users care about the actual
// plan body: from "OpenTofu/Terraform will perform the following actions:"
// through the "Plan: N to add…" summary line. Strip the rest; on a stdout
// shape we don't recognise (no banner, no summary), fall back to the full
// text rather than swallowing something useful.
export function trimPlanStdout(text: string): string {
  const lines = text.split("\n");
  const startIdx = lines.findIndex((l) =>
    /(OpenTofu|Terraform) will perform the following actions/.test(l),
  );
  const endIdx = lines.findIndex((l) => /^Plan:\s+\d+\s+to add/.test(l));
  if (startIdx === -1 || endIdx === -1 || endIdx < startIdx) return text;
  return lines.slice(startIdx, endIdx + 1).join("\n");
}

export function PlanTextView({ planOperations, planStdout }: PlanTextViewProps) {
  if (planStdout) {
    return <PlanOutput text={trimPlanStdout(planStdout)} />;
  }

  const ops = planOperations;
  if (ops.length === 0) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        No plan output yet. Run <code className="font-mono">stategraph tf plan</code> to
        populate this view.
      </div>
    );
  }

  return (
    <div className="p-4">
      <p className="text-xs text-[var(--sg-text-muted)] mb-3">
        Showing the derived operation summary; the server does not capture the full
        terraform plan text.
      </p>
      <ul className="text-xs leading-relaxed font-mono text-[var(--sg-text)] list-none">
        {ops.map((op, i) => (
          <li key={`${op.address}:${i}`} className="flex gap-3">
            <span className={`w-24 shrink-0 ${OP_CLASS[op.operation]}`}>
              {opGlyphLabel(op.operation)}
            </span>
            <span className="text-[var(--sg-text)]">{op.address}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

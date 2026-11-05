"use client";

import { AlertTriangle } from "lucide-react";
import type { TxDetailResponse } from "@/lib/api/client";
import { failureLabel, failureOutputText, type TxOutput } from "@/lib/tx/output";
import { PlanOutput } from "./PlanOutput";

interface PlanApplyViewProps {
  detail: TxDetailResponse;
  /** The apply's output as loaded by `loadTxOutput`; null when none is stored. */
  applyOutput: TxOutput | null;
}

const EMPTY_MESSAGES: Record<string, string> = {
  committed: "No apply output captured for this transaction.",
  committing: "Apply is in progress. Output will appear when the apply finishes.",
  failed: "Apply failed before output was captured.",
};
const DEFAULT_EMPTY_MESSAGE =
  "This transaction hasn't been applied yet. Run stategraph apply to populate this view.";

export function PlanApplyView({ detail, applyOutput }: PlanApplyViewProps) {
  if (applyOutput?.kind === "apply_stdout") {
    return <PlanOutput text={applyOutput.text} />;
  }
  if (applyOutput?.kind === "run_failure") {
    const text = failureOutputText(applyOutput.failure);
    return (
      <div>
        <div className="mx-4 mt-4 flex items-center gap-2 text-xs font-medium text-[var(--sg-error)]">
          <AlertTriangle className="w-3.5 h-3.5" />
          <span>{failureLabel(applyOutput.failure)}</span>
        </div>
        {text ? (
          <PlanOutput text={text} />
        ) : (
          <pre className="m-4 p-3 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-xs font-mono text-[var(--sg-text)] whitespace-pre-wrap overflow-x-auto">
            {JSON.stringify(applyOutput.failure.reason, null, 2)}
          </pre>
        )}
      </div>
    );
  }

  const message = EMPTY_MESSAGES[detail.tx.state] ?? DEFAULT_EMPTY_MESSAGE;

  return (
    <div className="p-8 text-sm text-[var(--sg-text-muted)]">{message}</div>
  );
}

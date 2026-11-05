"use client";

import { AlertTriangle } from "lucide-react";
import type { PlanTab } from "@/components/plans/PlanTabs";
import { failureLabel, failureOutputText, outputTail, type TxOutput } from "@/lib/tx/output";

interface FailedRunHintProps {
  /** The apply's output as loaded by `loadTxOutput`; null when none is stored. */
  applyOutput: TxOutput | null;
  onJumpToTab: (tab: PlanTab) => void;
}

// Show the trailing lines instead of dumping the whole output into the
// header; a tofu apply error block is routinely 8 to 15 lines.
const TAIL_LINES = 16;

export function FailedRunHint({ applyOutput, onJumpToTab }: FailedRunHintProps) {
  // A failed apply stores its failure record, whose reason carries tofu's
  // output when the failure happened inside terraform; an apply that finished
  // before the run was failed for another reason stored its stdout.
  const source =
    applyOutput?.kind === "apply_stdout"
      ? applyOutput.text
      : applyOutput?.kind === "run_failure"
        ? failureOutputText(applyOutput.failure)
        : null;
  const title =
    applyOutput?.kind === "run_failure" ? failureLabel(applyOutput.failure) : "Run failed";
  if (!source) {
    return (
      <div className="mt-3 flex items-start gap-2 px-3 py-2 rounded border border-[var(--sg-error)] bg-[var(--sg-error-bg)] text-[var(--sg-error)] text-xs">
        <AlertTriangle className="w-3.5 h-3.5 mt-[1px] shrink-0" />
        <span>{title} — no output was captured.</span>
      </div>
    );
  }
  const { snippet, truncated } = outputTail(source, TAIL_LINES);
  return (
    <div className="mt-3 rounded border border-[var(--sg-error)] bg-[var(--sg-error-bg)]">
      <div className="flex items-center gap-2 px-3 py-1.5 text-[var(--sg-error)] text-xs font-medium">
        <AlertTriangle className="w-3.5 h-3.5" />
        <span>
          {title} — {truncated ? `last ${TAIL_LINES} lines of output` : "output"}
        </span>
        <button
          type="button"
          onClick={() => onJumpToTab("apply")}
          className="ml-auto underline hover:no-underline cursor-pointer"
        >
          {truncated ? "View full output →" : "Switch to Apply tab →"}
        </button>
      </div>
      <pre className="px-3 pb-2 text-xs font-mono text-[var(--sg-text)] whitespace-pre-wrap overflow-x-auto">
        {snippet}
      </pre>
    </div>
  );
}

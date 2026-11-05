"use client";

import { PlanOutput } from "@/components/plans";
import { FormattedOutput } from "./FormattedOutput";
import { OutputSizeGuard, type ExpandOutput } from "./OutputSizeGuard";
import {
  isPlanStep,
  planDiff,
  scopeDir,
  scopeWorkspace,
  stepLabel,
  stepText,
  type RawStep,
} from "@/lib/wm/decode";
import { outputFilename } from "@/lib/wm/download";
import { parseOutputFormat } from "@/lib/wm/outputFormat";

export interface DownloadContext {
  repo: string;
  pullNumber?: string;
  runType?: string;
}

interface StepOutputViewProps {
  step: RawStep;
  downloadContext: DownloadContext;
  onExpand?: ExpandOutput;
}

const AUTH_STEPS = new Set(["auth/update-terrateam-github-token", "auth/oidc"]);

/** One step's output. A plan step carries both halves of the operation —
 *  the engine's diff in `payload.plan` and the plan command's stdout in
 *  `payload.text` — shown as two blocks; every other step renders its text
 *  per the payload's declared format. */
export function StepOutputView({ step, downloadContext, onExpand }: StepOutputViewProps) {
  const payload = step.payload;
  const diff = isPlanStep(step.step) ? planDiff(payload) : "";
  const text = stepText(payload);
  const scopeLabel = `${scopeDir(step.scope) || "run"}:${scopeWorkspace(step.scope) || "hooks"}`;
  const title = `${stepLabel(step.step)} · ${scopeLabel}`;
  const downloadName = (suffix: string) =>
    outputFilename({ ...downloadContext, step: `${step.step}${suffix}` });

  if (!diff && !text) {
    if (AUTH_STEPS.has(step.step)) {
      return (
        <div className="mt-2 text-xs italic text-[var(--sg-text-dim)]">
          {step.success === false ? "Authentication step failed" : "Authentication step completed"}
        </div>
      );
    }
    return <div className="mt-2 text-xs text-[var(--sg-text-dim)]">No output for this step.</div>;
  }

  return (
    <div className="mt-2 space-y-3">
      {diff && (
        <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
          <div className="px-3 pt-2 text-xs text-[var(--sg-text-dim)]">
            Diff <span className="font-mono">(engine.diff)</span>
          </div>
          <OutputSizeGuard
            content={diff}
            title={`${title} diff`}
            downloadName={downloadName("_diff")}
            onExpand={onExpand}
          >
            {(t) => <PlanOutput text={t} className="m-0 border-0 shadow-none" copyable={false} />}
          </OutputSizeGuard>
        </div>
      )}
      {text && (
        <div className="rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
          {diff && (
            <div className="px-3 pt-2 text-xs text-[var(--sg-text-dim)]">
              Plan output <span className="font-mono">(engine.plan)</span>
            </div>
          )}
          <OutputSizeGuard content={text} title={title} downloadName={downloadName("")} onExpand={onExpand}>
            {(t) => <FormattedOutput text={t} format={parseOutputFormat(payload?.format)} />}
          </OutputSizeGuard>
        </div>
      )}
    </div>
  );
}

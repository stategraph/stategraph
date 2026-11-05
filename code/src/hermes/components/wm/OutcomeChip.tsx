import type { Outcome } from "@/lib/wm/decode";
import { StatusPill } from "@/components/status/StatusPill";
import { OUTCOME_TONE } from "@/components/status/tones";

export const OUTCOME_LABEL: Record<Outcome, string> = {
  succeeded: "Succeeded",
  failed: "Failed",
  running: "Running",
  queued: "Queued",
  aborted: "Aborted",
  unknown: "Unknown",
};

/** The user-facing outcome of a Terrateam run, folded by lib/wm/decode's
 *  runOutcome / runOutcomeFromSuccess / runListOutcome, in the shared status
 *  palette. An unknown outcome is labeled with the raw lifecycle state when
 *  the caller has one, so it never reads as success nor renders empty. */
export function OutcomeChip({ outcome, rawState }: { outcome: Outcome; rawState?: string }) {
  const label = outcome === "unknown" ? rawState || OUTCOME_LABEL.unknown : OUTCOME_LABEL[outcome];
  return <StatusPill tone={OUTCOME_TONE[outcome]} label={label} ariaPrefix="Run state" />;
}

import {
  RUN_STATE_TONE,
  STACK_STATE_TONE,
  TONE_CLASS,
  TX_STATE_TONE,
  toneOf,
  type Tone,
} from "@/components/status/tones";

// Three vocabularies land here. Engine TRANSACTION states (open … aborted),
// work-manifest RUN states (queued | running | completed | aborted, from
// Terrat_work_manifest3.State), and STACK states (the terrateam `stack-state`
// enum, derived per dirspace and rolled up by the Stacks tab). Only `aborted`
// is shared between the first two, and it means the same thing in both; the
// stack names are disjoint from both, so no entry is ambiguous. Before the run
// states were listed, every orchestration row fell through to the `aborted`
// gray, so a queued run and a finished one were the same flat badge. NB a run
// state cannot express success or failure — that lives in the step outputs
// (lib/wm/decode runOutcome) — so the most this can say is in-flight versus
// finished. Stack states DO carry outcome, because the engine has already
// folded the plan/apply result into them. Colors come from the shared tone
// palette (components/status/tones), one map per vocabulary, merged here.
const STATE_CHIP_TONE: Record<string, Tone> = {
  ...TX_STATE_TONE,
  ...RUN_STATE_TONE,
  ...STACK_STATE_TONE,
};

// Canonical user-facing labels. Backend state names are abstract — "open"
// doesn't tell anyone the plan is sitting waiting for them. Map to verbs
// that describe what the run is actually doing (or waiting for).
const STATE_CHIP_LABEL: Record<string, string> = {
  open: "Planned",
  previewing: "Planning",
  committing: "Applying",
  committed: "Applied",
  failed: "Failed",
  aborted: "Aborted",
  queued: "Queued",
  running: "Running",
  completed: "Completed",
  plan_failed: "Plan failed",
  plan_pending: "Plan pending",
  apply_failed: "Apply failed",
  apply_pending: "Apply pending",
  apply_ready: "Apply ready",
  apply_success: "Applied",
  no_changes: "No changes",
};

interface StateChipProps {
  state: string;
  /** Override the default label for specific states when a caller needs a
   *  different vocabulary in context. */
  relabel?: Record<string, string>;
  /** What the screen reader calls this kind of state. Defaults to the run
   *  vocabulary, which is what every caller but the Stacks tab shows. */
  ariaPrefix?: string;
}

/** An unknown state renders as a visible neutral badge with its raw name. */
export function StateChip({ state, relabel, ariaPrefix = "Run state" }: StateChipProps) {
  const label = relabel?.[state] ?? STATE_CHIP_LABEL[state] ?? state;
  const cls = TONE_CLASS[toneOf(STATE_CHIP_TONE, state)];
  return (
    <span
      role="status"
      aria-label={`${ariaPrefix}: ${label}`}
      className={`inline-block px-2 py-0.5 text-[10px] uppercase tracking-wide font-medium rounded border ${cls}`}
    >
      {label}
    </span>
  );
}

// The single source of truth for status-badge colors, extracted from the
// Stacks chip (the agreed anchor) so every run/stack/workspace/PR badge in the
// console draws from one palette: green = success/applied, red = failure,
// amber = pending/queued, accent = actively running / ready, neutral =
// no-changes and anything unknown. Pure data + pure maps — no React — so the
// domain mappings are unit-testable.

import type { Outcome, StepStatus } from "@/lib/wm/decode";

export type Tone = "success" | "error" | "warning" | "accent" | "neutral";

export const TONE_CLASS: Record<Tone, string> = {
  success: "bg-[var(--sg-success-bg)] text-[var(--sg-success)] border-[var(--sg-success)]",
  error: "bg-[var(--sg-error-bg)] text-[var(--sg-error)] border-[var(--sg-error)]",
  warning: "bg-[var(--sg-warning-bg)] text-[var(--sg-warning)] border-[var(--sg-warning)]",
  accent: "bg-[var(--sg-accent-bg)] text-[var(--sg-accent)] border-[var(--sg-accent)]",
  neutral: "bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border-[var(--sg-border)]",
};

/** Stack states (the 7-value `stack-state` enum). The anchor mapping. */
export const STACK_STATE_TONE: Record<string, Tone> = {
  plan_failed: "error",
  apply_failed: "error",
  plan_pending: "warning",
  apply_pending: "warning",
  apply_ready: "accent",
  apply_success: "success",
  no_changes: "neutral",
};

/** Folded run outcomes (lib/wm/decode's `Outcome`): what a work manifest
 *  actually did, not its lifecycle state. Rendered by OutcomeChip, which also
 *  owns the labels. */
export const OUTCOME_TONE: Record<Outcome, Tone> = {
  succeeded: "success",
  failed: "error",
  running: "accent",
  queued: "warning",
  aborted: "neutral",
  unknown: "neutral",
};

/** Workflow step statuses on the run page. A failure the step marked
 *  ignore_errors did not fail the run, so it is amber, never red. */
export const STEP_STATUS_TONE: Record<StepStatus, Tone> = {
  success: "success",
  failure: "error",
  ignored: "warning",
};

/** Stategraph transaction states (State Changes / runs detail). */
export const TX_STATE_TONE: Record<string, Tone> = {
  open: "accent",
  previewing: "accent",
  committing: "warning",
  committed: "success",
  failed: "error",
  aborted: "neutral",
};

/** Work-manifest lifecycle states (queued/running/completed/aborted). A
 *  lifecycle state carries no outcome, so only in-flight stands out; lists
 *  that know the outcome fold it first and use {@link OUTCOME_TONE}. */
export const RUN_STATE_TONE: Record<string, Tone> = {
  queued: "neutral",
  running: "accent",
  completed: "neutral",
  aborted: "neutral",
};

/** VCS pull-request states. `merged` is the success terminal; a closed-
 *  unmerged PR is a non-event, not a failure. */
export const PR_STATE_TONE: Record<string, Tone> = {
  open: "accent",
  merged: "success",
  closed: "neutral",
};

/** Tone lookup with the mandated fallback: unknown states stay VISIBLE as a
 *  neutral badge (never dropped, never dressed up as something else). */
export const toneOf = (map: Record<string, Tone>, state: string): Tone =>
  map[state] ?? "neutral";

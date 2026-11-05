import type { Transaction } from "@/lib/api/client";

// `previewing` = terraform plan is executing right now.
// `committing` = terraform apply is executing right now.
// Use this for live-poll decisions — these are the states where the server
// will produce new data without user action.
export const RUNNING_STATES = new Set(["previewing", "committing"]);

// `open` = plan landed, sitting waiting for the user to kick off apply.
// Nothing is running on the backend; surfacing this as a separate signal
// from RUNNING_STATES keeps the UX honest about who needs to act next.
export const AWAITING_STATES = new Set(["open"]);

export function isRunning(tx: Transaction): boolean {
  return RUNNING_STATES.has(tx.state);
}

export function isAwaitingApply(tx: Transaction): boolean {
  return AWAITING_STATES.has(tx.state);
}

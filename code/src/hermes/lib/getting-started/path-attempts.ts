/* How many times this browser tab has picked a getting-started path. The count
   rides on getting_started_path_selected, so a user sent back to the path
   selector shows up as attempt 2, 3, and so on. Per tab: sessionStorage
   survives the full-page trips to GitHub and back, and a new tab starts at 1. */

const KEY = "stategraph-getting-started-path-attempts";

export interface CounterStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

function sessionStore(): CounterStore | null {
  if (typeof window === "undefined") return null;
  try {
    return window.sessionStorage;
  } catch {
    return null;
  }
}

/** Count one more path selection and return its number, starting at 1. */
export function nextPathSelectionAttempt(store: CounterStore | null = sessionStore()): number {
  if (!store) return 1;
  try {
    const previous = Number.parseInt(store.getItem(KEY) ?? "0", 10);
    const attempt = (Number.isFinite(previous) && previous > 0 ? previous : 0) + 1;
    store.setItem(KEY, String(attempt));
    return attempt;
  } catch {
    return 1;
  }
}

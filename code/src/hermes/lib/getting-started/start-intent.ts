import { ORCHESTRATION_SETUP_HREF, STATE_SETUP_HREF } from "./setup-progress";

/** The product a website Start button names on the landing URL, `?start=`. */
export type StartIntent = "orchestration" | "iaad";

export const START_INTENT_PARAM = "start";

const KEY = "stategraph-start-intent";

type IntentStore = Pick<Storage, "getItem" | "setItem" | "removeItem">;

function sessionStore(): IntentStore | null {
  if (typeof window === "undefined") return null;
  try {
    return window.sessionStorage;
  } catch {
    return null;
  }
}

export function parseStartIntent(value: string | null | undefined): StartIntent | null {
  return value === "iaad" || value === "orchestration" ? value : null;
}

/** Keep the intent across the redirects that follow the landing, for this tab only. */
export function stashStartIntent(value: string | null | undefined, store = sessionStore()): void {
  const intent = parseStartIntent(value);
  if (!intent || !store) return;
  try {
    store.setItem(KEY, intent);
  } catch {
    // Unavailable or full: the intent lives in the URL for this hop only.
  }
}

export function readStartIntent(store = sessionStore()): StartIntent | null {
  if (!store) return null;
  try {
    return parseStartIntent(store.getItem(KEY));
  } catch {
    return null;
  }
}

export function clearStartIntent(store = sessionStore()): void {
  if (!store) return;
  try {
    store.removeItem(KEY);
  } catch {
    // Nothing to clear.
  }
}

/** Where a new tenant's first run starts: the state wizard for `iaad`, orchestration otherwise. */
export function setupDestination(intent: StartIntent | null): string {
  return intent === "iaad" ? STATE_SETUP_HREF : ORCHESTRATION_SETUP_HREF;
}

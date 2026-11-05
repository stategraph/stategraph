const KEY_PREFIX = "stategraph-first-run-seen:";

interface StoreLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

function localStore(): StoreLike | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

/** Whether first-run setup (the redirect into setup and the Home welcome panel) applies on this
 *  server: always in COMMUNISM mode, otherwise when the server reports orchestration enabled.
 *  `null` until the mode and, outside COMMUNISM mode, the orchestration capability have loaded. */
export function firstRunSetupEnabled(args: {
  modeLoading: boolean;
  mode: string | undefined;
  orchestrationEnabled: boolean | null;
}): boolean | null {
  if (args.modeLoading) return null;
  if (args.mode === "COMMUNISM") return true;
  return args.orchestrationEnabled;
}

/** Whether this browser was already sent into setup for the tenant. */
export function hasSeenFirstRun(tenantId: string, store: StoreLike | null = localStore()): boolean {
  if (!store) return false;
  try {
    return store.getItem(KEY_PREFIX + tenantId) === "1";
  } catch {
    return false;
  }
}

export function markFirstRunSeen(tenantId: string, store: StoreLike | null = localStore()): void {
  if (!store) return;
  try {
    store.setItem(KEY_PREFIX + tenantId, "1");
  } catch {
    // Unavailable or full: the next load sends the user into setup once more.
  }
}

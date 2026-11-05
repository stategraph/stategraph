import { getCapabilities, type Capabilities } from "./client";

/* The server capability envelope, shared by every consumer of useCapabilities.
   Kept out of the hook (and away from React) so the caching rule is testable;
   named apart from ./capabilities, which reads the session's capabilities. */

let cache: Capabilities | null = null;
let inflight: Promise<Capabilities> | null = null;

/** The successful response, once one has arrived; null until then. */
export function cachedServerCapabilities(): Capabilities | null {
  return cache;
}

/**
 * The envelope: the cached success, else the in-flight request, else a new
 * one. A failure rejects every waiter and is not cached, so the next load
 * sends a new request.
 */
export function fetchServerCapabilities(): Promise<Capabilities> {
  if (cache !== null) return Promise.resolve(cache);
  if (inflight) return inflight;
  /* A refresh replaces `inflight`, so a request that is no longer the current
     one touches neither the cache nor the slot: without the check a slow early
     request can overwrite a newer envelope, or its rejection can clear a newer
     request's slot. */
  const p: Promise<Capabilities> = getCapabilities().then(
    (res) => {
      if (inflight === p) cache = res;
      return res;
    },
    (error: unknown) => {
      if (inflight === p) inflight = null;
      throw error;
    },
  );
  inflight = p;
  return p;
}

/**
 * Discard the cache and fetch again. The github_app fields change while the
 * server runs, so a consumer that watches them refreshes here rather than
 * keeping a copy the other consumers never see.
 */
export function refreshServerCapabilities(): Promise<Capabilities> {
  cache = null;
  inflight = null;
  return fetchServerCapabilities();
}

/** The envelope, with a failure resolved to everything-disabled. */
export function loadServerCapabilities(): Promise<Capabilities> {
  return fetchServerCapabilities().catch(() => ({
    costs: { enabled: false },
    dedicated: { enabled: false },
    github_app: { configured: false, creatable: false, ready: false },
    orchestration: { enabled: false },
    security: { enabled: false },
  }));
}

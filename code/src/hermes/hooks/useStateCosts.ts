"use client";

import { useEffect, useState } from "react";

import { type StateCosts } from "@/lib/api/client";
import { fetchStateCost } from "@/lib/cost/stateCost";

/**
 * Per-state cost fetch with a module-level cache keyed by state id. The same
 * tenant page can render the modules grid, open InstanceInspector for several
 * instances in succession, and walk back to the modules grid -- each surface
 * needs the same {@link getStateCosts} payload, and naively letting every
 * component fetch produces N copies of the same request.
 *
 * The cache stores resolved payloads only; in-flight promises share a single
 * fetch so concurrent first-mounts coalesce. A 404 (or any other error) is
 * NOT cached, so a state that hasn't been priced yet retries on the next
 * mount.
 *
 * The cache deliberately has no eviction. State cost payloads are bounded
 * (one per state) and a SPA reload clears them; if that ever becomes a
 * memory issue, swap in an LRU keyed by id.
 */

const cache = new Map<string, StateCosts>();
const inflight = new Map<string, Promise<StateCosts>>();

function fetchOnce(stateId: string): Promise<StateCosts> {
  const cached = cache.get(stateId);
  if (cached) return Promise.resolve(cached);
  const live = inflight.get(stateId);
  if (live) return live;
  const p = fetchStateCost(stateId)
    .then((res) => {
      cache.set(stateId, res);
      inflight.delete(stateId);
      return res;
    })
    .catch((err) => {
      inflight.delete(stateId);
      throw err;
    });
  inflight.set(stateId, p);
  return p;
}

interface UseStateCostsResult {
  costs: StateCosts | null;
  isLoading: boolean;
  error: string | null;
}

interface Settled {
  id: string;
  /** The cache holds successes; this holds error outcomes so the consumer can
   *  surface them without a re-fetch (until the dep changes). */
  error: string | null;
}

/**
 * Fetch the latest priced snapshot for {@link stateId}. Returns `null` until
 * the first fetch resolves. Passing `null` / `undefined` parks the hook (no
 * fetch, no error) so callers don't have to gate the call themselves.
 *
 * Cache hits are returned at render time -- the effect never calls setState
 * synchronously; setState only fires after the asynchronous fetch settles.
 */
export function useStateCosts(stateId: string | null | undefined): UseStateCostsResult {
  const cached = stateId ? cache.get(stateId) ?? null : null;
  const [settled, setSettled] = useState<Settled | null>(null);
  // Bump on every successful resolve so the cache hit re-evaluates on the
  // next render even though `cache` itself isn't reactive.
  const [, setRevision] = useState(0);

  useEffect(() => {
    if (!stateId) return;
    if (cache.has(stateId)) return;
    let cancelled = false;
    fetchOnce(stateId)
      .then(() => {
        if (cancelled) return;
        setSettled({ id: stateId, error: null });
        setRevision((r) => r + 1);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setSettled({
          id: stateId,
          error: err instanceof Error ? err.message : "Failed to load state costs",
        });
      });
    return () => {
      cancelled = true;
    };
  }, [stateId]);

  if (!stateId) {
    return { costs: null, isLoading: false, error: null };
  }
  if (cached) {
    return { costs: cached, isLoading: false, error: null };
  }
  const fresh = settled !== null && settled.id === stateId;
  return {
    costs: null,
    isLoading: !fresh,
    error: fresh ? settled.error : null,
  };
}

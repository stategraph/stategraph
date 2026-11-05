"use client";

import { useEffect } from "react";

/**
 * Reflect the state currently being viewed (e.g. a States detail/inspect page,
 * keyed off its `?id=` param) into the sticky `state` deep-link param,
 * overriding any stale value carried in from a previous page.
 *
 * This keeps the same state selected when navigating onward (e.g. to Graph
 * Explorer / Blast Radius), where `DeepLink` / `useDeepLinkRouter` forward
 * `?state=`.
 *
 * Uses `history.replaceState` (no navigation); Next.js syncs this with
 * `useSearchParams`, so sidebar links pick up the new value immediately.
 */
export function usePublishSelectedState(stateId: string): void {
  useEffect(() => {
    if (!stateId || typeof window === "undefined") return;
    const url = new URL(window.location.href);
    if (url.searchParams.get("state") !== stateId) {
      url.searchParams.set("state", stateId);
      window.history.replaceState(null, "", url.pathname + url.search);
    }
  }, [stateId]);
}

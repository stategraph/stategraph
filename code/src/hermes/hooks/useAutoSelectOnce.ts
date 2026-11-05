"use client";

import { useEffect, useRef } from "react";

/**
 * Run an "auto-select" effect exactly once after a set of preconditions has
 * resolved. The effect is intentionally one-shot: once {@link compute} has been
 * invoked, subsequent renders short-circuit even if the dependency array
 * thrashes, so user-driven selections after the first auto-pick aren't
 * overwritten by a late-arriving fetch.
 *
 * `compute` is called inside a {@link useEffect} body and may call its
 * surrounding component's setters. Returning `false` from `compute` indicates
 * "preconditions still resolving, try again on the next render"; returning
 * `true` or `undefined` marks the hook as fired and freezes it.
 *
 * Typical use:
 *
 * ```ts
 * useAutoSelectOnce(
 *   () => {
 *     if (statesLoading || statesWithCosts.length === 0) return false;
 *     const pinned = new URLSearchParams(location.search).get("state");
 *     if (pinned && states.some(s => s.id === pinned)) return true;
 *     const recent = pickMostRecent(statesWithCosts);
 *     if (recent) setSelectedStateId(recent.id);
 *     return true;
 *   },
 *   [statesLoading, statesWithCosts, states]
 * );
 * ```
 */
export function useAutoSelectOnce(
  compute: () => boolean | void,
  deps: React.DependencyList
): void {
  const firedRef = useRef(false);
  useEffect(() => {
    if (firedRef.current) return;
    const settled = compute();
    if (settled !== false) firedRef.current = true;
    // The effect body's dep list is what the caller passes in; we trust them
    // to enumerate every value `compute` closes over.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
}

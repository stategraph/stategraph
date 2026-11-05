"use client";

import { useCallback, useState } from "react";

/**
 * What a changed URL value means to a hook that also writes it: the router
 * catching up with one of the hook's own writes (Next applies replaceState to
 * useSearchParams in a transition, so a typed "ab" can first come back as
 * "a"), or a change from outside, such as a client navigation to the same page
 * with another query, which the state must adopt.
 */
export function reconcileUrlValue<T>(
  pending: readonly T[],
  urlValue: T,
): { adopt: boolean; pending: T[] } {
  const own = pending.indexOf(urlValue);
  return own >= 0
    ? { adopt: false, pending: pending.slice(own + 1) }
    : { adopt: true, pending: [] };
}

/**
 * State initialised from a URL value that keeps following it. A client
 * navigation keeps the page mounted, so reading the URL once would leave the
 * state stale; an outside change is adopted, while the hook's own writes are
 * not echoed back. The setter must call `recordWrite` with the value as the
 * URL will read it each time it actually changes the URL.
 */
export function useUrlFollowingState<T>(
  urlValue: T,
): [T, (next: T) => void, (written: T) => void] {
  const [value, setValue] = useState<T>(urlValue);
  const [seen, setSeen] = useState<T>(urlValue);
  const [pending, setPending] = useState<T[]>([]);
  // Adjust during render when the URL value changes (React's
  // adjust-state-on-prop-change pattern, as in useStateSelection).
  if (urlValue !== seen) {
    setSeen(urlValue);
    const next = reconcileUrlValue(pending, urlValue);
    setPending(next.pending);
    if (next.adopt) setValue(urlValue);
  }
  const recordWrite = useCallback((written: T) => setPending((p) => [...p, written]), []);
  return [value, setValue, recordWrite];
}

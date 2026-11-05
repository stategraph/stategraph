"use client";

import { useEffect } from "react";

/**
 * Kick off a screen's initial fetch on mount.
 *
 * The fetch is deferred one tick through setTimeout so React StrictMode's
 * dev-only mount → unmount → remount runs the cleanup before the first timer
 * fires — one request instead of two identical ones. In production it is just
 * a one-tick delay. `load` must be referentially stable (a useCallback), or
 * every render re-triggers it.
 */
export function useInitialLoad(load: () => void | Promise<void>): void {
  useEffect(() => {
    const t = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(t);
  }, [load]);
}

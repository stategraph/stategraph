"use client";

import { useCallback, useEffect, useState } from "react";

import {
  getStateSecurityFindingsSummary,
  type SecurityFindingsSummary,
} from "@/lib/api/client";

interface UseStateSecurityFindingsResult {
  summary: SecurityFindingsSummary | null;
  isLoading: boolean;
  /** Re-fetch the summary (e.g. after an on-demand scan completes). The current
   *  summary is kept on screen until the new one arrives -- no loading flash. */
  refetch: () => void;
}

interface Settled {
  id: string;
  summary: SecurityFindingsSummary | null;
}

/**
 * Latest-scan findings summary for a single state, mirroring {@link useStateCosts}:
 * the State Details page uses it only to decide whether to surface a link to the
 * Findings page (a state whose scan reports `total > 0` gets the link, the rest a
 * disabled label).
 *
 * Passing `null` / `undefined` parks the hook (no fetch) so callers can gate on the
 * security capability the same way the cost link gates on pricing support. The
 * summary endpoint 404s for a never-scanned state; that -- and any other error --
 * resolves to `null` (treated as "no findings") rather than surfacing, matching the
 * Findings page's own handling.
 *
 * Loading is derived from whether the settled result belongs to the current
 * `stateId` (the {@link useStateCosts} trick), so switching states reports
 * `isLoading` synchronously and never flashes a stale "no findings". Unlike the
 * cost hook there is no shared cache: this is the only surface that needs the
 * per-state summary by id, so a plain per-mount fetch suffices.
 */
export function useStateSecurityFindings(
  stateId: string | null | undefined
): UseStateSecurityFindingsResult {
  const [settled, setSettled] = useState<Settled | null>(null);
  // Bumped by refetch() to re-run the effect without changing stateId.
  const [reloadKey, setReloadKey] = useState(0);
  const refetch = useCallback(() => setReloadKey((k) => k + 1), []);

  useEffect(() => {
    if (!stateId) return;
    let cancelled = false;
    getStateSecurityFindingsSummary(stateId)
      .then((res) => {
        if (!cancelled) setSettled({ id: stateId, summary: res });
      })
      .catch(() => {
        // 404 (never scanned) or any error -> treat as no findings.
        if (!cancelled) setSettled({ id: stateId, summary: null });
      });
    return () => {
      cancelled = true;
    };
  }, [stateId, reloadKey]);

  if (!stateId) {
    return { summary: null, isLoading: false, refetch };
  }
  const fresh = settled !== null && settled.id === stateId;
  return {
    summary: fresh ? settled.summary : null,
    isLoading: !fresh,
    refetch,
  };
}

"use client";

import { useMemo } from "react";

import { useStates } from "@/contexts";
import { CostRange } from "@/lib/cost/range";

import { useCostRange } from "./useCostRange";

/**
 * Cost-range selection for the tenant-wide cost pages (Overview, Explorer).
 *
 * A tenant's aggregate cost series begins when its earliest state was created —
 * by the backend's carry-forward rule a state contributes from its `created_at`
 * onward — so this auto-picks the initial period from that span via
 * {@link useCostRange}. An explicit `?range=` URL pin still wins. Returns the
 * same `[range, setRange]` tuple as {@link useCostRange}.
 */
export function useTenantCostRange(): [CostRange, (range: CostRange) => void] {
  const { states } = useStates();
  const seriesStart = useMemo(
    () =>
      states.length === 0
        ? null
        : states.reduce(
            (earliest, s) => (s.created_at < earliest ? s.created_at : earliest),
            states[0].created_at
          ),
    [states]
  );
  return useCostRange(seriesStart);
}

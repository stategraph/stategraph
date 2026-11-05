"use client";

import {
  autoRangeForSpan,
  CostRange,
  DEFAULT_COST_RANGE,
  isCostRange,
  spanDaysSince,
} from "@/lib/cost/range";

import { useAutoSelectOnce } from "./useAutoSelectOnce";
import { useUrlSyncedParam } from "./useUrlSyncedParam";

/**
 * URL-synced cost-range selection. Reads `?range=` on mount, falls back to
 * {@link DEFAULT_COST_RANGE}; the setter syncs back to the URL via
 * {@link useUrlSyncedParam}.
 *
 * When `seriesStart` is supplied — the ISO timestamp at which the cost series
 * begins, which by the backend's carry-forward rule is the earliest
 * contributing state's `created_at` — the period is auto-picked once from the
 * data span via {@link autoRangeForSpan}: a series under a week long selects
 * "Last 7 days", under a month "Last month", and so on. Pass `null` while the
 * start is still loading; the pick waits for it and then fires a single time,
 * so a later user choice is never overwritten. An explicit `?range=` pin in the
 * URL always wins and disables the auto-pick entirely.
 */
export function useCostRange(
  seriesStart?: string | null
): [CostRange, (range: CostRange) => void] {
  const [value, setValue] = useUrlSyncedParam("range", DEFAULT_COST_RANGE);
  const range: CostRange = isCostRange(value) ? value : DEFAULT_COST_RANGE;

  useAutoSelectOnce(
    () => {
      if (seriesStart === undefined || seriesStart === null) return false;
      const pinned =
        typeof window !== "undefined"
          ? new URLSearchParams(window.location.search).get("range")
          : null;
      if (pinned === null) {
        setValue(autoRangeForSpan(spanDaysSince(seriesStart, new Date())));
      }
      return true;
    },
    [seriesStart, setValue]
  );

  return [range, setValue];
}

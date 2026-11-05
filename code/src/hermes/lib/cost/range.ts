/**
 * Time-range choices shown in the cost-analysis range selector. Each id
 * maps to a `from`/`to` ISO-8601 window passed to
 * GET /api/v1/states/{id}/costs/history.
 *
 * The backend defaults `from` to "30 days ago" when omitted, so to render the
 * "Since oldest data" range we need to send an explicitly old `from`.
 */
export type CostRange = "7d" | "1m" | "1q" | "6m" | "1y" | "all";

export interface CostRangeOption {
  id: CostRange;
  label: string;
}

export const COST_RANGES: CostRangeOption[] = [
  { id: "7d", label: "Last 7 days" },
  { id: "1m", label: "Last month" },
  { id: "1q", label: "Last quarter" },
  { id: "6m", label: "Last 6 months" },
  { id: "1y", label: "Last year" },
  { id: "all", label: "Since oldest data" },
];

export const DEFAULT_COST_RANGE: CostRange = "1m";

/** Lower bound used for "since oldest data". */
const ALL_FROM_ISO = "2000-01-01T00:00:00Z";

const DAY_MS = 24 * 60 * 60 * 1000;

const RANGE_DAYS: Record<Exclude<CostRange, "all">, number> = {
  "7d": 7,
  "1m": 30,
  "1q": 90,
  "6m": 180,
  "1y": 365,
};

export function isCostRange(value: string | null | undefined): value is CostRange {
  return (
    value === "7d" ||
    value === "1m" ||
    value === "1q" ||
    value === "6m" ||
    value === "1y" ||
    value === "all"
  );
}

export function rangeToFromTo(
  range: CostRange,
  now: Date
): { from: string; to: string } {
  const to = now.toISOString();
  if (range === "all") {
    return { from: ALL_FROM_ISO, to };
  }
  const from = new Date(now.getTime() - RANGE_DAYS[range] * DAY_MS).toISOString();
  return { from, to };
}

/**
 * Day span between an ISO timestamp and `now`, floored at 0 (fractional days
 * preserved). Returns 0 for an unparseable timestamp. Used to size the
 * cost-history period to how much history a series actually covers.
 */
export function spanDaysSince(iso: string, now: Date): number {
  const start = new Date(iso).getTime();
  if (!Number.isFinite(start)) return 0;
  return Math.max(0, (now.getTime() - start) / DAY_MS);
}

/**
 * The smallest preset range whose window contains `spanDays` of data: under a
 * week selects "7d", under a month "1m", then "1q", "6m", "1y", and anything a
 * year or longer falls back to "all". The thresholds are each range's own
 * length, so the chosen window never clips a series shorter than the data it
 * holds.
 */
export function autoRangeForSpan(spanDays: number): CostRange {
  const ascending: Exclude<CostRange, "all">[] = ["7d", "1m", "1q", "6m", "1y"];
  for (const id of ascending) {
    if (spanDays < RANGE_DAYS[id]) return id;
  }
  return "all";
}

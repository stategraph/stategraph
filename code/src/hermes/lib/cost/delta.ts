/**
 * Period-over-period cost deltas computed from a history series.
 *
 * History points carry money as decimal strings (see lib/cost/format). The UI
 * compares the first vs the last *priced* point over the selected range to show
 * a trend (▲/▼) on KPIs and in the Cost Explorer pivot.
 */

import { parseCost } from "./format";

export interface CostDelta {
  /** Earliest priced value in the range, or null if < 2 priced points. */
  previous: number | null;
  /** Latest priced value in the range, or null if none priced. */
  current: number | null;
}

/**
 * First vs last priced value across an oldest-first history series.
 *
 * Reads `monthly_cost` by default; pass `getValue` to compare a different field
 * (e.g. `hourly_cost`). Unpriced (null/absent) points are skipped so the
 * comparison reflects two real data points. With fewer than two priced points
 * there is no meaningful delta, so `previous` is null.
 */
export function deltaOverRange<T extends { monthly_cost?: string | null }>(
  points: ReadonlyArray<T>,
  getValue: (point: T) => string | number | null | undefined = (point) => point.monthly_cost
): CostDelta {
  const priced: number[] = [];
  for (const point of points) {
    const v = parseCost(getValue(point));
    if (v !== null) priced.push(v);
  }
  if (priced.length === 0) return { previous: null, current: null };
  if (priced.length === 1) return { previous: null, current: priced[0] };
  return { previous: priced[0], current: priced[priced.length - 1] };
}

/** Absolute change `current - previous`, or null when not comparable. */
export function deltaAbsolute(d: CostDelta): number | null {
  if (d.current === null || d.previous === null) return null;
  return d.current - d.previous;
}

/** Percent change relative to `previous`, or null when not comparable / div-by-zero. */
export function deltaPercent(d: CostDelta): number | null {
  if (d.current === null || d.previous === null || d.previous === 0) return null;
  return ((d.current - d.previous) / d.previous) * 100;
}

interface GroupedPoint {
  groups?: ReadonlyArray<{ name: string; monthly_cost?: string | null }>;
}

/**
 * Pivot grouped history points (each point holds a per-group breakdown for that
 * day) into a first-vs-last monthly delta per group name. Used for the Cost
 * Overview "top movers" panel and the Cost Explorer pivot's Δ column.
 *
 * Note: a group that only appears partway through the window is compared across
 * the days it does appear, so a brand-new group understates its rise from zero.
 */
export function groupDeltasOverRange(points: ReadonlyArray<GroupedPoint>): Map<string, CostDelta> {
  const series = new Map<string, (string | null | undefined)[]>();
  for (const point of points) {
    for (const g of point.groups ?? []) {
      const arr = series.get(g.name);
      if (arr) arr.push(g.monthly_cost);
      else series.set(g.name, [g.monthly_cost]);
    }
  }
  const out = new Map<string, CostDelta>();
  for (const [name, values] of series) {
    out.set(name, deltaOverRange(values.map((v) => ({ monthly_cost: v ?? null }))));
  }
  return out;
}

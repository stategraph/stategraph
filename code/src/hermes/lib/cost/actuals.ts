/**
 * Helpers for the "actual" (FOCUS billing) basis of the cost pages.
 *
 * Actuals are billed facts summed over a charge-period window; estimates are
 * monthly projections. The two only compare honestly after normalising the
 * billed sum into a monthly run rate, and only when the window is long enough
 * for that rate to mean something. Everything here exists to enforce that
 * discipline in one place.
 */

import type { TenantCostAttribution } from "@/lib/api/client";
import { parseCost } from "@/lib/cost/format";

const MS_PER_DAY = 86_400_000;

/** Average Gregorian month, in days, for window -> monthly normalisation. */
export const DAYS_PER_MONTH = 30.4375;

/**
 * Minimum charge-period span (days) before a billed sum may be normalised
 * into a comparable monthly run rate. Below this, show the billed fact but no
 * estimate-vs-actual comparison -- extrapolating a few days of charges to a
 * month implies precision the data doesn't have.
 */
export const MIN_COMPARE_WINDOW_DAYS = 28;

/**
 * Day span of a charge-period window. `null` when either bound is missing or
 * unparseable, or when the window is inverted. A zero span is possible (a
 * single charge instant, or daily-grain lines without a charge_period_end)
 * and intentionally fails the {@link MIN_COMPARE_WINDOW_DAYS} gate.
 */
export function windowDays(
  windowStart: string | undefined,
  windowEnd: string | undefined
): number | null {
  if (!windowStart || !windowEnd) return null;
  const start = new Date(windowStart).getTime();
  const end = new Date(windowEnd).getTime();
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) return null;
  return (end - start) / MS_PER_DAY;
}

/**
 * Normalise a billed sum over its charge-period window into a monthly run
 * rate. `null` when the cost is unparseable or the window is missing or
 * shorter than {@link MIN_COMPARE_WINDOW_DAYS} -- callers must treat that as
 * "not comparable", never as zero.
 */
export function monthlyRunRate(
  billedCost: string | number | undefined | null,
  windowStart: string | undefined,
  windowEnd: string | undefined
): number | null {
  const cost = parseCost(billedCost);
  if (cost === null) return null;
  const days = windowDays(windowStart, windowEnd);
  if (days === null || days < MIN_COMPARE_WINDOW_DAYS) return null;
  return (cost / days) * DAYS_PER_MONTH;
}

/**
 * Currency for an attribution summary, mirroring `tenantCurrencyFor` on the
 * estimated side: the backend omits `currency` both when there are no billing
 * lines and when the lines span several currencies, and only the latter
 * should be badged as "mixed" (bare numbers, no symbol).
 */
export function attributionCurrencyFor(attribution: TenantCostAttribution | null): {
  currency: string;
  isMixedCurrency: boolean;
} {
  const hasBilledData = attribution !== null && attribution.line_count > 0;
  const isMixedCurrency = hasBilledData && attribution.currency === undefined;
  const currency = isMixedCurrency ? "" : (attribution?.currency ?? "USD");
  return { currency, isMixedCurrency };
}

/**
 * Where "bring this under management" leads: the gap-analysis import flow,
 * pre-filtered to the provider when exactly one has unmanaged spend. The one
 * place the unmanaged-spend -> import routing rule lives.
 */
export function gapAnalysisHref(attribution: TenantCostAttribution): string {
  const gapProviders = attribution.by_provider.filter((p) => p.unmanaged_count > 0);
  return gapProviders.length === 1
    ? `/gap-analysis?cloud=${encodeURIComponent(gapProviders[0].provider)}`
    : "/gap-analysis";
}

/**
 * Human label for a charge-period window, e.g. "May 12 – Jun 11". `null` when
 * either bound is missing or unparseable -- callers should omit the label
 * rather than show a partial window.
 */
export function formatWindow(
  windowStart: string | undefined,
  windowEnd: string | undefined
): string | null {
  if (!windowStart || !windowEnd) return null;
  const start = new Date(windowStart);
  const end = new Date(windowEnd);
  if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime())) return null;
  const fmt: Intl.DateTimeFormatOptions = { month: "short", day: "numeric" };
  return `${start.toLocaleDateString(undefined, fmt)} – ${end.toLocaleDateString(undefined, fmt)}`;
}

/**
 * Cost-display helpers shared by the cost-analysis page and its chart.
 *
 * The API serialises Postgres `numeric` cost columns as decimal strings
 * (e.g. "7.592000") to preserve sub-cent precision; the UI only needs a
 * float for layout, so coerce here and drop unparseable values.
 */

import type { TenantCosts } from "@/lib/api/client";

/**
 * Resolve the currency to feed into {@link formatCurrency} for a tenant
 * rollup, together with whether the rollup spans multiple currencies.
 *
 * The backend collapses {@link TenantCosts.currency} to `undefined` when its
 * states use mixed currencies (the totals are summed in numeric but the unit
 * is ambiguous), so the caller has to distinguish three cases:
 *
 *  - {@link TenantCosts.currency} present -> single-currency rollup.
 *  - Absent but the tenant has priced data (positive {@link priced_count} or a
 *    non-empty {@link monthly_cost} string) -> mixed-currency rollup; render
 *    bare numbers and badge the surface as "mixed".
 *  - Absent and no priced data -> nothing has ever been priced; fall back to
 *    `"USD"` so the empty-state KPI cards still have a sensible symbol.
 */
export function tenantCurrencyFor(rollup: TenantCosts | null): {
  currency: string;
  isMixedCurrency: boolean;
} {
  const hasPricedData =
    rollup !== null &&
    ((typeof rollup.monthly_cost === "string" && rollup.monthly_cost !== "") ||
      rollup.priced_count > 0);
  const isMixedCurrency =
    rollup !== null && rollup.currency === undefined && hasPricedData;
  const currency = isMixedCurrency ? "" : (rollup?.currency ?? "USD");
  return { currency, isMixedCurrency };
}

/**
 * Coerce an API cost value into a JS number, returning `null` if it can't
 * be parsed. Accepts the (current) string contract as well as plain numbers
 * to stay forward-compatible with any schema rework.
 */
export function parseCost(raw: string | number | undefined | null): number | null {
  if (raw == null) return null;
  const n = typeof raw === "number" ? raw : Number(raw);
  return Number.isFinite(n) ? n : null;
}

/**
 * Render `value` as a currency amount in the user's locale. Falls back to
 * `"<value> <currency>"` for unknown ISO codes that `Intl.NumberFormat`
 * rejects, so the UI degrades gracefully rather than throwing.
 *
 * Empty `currency` (e.g. when the backend reports a mixed-currency rollup --
 * the unit is genuinely ambiguous) renders the bare number with no symbol.
 * Callers that want to label the value as "mixed" should do so out-of-band
 * (a hint / badge), not by feeding "MIXED" as a currency code.
 */
export function formatCurrency(value: number, currency: string): string {
  if (!currency) return value.toFixed(2);
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency,
      maximumFractionDigits: 2,
    }).format(value);
  } catch {
    return `${value.toFixed(2)} ${currency}`;
  }
}

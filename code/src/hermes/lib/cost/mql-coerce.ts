/**
 * Coercion helpers for rows returned by MQL — the JSON shape is `unknown`
 * field-for-field, and every cost helper that calls MQL needs to massage it
 * into a typed payload. Centralising the coercers avoids drift if (e.g.) the
 * "string or number" semantics for `monthly_cost` ever change.
 */

export const str = (v: unknown): string => (typeof v === "string" ? v : "");

export const optStr = (v: unknown): string | null => (typeof v === "string" ? v : null);

export const num = (v: unknown): number => {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : Number.NaN;
  return Number.isFinite(n) ? n : 0;
};

/** [priced / total] as a 0..100 percentage. 100 when the state has no
 *  resources at all (avoids a divide-by-zero and matches how the backend
 *  computes coverage for empty snapshots). */
export function coveragePercent(resource_count: number, priced_count: number): number {
  if (resource_count === 0) return 100;
  return (priced_count / resource_count) * 100;
}

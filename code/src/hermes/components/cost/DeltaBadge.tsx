import { formatCurrency } from "@/lib/cost/format";

export interface DeltaBadgeProps {
  /** Latest value in the compared window. */
  current: number | null;
  /** Earlier value to compare against. */
  previous: number | null;
  currency: string;
  className?: string;
  /** Tooltip; defaults to the period-over-period reading. */
  title?: string;
}

/**
 * Renders a period-over-period change, e.g. `▲ +$120 (4.2%)`.
 *
 * Cost going UP is what deserves attention, so increases are amber
 * (`--sg-warning`) and decreases green (`--sg-success`) -- the opposite of the
 * usual red-bad/green-good convention. A neutral dash is shown when there's no
 * comparable prior value.
 */
export function DeltaBadge({ current, previous, currency, className, title }: DeltaBadgeProps) {
  if (current === null || previous === null) {
    return (
      <span className={`text-xs text-[var(--sg-text-dim)] ${className ?? ""}`}>—</span>
    );
  }

  const abs = current - previous;
  const pct = previous !== 0 ? (abs / previous) * 100 : null;
  const flat = abs === 0;
  const rising = abs > 0;

  const color = flat
    ? "var(--sg-text-muted)"
    : rising
      ? "var(--sg-warning)"
      : "var(--sg-success)";
  const arrow = flat ? "→" : rising ? "▲" : "▼";
  const sign = rising ? "+" : abs < 0 ? "−" : "";
  const magnitude = formatCurrency(Math.abs(abs), currency);
  const pctStr = pct === null ? "" : ` (${sign}${Math.abs(pct).toFixed(1)}%)`;

  return (
    <span
      className={`inline-flex items-center gap-1 text-xs font-mono ${className ?? ""}`}
      style={{ color }}
      title={title ?? "Change over the selected range"}
    >
      <span aria-hidden>{arrow}</span>
      <span>
        {sign}
        {magnitude}
        {pctStr}
      </span>
    </span>
  );
}

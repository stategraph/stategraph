import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/**
 * A small surface-styled card showing a single numeric/textual KPI plus an
 * optional unit/freshness hint. Used to compose the strip of headline numbers
 * at the top of the cost-analysis and cost-overview pages.
 *
 * `accessory` renders inline to the right of the value (e.g. a DeltaBadge);
 * `footer` renders below the value and takes precedence over `hint` (e.g. a
 * ProvenanceBadge or a richer sub-label).
 *
 * `className` / `valueClassName` extend or override the card / value styling
 * (e.g. an accent border and value colour for a headline card) without
 * forking the card's anatomy.
 */
export interface KpiCardProps {
  label: string;
  value: string;
  hint?: string;
  accessory?: ReactNode;
  footer?: ReactNode;
  className?: string;
  valueClassName?: string;
}

export function KpiCard({
  label,
  value,
  hint,
  accessory,
  footer,
  className,
  valueClassName,
}: KpiCardProps) {
  return (
    <div
      className={cn(
        "flex flex-col gap-1 px-4 py-3 bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md",
        className
      )}
    >
      <div className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">{label}</div>
      <div className="flex items-center gap-2 flex-wrap">
        <span
          className={cn("text-lg font-semibold text-[var(--sg-text)] font-mono", valueClassName)}
        >
          {value}
        </span>
        {accessory}
      </div>
      {footer ? (
        <div className="text-xs text-[var(--sg-text-muted)]">{footer}</div>
      ) : (
        hint && <div className="text-xs text-[var(--sg-text-muted)]">{hint}</div>
      )}
    </div>
  );
}

"use client";

import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";

import type {
  StateCostUnsupported,
  StateCostUnsupportedResource,
} from "@/lib/api/client";

/**
 * Lists the resources excluded from a state's priced totals, split into
 * "unsupported type" (the pricing engine doesn't know the type) and
 * "no price / usage-based" (recognised, but nothing fixed to estimate).
 * Renders nothing when there are no gaps.
 */
export function CoverageGapsPanel({ data }: { data: StateCostUnsupported | null }) {
  const [open, setOpen] = useState(false);
  const resources = data?.resources ?? [];
  if (resources.length === 0) return null;

  const unsupported = resources.filter((r) => !r.supported);
  const noPrice = resources.filter((r) => r.supported && r.no_price);

  return (
    <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
      <button
        onClick={() => setOpen((v) => !v)}
        className="w-full flex flex-wrap items-center justify-between gap-x-3 gap-y-1 px-3 py-2 text-sm hover:bg-[var(--sg-bg-2)]"
      >
        <span className="flex items-center gap-2 text-[var(--sg-text)] min-w-0">
          {open ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          Coverage gaps
          <span className="text-[var(--sg-text-muted)]">
            · {resources.length} resource{resources.length === 1 ? "" : "s"} excluded from totals
          </span>
        </span>
        <span className="flex items-center gap-3 text-xs">
          {unsupported.length > 0 && (
            <span style={{ color: "var(--sg-error)" }}>{unsupported.length} unsupported</span>
          )}
          {noPrice.length > 0 && (
            <span style={{ color: "var(--sg-warning)" }}>{noPrice.length} no price</span>
          )}
        </span>
      </button>
      {open && (
        <div className="px-3 py-3 border-t border-[var(--sg-border-light)] flex flex-col gap-4">
          {unsupported.length > 0 && (
            <GapGroup
              title="Unsupported type"
              hint="The pricing engine doesn't recognise these resource types yet."
              chipColorVar="--sg-error"
              resources={unsupported}
            />
          )}
          {noPrice.length > 0 && (
            <GapGroup
              title="No price / usage-based"
              hint="Recognised, but with no fixed billable price to estimate (often usage-based)."
              chipColorVar="--sg-warning"
              resources={noPrice}
            />
          )}
          <div className="text-xs text-[var(--sg-text-muted)]">
            These resources are excluded from the totals above, so the real bill may be higher.
          </div>
        </div>
      )}
    </div>
  );
}

function GapGroup({
  title,
  hint,
  chipColorVar,
  resources,
}: {
  title: string;
  hint: string;
  chipColorVar: string;
  resources: StateCostUnsupportedResource[];
}) {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-baseline gap-2 flex-wrap">
        <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">{title}</span>
        <span className="text-xs text-[var(--sg-text-dim)]">{hint}</span>
      </div>
      <div className="flex flex-wrap gap-1.5">
        {resources.map((r) => (
          <span
            key={r.address}
            title={`${r.type}${r.provider ? ` · ${r.provider}` : ""}`}
            className="inline-flex items-center px-2 py-0.5 rounded text-xs font-mono border break-all max-w-full"
            style={{ color: `var(${chipColorVar})`, borderColor: `var(${chipColorVar})` }}
          >
            {r.address}
          </span>
        ))}
      </div>
    </div>
  );
}

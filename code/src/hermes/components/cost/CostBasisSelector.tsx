import type { CostBasis } from "@/hooks/useCostBasis";

import { PillGroup } from "./PillGroup";

const BASES = [
  {
    id: "estimated",
    label: "Estimated",
    title: "Projected monthly cost from list pricing (Infracost)",
  },
  {
    id: "actual",
    label: "Actual",
    title: "Billed spend from your FOCUS billing exports",
  },
  {
    id: "both",
    label: "Both",
    title: "Estimated views plus the billed actuals, compared",
  },
] as const satisfies readonly { id: CostBasis; label: string; title: string }[];

export interface CostBasisSelectorProps {
  value: CostBasis;
  onChange: (basis: CostBasis) => void;
}

/**
 * The labelled basis control for the cost pages: render from the
 * Infracost-derived estimate, the actual billed (FOCUS) spend, or both.
 * Carries its own "Basis" label since every page shows the same one.
 */
export function CostBasisSelector({ value, onChange }: CostBasisSelectorProps) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">Basis</span>
      <PillGroup options={BASES} value={value} onChange={onChange} />
    </div>
  );
}

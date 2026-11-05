import { COST_RANGES, CostRange } from "@/lib/cost/range";

import { PillGroup } from "./PillGroup";

/**
 * The pill-group selector for the time window of a cost history chart. Shared
 * by the per-state and tenant cost pages.
 */
export interface CostRangeSelectorProps {
  value: CostRange;
  onChange: (range: CostRange) => void;
}

export function CostRangeSelector({ value, onChange }: CostRangeSelectorProps) {
  return <PillGroup options={COST_RANGES} value={value} onChange={onChange} />;
}

"use client";

import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";

/**
 * The basis a cost page renders from: the Infracost-derived estimate (the
 * original experience), the actual billed spend from FOCUS exports, or both
 * side by side.
 */
export type CostBasis = "estimated" | "actual" | "both";

const DEFAULT_COST_BASIS: CostBasis = "estimated";

function isCostBasis(v: string | null): v is CostBasis {
  return v === "estimated" || v === "actual" || v === "both";
}

/**
 * URL-synced basis selection (`?basis=`). Defaults to "estimated" and keeps
 * the param off the URL in that case, so pre-existing links and the default
 * experience are byte-for-byte unchanged.
 */
export function useCostBasis(): [CostBasis, (next: CostBasis) => void] {
  const [raw, setRaw] = useUrlSyncedParam("basis", DEFAULT_COST_BASIS);
  const basis: CostBasis = isCostBasis(raw) ? raw : DEFAULT_COST_BASIS;
  return [basis, setRaw];
}

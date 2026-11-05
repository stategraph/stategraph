"use client";

import { useCapabilities } from "./useCapabilities";
import type { CostAvailability, DedicatedAvailability } from "@/lib/api/client";

/**
 * Whether the server supports the cost feature. A thin selector on top of
 * {@link useCapabilities} (driven by STATEGRAPH_PRICING_SERVICE_URL on the
 * backend); falls back to [enabled: false] so the UI degrades to the
 * not-configured (cost-docs) experience.
 */
export function useCostAvailability(): {
  capability: CostAvailability | null;
  isLoading: boolean;
} {
  const { capabilities, isLoading } = useCapabilities();
  return { capability: capabilities?.costs ?? null, isLoading };
}

/**
 * Whether the server offers dedicated-Stategraph provisioning (the "Create
 * Dedicated Stategraph" flow and the personal/dev-eval tenant labeling),
 * driven by STATEGRAPH_DEDICATED_ENABLED on the backend. A thin selector on
 * top of {@link useCapabilities}, sharing its single `/capabilities` fetch.
 *
 * Falls back to [enabled: false] on error so the UI hides the dedicated
 * surfaces rather than advertising a feature the server may not offer.
 */
export function useDedicatedAvailability(): {
  capability: DedicatedAvailability | null;
  isLoading: boolean;
} {
  const { capabilities, isLoading } = useCapabilities();
  return { capability: capabilities?.dedicated ?? null, isLoading };
}

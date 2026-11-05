"use client";

import { useCapabilities } from "./useCapabilities";
import type { SecurityAvailability } from "@/lib/api/client";

/**
 * Whether the server runs security scans (STATEGRAPH_SECURITY is "true" or
 * "1"). A thin selector on top
 * of {@link useCapabilities}; falls back to [enabled: false] so the Security
 * pages degrade to the not-configured notice instead of calling endpoints that
 * would 503.
 */
export function useSecurityAvailability(): {
  capability: SecurityAvailability | null;
  isLoading: boolean;
} {
  const { capabilities, isLoading } = useCapabilities();
  return { capability: capabilities?.security ?? null, isLoading };
}

"use client";

import { useCallback, useEffect, useState } from "react";
import type { Capabilities } from "@/lib/api/client";
import { fetchServerCapabilities } from "@/lib/api/serverCapabilities";
import { ORCHESTRATION_COPY } from "@/lib/getting-started/orchestration-constants";

export type OrchestrationAvailability =
  | { status: "loading" }
  | { status: "available" }
  | { status: "unavailable" }
  | { status: "error"; message: string };

/** Read the server's orchestration capability. The envelope is the one shared
 * with every other capability consumer, so a success is cached; a failure to
 * load it stays retryable rather than being reported as unavailable. */
export async function probeOrchestrationAvailability(
  load: () => Promise<Capabilities> = fetchServerCapabilities,
): Promise<Exclude<OrchestrationAvailability, { status: "loading" }>> {
  try {
    const capabilities = await load();
    return capabilities.orchestration.enabled
      ? { status: "available" }
      : { status: "unavailable" };
  } catch (reason) {
    return {
      status: "error",
      message:
        reason instanceof Error
          ? reason.message
          : ORCHESTRATION_COPY.common.errorDetailFallback,
    };
  }
}

export function useOrchestrationAvailability(): {
  availability: OrchestrationAvailability;
  retry: () => void;
} {
  const [attempt, setAttempt] = useState(0);
  const [availability, setAvailability] =
    useState<OrchestrationAvailability>({ status: "loading" });

  const retry = useCallback((): void => {
    setAvailability({ status: "loading" });
    setAttempt((value) => value + 1);
  }, []);

  useEffect(() => {
    let cancelled = false;
    void probeOrchestrationAvailability().then((result) => {
      if (!cancelled) setAvailability(result);
    });
    return () => {
      cancelled = true;
    };
  }, [attempt]);

  return { availability, retry };
}

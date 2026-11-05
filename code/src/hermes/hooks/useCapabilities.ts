"use client";

import { useCallback, useEffect, useState } from "react";

import { useAuth } from "@/components/auth";
import type { Capabilities } from "@/lib/api/client";
import {
  cachedServerCapabilities,
  loadServerCapabilities,
  refreshServerCapabilities,
} from "@/lib/api/serverCapabilities";

/**
 * Fetches the server capability envelope and shares one successful response
 * across every caller via a module-level cache. Capability flags are
 * server-wide (driven by backend env vars like STATEGRAPH_PRICING_SERVICE_URL /
 * STATEGRAPH_SECURITY), so once a fetch has succeeded there's no reason to
 * fetch them again. The fetch waits for authentication, since the endpoint
 * sits behind the session check.
 *
 * Per-feature selectors (see {@link useCostAvailability},
 * {@link useSecurityAvailability}) sit on top of this rather than spawning new
 * endpoints. On error a consumer gets everything-disabled, so the UI degrades
 * to the not-configured experience instead of advertising features the server
 * may not really have. Only a success is cached: a consumer that mounts after a
 * failure fetches again, while one that received the fallback keeps it until it
 * remounts.
 */

export function useCapabilities(): {
  capabilities: Capabilities | null;
  isLoading: boolean;
  refresh: () => void;
} {
  const { isAuthenticated } = useAuth();
  // Initialise from the module-level cache so a consumer that mounts after a
  // fetch has succeeded paints the right thing on the first render.
  const [capabilities, setCapabilities] = useState<Capabilities | null>(cachedServerCapabilities);
  const [isLoading, setIsLoading] = useState<boolean>(() => cachedServerCapabilities() === null);

  useEffect(() => {
    // /capabilities sits behind the session check: a fetch before login
    // completes can only earn the everything-disabled fallback.
    if (!isAuthenticated) return;
    let cancelled = false;
    loadServerCapabilities().then((res) => {
      if (cancelled) return;
      setCapabilities(res);
      setIsLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [isAuthenticated]);

  const refresh = useCallback(() => {
    refreshServerCapabilities().then(
      (res) => setCapabilities(res),
      () => undefined,
    );
  }, []);

  return { capabilities, isLoading, refresh };
}

"use client";

import { useCallback, useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { useLicense, useSetupProgress } from "@/contexts";
import { firstRunSetupEnabled } from "@/lib/getting-started/first-run";
import { featureNavLock, type FeatureNavLock } from "@/lib/getting-started/setup-progress";
import { useCapabilities } from "./useCapabilities";

const RECHECK_MIN_MS = 15_000;

/** {@link firstRunSetupEnabled} for this server. */
export function useFirstRunSetup(): boolean | null {
  const { mode, isLoading: licenseLoading } = useLicense();
  const { capabilities } = useCapabilities();
  return firstRunSetupEnabled({
    modeLoading: licenseLoading,
    mode,
    orchestrationEnabled: capabilities ? capabilities.orchestration.enabled : null,
  });
}

/** Whether the areas that read a tenant's states are greyed out in the sidebar, and why. */
export function useFeatureNavLock(): FeatureNavLock {
  const firstRunSetup = useFirstRunSetup();
  const { shape } = useSetupProgress();
  return featureNavLock(firstRunSetup, shape);
}

/** While `active`, re-reads setup progress when the window gains focus, the tab becomes visible or
 *  the route changes, at most once per RECHECK_MIN_MS. */
export function useSetupRecheck(active: boolean): void {
  const { revalidate } = useSetupProgress();
  const pathname = usePathname();
  const lastCheckAt = useRef(0);
  const lastPathname = useRef(pathname);

  const recheck = useCallback(() => {
    const now = Date.now();
    if (now - lastCheckAt.current < RECHECK_MIN_MS) return;
    lastCheckAt.current = now;
    revalidate();
  }, [revalidate]);

  // The first re-check comes RECHECK_MIN_MS after the lock appears.
  useEffect(() => {
    if (active) lastCheckAt.current = Date.now();
  }, [active]);

  useEffect(() => {
    if (!active) return;
    const onVisibilityChange = () => {
      if (document.visibilityState === "visible") recheck();
    };
    window.addEventListener("focus", recheck);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      window.removeEventListener("focus", recheck);
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, [active, recheck]);

  useEffect(() => {
    if (lastPathname.current === pathname) return;
    lastPathname.current = pathname;
    if (active) recheck();
  }, [active, pathname, recheck]);
}

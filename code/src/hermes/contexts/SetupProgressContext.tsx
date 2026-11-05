"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { useAuth } from "@/components/auth";
import { useTenant } from "./TenantContext";
import { useStates } from "./StateContext";
import { executeMQL, listVcsInstallations } from "@/lib/api/client";
import { isTenantAdmin } from "@/lib/api/capabilities";
import { loadAcrossProviders, orchestrationUnavailable } from "@/lib/mql/providers";
import type { SetupFacts } from "@/lib/getting-started/setup-progress";
import {
  RECENT_RUNS_CAP,
  mapRunRow,
  mergeRecentRuns,
  recentRunsQuery,
  resolveWorkManifestPresence,
  stategraphEnginePresenceQuery,
  type RunRow,
} from "@/app/(console)/home/mqlQueries";

export interface SetupProgressValue extends SetupFacts {
  /** True until the orchestration facts for the current tenant have loaded. */
  isLoading: boolean;
  /** The newest run, for naming the repository that got its first plan. */
  latestRun: RunRow | null;
  refresh: () => void;
}

interface OrchestrationFacts {
  tenantId: string;
  hasWorkManifest: boolean | null;
  latestRun: RunRow | null;
  linkedInstallation: boolean | null;
  engineRun: boolean | null;
}

const SetupProgressContext = createContext<SetupProgressValue | undefined>(undefined);

function errorStatus(error: unknown): number | null {
  if (typeof error !== "object" || error === null || !("status" in error)) return null;
  const status = (error as { status?: unknown }).status;
  return typeof status === "number" ? status : null;
}

/**
 * The facts every setup surface reads (the Get started checklist, the Home
 * next-step cards, the sidebar badge, the first-run redirect), loaded once per
 * tenant instead of once per surface.
 */
export function SetupProgressProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, user } = useAuth();
  const { currentTenant, isLoading: tenantLoading } = useTenant();
  const { states } = useStates();
  const [facts, setFacts] = useState<OrchestrationFacts | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  const tenantId = currentTenant?.id ?? null;
  const capabilities = user?.capabilities;

  useEffect(() => {
    if (!isAuthenticated || tenantLoading || !tenantId) return;
    let cancelled = false;

    async function load(): Promise<void> {
      const id = tenantId as string;
      let hasWorkManifest: boolean | null = null;
      let latestRun: RunRow | null = null;
      try {
        const runs = await loadAcrossProviders(recentRunsQuery, mapRunRow, RECENT_RUNS_CAP);
        hasWorkManifest = resolveWorkManifestPresence(runs.rows, runs.failed);
        latestRun = mergeRecentRuns([runs.rows], 1)[0] ?? null;
      } catch (error) {
        if (orchestrationUnavailable(error)) hasWorkManifest = false;
        else console.warn("[SetupProgress] Failed to check orchestration activity:", error);
      }

      // The installation endpoint is tenant-admin-only; for anyone else the
      // list is unknown, not empty.
      let linkedInstallation: boolean | null = null;
      if (isTenantAdmin(capabilities, id)) {
        try {
          const installations = await listVcsInstallations(id);
          linkedInstallation = installations.results.length > 0;
        } catch (error) {
          const status = errorStatus(error);
          if (status !== 401 && status !== 403) {
            console.warn("[SetupProgress] Failed to check linked VCS installations:", error);
          }
        }
      }

      let engineRun: boolean | null = null;
      try {
        const result = await executeMQL(stategraphEnginePresenceQuery());
        engineRun = result.data.length > 0;
      } catch (error) {
        if (orchestrationUnavailable(error)) engineRun = false;
        else console.warn("[SetupProgress] Failed to check for Stategraph engine runs:", error);
      }

      if (cancelled) return;
      setFacts({ tenantId: id, hasWorkManifest, latestRun, linkedInstallation, engineRun });
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [isAuthenticated, tenantLoading, tenantId, capabilities, reloadKey]);

  const refresh = useCallback(() => {
    setFacts(null);
    setReloadKey((k) => k + 1);
  }, []);

  const value = useMemo<SetupProgressValue>(() => {
    const current = facts !== null && facts.tenantId === tenantId ? facts : null;
    return {
      isLoading: current === null,
      stateCount: states.length,
      hasWorkManifest: current?.hasWorkManifest ?? null,
      latestRun: current?.latestRun ?? null,
      linkedInstallation: current?.linkedInstallation ?? null,
      engineRun: current?.engineRun ?? null,
      refresh,
    };
  }, [facts, tenantId, states.length, refresh]);

  return <SetupProgressContext.Provider value={value}>{children}</SetupProgressContext.Provider>;
}

export function useSetupProgress(): SetupProgressValue {
  const context = useContext(SetupProgressContext);
  if (context === undefined) {
    throw new Error("useSetupProgress must be used within SetupProgressProvider");
  }
  return context;
}

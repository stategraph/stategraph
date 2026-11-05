"use client";

import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useMemo,
  useCallback,
  ReactNode,
} from "react";
import { State, executeMQL } from "@/lib/api/client";
import { statesListQuery } from "./mqlQueries";
import { useTenant } from "./TenantContext";

// ============================================================================
// Context Interface
// ============================================================================

export interface StateContextValue {
  states: State[];
  refreshStates: () => Promise<void>;
  isLoading: boolean;
  error: string | null;
}

const StateContext = createContext<StateContextValue | undefined>(undefined);

// ============================================================================
// Provider Component
// ============================================================================

interface StateProviderProps {
  children: ReactNode;
}

export function StateProvider({ children }: StateProviderProps) {
  const { currentTenant } = useTenant();
  const [states, setStates] = useState<State[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // States are tenant-scoped, so the loaded list stops being true the instant the tenant changes.
  // Drop it during render (React's adjust-on-tenant-change pattern) rather than leaving it to the
  // effect below, which runs a commit later: in that one commit `states` still holds the previous
  // tenant's rows while `isLoading` is still false, which is exactly what useStateSelection reads
  // to auto-select `states[0]` on its `allowAll: false` pages -- a state the new tenant cannot see.
  // Clearing the ?state= pin (#1773) closed the same hole from the URL side; this is the in-memory
  // half of it.
  const tenantId = currentTenant?.id ?? null;
  const [seenTenantId, setSeenTenantId] = useState<string | null>(tenantId);
  if (tenantId !== seenTenantId) {
    setSeenTenantId(tenantId);
    setStates([]);
    setError(null);
    // A fetch is about to run for the new tenant; with no tenant there is nothing to wait for.
    setIsLoading(tenantId !== null);
  }

  // Fetch states when tenant changes
  const fetchStates = useCallback(async () => {
    if (!currentTenant) {
      setStates([]);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const result = await executeMQL(statesListQuery(currentTenant.id));
      if (result.defaultLimitApplied !== null) {
        console.warn(
          `[StateContext] Unexpected default limit (${result.defaultLimitApplied}) applied; some states may be missing.`
        );
      }
      setStates(result.data as State[]);
    } catch (err: unknown) {
      console.error("[StateContext] Failed to fetch states:", err);
      const message = err instanceof Error ? err.message : "Failed to load states";
      setError(message);
      setStates([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentTenant]);

  // Fetch states when tenant changes
  useEffect(() => {
    fetchStates();
  }, [fetchStates]);

  const value = useMemo(
    () => ({
      states,
      refreshStates: fetchStates,
      isLoading,
      error,
    }),
    [states, isLoading, error, fetchStates]
  );

  return (
    <StateContext.Provider value={value}>{children}</StateContext.Provider>
  );
}

// ============================================================================
// Hooks
// ============================================================================

export function useStates(): StateContextValue {
  const context = useContext(StateContext);

  if (context === undefined) {
    throw new Error("useStates must be used within a StateProvider");
  }

  return context;
}

// Backwards-compatible alias
export { useStates as useStateContext };

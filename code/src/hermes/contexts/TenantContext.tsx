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
import { Tenant, executeMQL } from "@/lib/api/client";
import {
  isLiveOrchestrationTenantChange,
  stripTenantOrchestrationSearchParams,
} from "@/lib/getting-started/orchestration-state";
import { tenantsListQuery } from "./mqlQueries";
import { useAuth } from "@/components/auth";
import { setAnalyticsTenant } from "@/lib/analytics";

// ============================================================================
// Context Interface
// ============================================================================

export interface TenantContextValue {
  currentTenant: Tenant | null;
  tenants: Tenant[];
  setCurrentTenant: (tenant: Tenant) => void;
  /** Refetch the tenant list (e.g. after creating or renaming a tenant),
   *  keeping the current selection by id and refreshing its object so new
   *  names show everywhere. Returns the fresh list; failures propagate. */
  refreshTenants: () => Promise<Tenant[]>;
  isLoading: boolean;
  error: string | null;
}

const TenantContext = createContext<TenantContextValue | undefined>(undefined);

// ============================================================================
// Helpers
// ============================================================================

const STORAGE_KEY = "stategraph-tenant";

/** Read the `tenant` query param from the current URL (client-side only). */
function getTenantFromUrl(): string | null {
  if (typeof window === "undefined") return null;
  const params = new URLSearchParams(window.location.search);
  return params.get("tenant");
}

/** Update (or add) the `tenant` query param in the URL without a navigation. */
function setTenantInUrl(tenantId: string): void {
  if (typeof window === "undefined") return;
  const url = new URL(window.location.href);
  if (isLiveOrchestrationTenantChange(url.pathname, url.searchParams, tenantId)) {
    url.search = stripTenantOrchestrationSearchParams(url.searchParams).toString();
  }
  url.searchParams.set("tenant", tenantId);
  window.history.replaceState(null, "", url.pathname + url.search);
}

// ============================================================================
// Provider Component
// ============================================================================

interface TenantProviderProps {
  children: ReactNode;
}

export function TenantProvider({ children }: TenantProviderProps) {
  const { isAuthenticated, isLoading: authLoading } = useAuth();
  const [currentTenant, setCurrentTenantState] = useState<Tenant | null>(null);
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Fetch tenants only after authentication is complete
  useEffect(() => {
    // Wait for auth to complete
    if (authLoading) {
      return;
    }

    // Don't fetch if not authenticated
    if (!isAuthenticated) {
      setIsLoading(false);
      return;
    }

    const fetchTenants = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const result = await executeMQL(tenantsListQuery());
        const tenantsList = result.data as Tenant[];
        setTenants(tenantsList);

        if (tenantsList.length > 0) {
          // Priority: URL param > localStorage > first tenant
          const urlTenantId = getTenantFromUrl();
          const storedTenantId =
            typeof window !== "undefined"
              ? localStorage.getItem(STORAGE_KEY)
              : null;

          let tenantToSelect: Tenant | undefined;

          // 1. Try URL param first
          if (urlTenantId) {
            tenantToSelect = tenantsList.find((t) => t.id === urlTenantId);
          }

          // 2. Fall back to localStorage
          if (!tenantToSelect && storedTenantId) {
            tenantToSelect = tenantsList.find((t) => t.id === storedTenantId);
          }

          // 3. Default to first tenant
          if (!tenantToSelect) {
            tenantToSelect = tenantsList[0];
          }

          setCurrentTenantState(tenantToSelect);

          // Sync URL and localStorage with the selected tenant
          if (typeof window !== "undefined") {
            localStorage.setItem(STORAGE_KEY, tenantToSelect.id);
            setTenantInUrl(tenantToSelect.id);
          }
        }
      } catch (err: unknown) {
        console.error("[TenantContext] Failed to fetch tenants:", err);
        const message = err instanceof Error ? err.message : "Failed to load tenants";
        setError(message);
      } finally {
        setIsLoading(false);
      }
    };

    fetchTenants();
  }, [isAuthenticated, authLoading]);

  const currentTenantId = currentTenant?.id;
  useEffect(() => {
    setAnalyticsTenant(currentTenantId);
  }, [currentTenantId]);

  // Persist selected tenant to localStorage and update URL
  const setCurrentTenant = useCallback((tenant: Tenant) => {
    setCurrentTenantState(tenant);
    if (typeof window !== "undefined") {
      localStorage.setItem(STORAGE_KEY, tenant.id);
      setTenantInUrl(tenant.id);
      // State ids are tenant-scoped: a `state` pin carried across a switch
      // would follow every navigation (useDeepLinkRouter re-injects it) and
      // render state-scoped pages empty for the new tenant. Only here: the
      // initial-selection sync above must keep ?state= deep links working.
      const url = new URL(window.location.href);
      if (url.searchParams.has("state")) {
        url.searchParams.delete("state");
        window.history.replaceState(null, "", url.pathname + url.search);
      }
    }
  }, []);

  // Re-fetch the tenant list without disturbing the current selection. Used after creating a tenant
  // so it appears in the switcher immediately. Returns the list and lets a failure propagate.
  const refreshTenants = useCallback(async () => {
    const result = await executeMQL(tenantsListQuery());
    const tenantsList = result.data as Tenant[];
    setTenants(tenantsList);
    // Keep the selected tenant's object in sync with the refreshed list (#1773): a rename
    // must show up everywhere `currentTenant.name` is read, not just in the switcher list.
    //
    // Swap only when something actually changed. `find` yields a fresh object every refresh, and
    // currentTenant's identity is a dependency of StateContext.fetchStates and of
    // useDeepLinkRouter.injectParams (which documents that an unstable identity there crashes the
    // Visualization and Dashboard viewers) -- handing them a new-but-equal object would refetch
    // every state on every refresh. A tenant is {id, name} and the id is what we matched on, so
    // the name is the whole of the rest.
    setCurrentTenantState((cur) => {
      if (!cur) return cur;
      const next = tenantsList.find((t) => t.id === cur.id);
      return next && next.name !== cur.name ? next : cur;
    });
    return tenantsList;
  }, []);

  const value = useMemo(
    () => ({
      currentTenant,
      tenants,
      setCurrentTenant,
      refreshTenants,
      isLoading,
      error,
    }),
    [currentTenant, tenants, setCurrentTenant, refreshTenants, isLoading, error]
  );

  return (
    <TenantContext.Provider value={value}>{children}</TenantContext.Provider>
  );
}

// ============================================================================
// Hook
// ============================================================================

export function useTenant(): TenantContextValue {
  const context = useContext(TenantContext);

  if (context === undefined) {
    throw new Error("useTenant must be used within a TenantProvider");
  }

  return context;
}

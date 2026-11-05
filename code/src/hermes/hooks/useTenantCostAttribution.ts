"use client";

import { useEffect, useState } from "react";

import { getTenantCostAttribution, type TenantCostAttribution } from "@/lib/api/client";
import { useTenant } from "@/contexts";

interface UseTenantCostAttributionResult {
  attribution: TenantCostAttribution | null;
  isLoading: boolean;
  error: string | null;
}

interface Settled {
  /** Tenant the result was fetched for; mismatch means the stored result is stale. */
  tenantId: string;
  attribution: TenantCostAttribution | null;
  error: string | null;
}

/**
 * Fetch the actual-spend attribution summary for the active tenant (the
 * "Actual" basis of the cost pages). Same settled-keyed state design as
 * {@link useTenantCosts}: loading/result are derived by comparing the settled
 * key against the current tenant, so a slow response never overwrites a
 * fresher one. Fetches whenever mounted -- the cost pages gate mounting on
 * the basis.
 */
export function useTenantCostAttribution(): UseTenantCostAttributionResult {
  const { currentTenant } = useTenant();
  const tenantId = currentTenant?.id ?? null;

  const [settled, setSettled] = useState<Settled | null>(null);

  useEffect(() => {
    if (!tenantId) return;
    let cancelled = false;
    getTenantCostAttribution(tenantId)
      .then((res) => {
        if (!cancelled) setSettled({ tenantId, attribution: res, error: null });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setSettled({
          tenantId,
          attribution: null,
          error: err instanceof Error ? err.message : "Failed to load actual cost data",
        });
      });
    return () => {
      cancelled = true;
    };
  }, [tenantId]);

  const fresh = settled !== null && settled.tenantId === tenantId;
  return {
    attribution: fresh ? settled.attribution : null,
    isLoading: tenantId !== null && !fresh,
    error: fresh ? settled.error : null,
  };
}

"use client";

import { useEffect, useState } from "react";

import { getTenantSecurityHistory, type TenantSecurityHistory } from "@/lib/api/client";
import { useTenant } from "@/contexts";
import { type CostRange, rangeToFromTo } from "@/lib/cost/range";

interface UseTenantSecurityHistoryOptions {
  range: CostRange;
}

interface UseTenantSecurityHistoryResult {
  history: TenantSecurityHistory | null;
  isLoading: boolean;
  error: string | null;
}

interface Settled {
  key: string;
  history: TenantSecurityHistory | null;
  error: string | null;
}

function keyFor(tenantId: string | undefined, range: CostRange): string | null {
  if (!tenantId) return null;
  return `${tenantId}|${range}`;
}

/**
 * Fetch the tenant-wide security posture history for the active tenant. The
 * series carries both the severity and blast breakdowns on every entry, so the
 * page toggles dimensions client-side without re-fetching; the only request
 * input is the time window. Re-runs on tenant / range changes and cancels stale
 * requests on unmount or rerun.
 *
 * Same settled-key pattern as {@link useTenantCostHistory}: the effect only ever
 * calls setState in async callbacks, and a no-tenant key resolves to `null`.
 */
export function useTenantSecurityHistory(
  options: UseTenantSecurityHistoryOptions
): UseTenantSecurityHistoryResult {
  const { currentTenant } = useTenant();
  const { range } = options;
  const key = keyFor(currentTenant?.id, range);

  const [settled, setSettled] = useState<Settled | null>(null);

  useEffect(() => {
    if (!currentTenant || !key) return;
    let cancelled = false;
    const { from, to } = rangeToFromTo(range, new Date());
    getTenantSecurityHistory(currentTenant.id, { from, to })
      .then((res) => {
        if (!cancelled) setSettled({ key, history: res, error: null });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setSettled({
          key,
          history: null,
          error: err instanceof Error ? err.message : "Failed to load security history",
        });
      });
    return () => {
      cancelled = true;
    };
  }, [currentTenant, range, key]);

  if (key === null) {
    return { history: null, isLoading: false, error: null };
  }
  const fresh = settled !== null && settled.key === key;
  return {
    history: fresh ? settled.history : null,
    isLoading: !fresh,
    error: fresh ? settled.error : null,
  };
}

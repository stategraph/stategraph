"use client";

import { useEffect, useState } from "react";

import { getTenantCosts, type TenantCosts } from "@/lib/api/client";
import { useTenant } from "@/contexts";

interface UseTenantCostsResult {
  rollup: TenantCosts | null;
  isLoading: boolean;
  error: string | null;
}

interface Settled {
  /** Stable key identifying the (tenant, tagKey) the result was fetched for.
   *  Comparing against the current key tells us whether the stored result is
   *  stale (request in flight) or current (matches what the caller wants now). */
  key: string;
  rollup: TenantCosts | null;
  error: string | null;
}

function keyFor(tenantId: string | undefined, tagKey: string | undefined): string | null {
  if (!tenantId) return null;
  return `${tenantId}|${tagKey ?? ""}`;
}

/**
 * Fetch the tenant cost rollup for the active tenant. Re-runs whenever the
 * tenant or {@link options.tagKey} changes; aborts the previous request on
 * unmount or rerun so a slow response can't overwrite a fresher one.
 *
 * State design: a single {@link Settled} object holds the last response
 * keyed by `(tenantId, tagKey)`. {@link isLoading} and the exposed rollup
 * are derived by comparing the current key against the settled key, which
 * means the effect only ever calls setState in async callbacks -- never
 * synchronously at the top of the body.
 *
 * `skip` suppresses the fetch while keeping any settled data -- for callers
 * that must stay mounted (rules of hooks) but aren't rendering estimates,
 * e.g. the cost pages on the "actual" basis.
 */
export function useTenantCosts(options?: {
  tagKey?: string;
  skip?: boolean;
}): UseTenantCostsResult {
  const { currentTenant } = useTenant();
  const tagKey = options?.tagKey;
  const skip = options?.skip ?? false;
  const key = keyFor(currentTenant?.id, tagKey);

  const [settled, setSettled] = useState<Settled | null>(null);

  useEffect(() => {
    if (!currentTenant || !key || skip) return;
    let cancelled = false;
    getTenantCosts(currentTenant.id, { tag_key: tagKey })
      .then((res) => {
        if (!cancelled) setSettled({ key, rollup: res, error: null });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setSettled({
          key,
          rollup: null,
          error: err instanceof Error ? err.message : "Failed to load tenant costs",
        });
      });
    return () => {
      cancelled = true;
    };
  }, [currentTenant, tagKey, key, skip]);

  const fresh = settled !== null && settled.key === key;
  return {
    rollup: fresh ? settled.rollup : null,
    isLoading: !skip && key !== null && !fresh,
    error: fresh ? settled.error : null,
  };
}

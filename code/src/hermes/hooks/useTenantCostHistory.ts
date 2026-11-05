"use client";

import { useEffect, useState } from "react";

import { getTenantCostHistory, type TenantCostHistory } from "@/lib/api/client";
import { useTenant } from "@/contexts";
import { type CostRange, rangeToFromTo } from "@/lib/cost/range";

interface UseTenantCostHistoryOptions {
  range: CostRange;
  /** Grouping dimension; `undefined` requests the un-grouped total series. */
  groupBy?: "provider" | "type" | "tag";
  /** Required when {@link groupBy} is `"tag"`. When the caller forgets it,
   *  the hook short-circuits to an empty result rather than letting the
   *  backend respond with 400. */
  tagKey?: string;
  /** Suppress the fetch (keeping settled data) -- for callers that must stay
   *  mounted but aren't rendering the history, e.g. the "actual" basis. */
  skip?: boolean;
}

interface UseTenantCostHistoryResult {
  history: TenantCostHistory | null;
  isLoading: boolean;
  error: string | null;
}

interface Settled {
  key: string;
  history: TenantCostHistory | null;
  error: string | null;
}

const EMPTY_HISTORY: TenantCostHistory = { points: [] };

function keyFor(
  tenantId: string | undefined,
  range: CostRange,
  groupBy: "provider" | "type" | "tag" | undefined,
  tagKey: string | undefined
): string | null {
  if (!tenantId) return null;
  return `${tenantId}|${range}|${groupBy ?? ""}|${tagKey ?? ""}`;
}

/**
 * Fetch the tenant cost history for the active tenant. Re-runs on tenant /
 * range / groupBy / tagKey changes; cancels stale requests on unmount or
 * rerun.
 *
 * Same key-derivation pattern as {@link useTenantCosts}: the effect only
 * ever calls setState in async callbacks. Two short-circuit cases match
 * what the two cost pages did inline:
 *
 *  - No tenant -> resolve to `null`.
 *  - `groupBy === "tag"` without a `tagKey` -> resolve to `{ points: [] }`
 *    (the chart renders its empty state below; the backend would 400).
 */
export function useTenantCostHistory(
  options: UseTenantCostHistoryOptions
): UseTenantCostHistoryResult {
  const { currentTenant } = useTenant();
  const { range, groupBy, tagKey, skip = false } = options;
  const key = keyFor(currentTenant?.id, range, groupBy, tagKey);
  const tagShortCircuit = groupBy === "tag" && !tagKey;

  const [settled, setSettled] = useState<Settled | null>(null);

  useEffect(() => {
    if (!currentTenant || !key || tagShortCircuit || skip) return;
    let cancelled = false;
    const { from, to } = rangeToFromTo(range, new Date());
    const tag_key = groupBy === "tag" && tagKey ? tagKey : undefined;
    getTenantCostHistory(currentTenant.id, { from, to, group_by: groupBy, tag_key })
      .then((res) => {
        if (!cancelled) setSettled({ key, history: res, error: null });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setSettled({
          key,
          history: null,
          error: err instanceof Error ? err.message : "Failed to load cost history",
        });
      });
    return () => {
      cancelled = true;
    };
  }, [currentTenant, range, groupBy, tagKey, key, tagShortCircuit, skip]);

  if (key === null) {
    return { history: null, isLoading: false, error: null };
  }
  if (tagShortCircuit) {
    return { history: EMPTY_HISTORY, isLoading: false, error: null };
  }
  const fresh = settled !== null && settled.key === key;
  return {
    history: fresh ? settled.history : null,
    isLoading: !skip && !fresh,
    error: fresh ? settled.error : null,
  };
}

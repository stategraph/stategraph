"use client";

import { useCallback } from "react";

import { useUrlSyncedNullable, useUrlSyncedParam } from "./useUrlSyncedParam";

/**
 * Grouping dimension for the tenant cost history chart and breakdown
 * panels. `"none"` shows the total series only; the others mirror the
 * backend's ?group_by values.
 */
export type TenantHistoryGroupBy = "none" | "provider" | "type" | "tag";

const DEFAULT_GROUP_BY: TenantHistoryGroupBy = "none";

function isGroupBy(value: string | null | undefined): value is TenantHistoryGroupBy {
  return value === "none" || value === "provider" || value === "type" || value === "tag";
}

/**
 * URL-synced grouping selection for the tenant cost page. Reads `?group_by=`
 * and `?tag_key=` on mount; the setter clears `?tag_key` whenever group_by
 * leaves the `tag` dimension so the URL stays consistent with what the page
 * actually reads.
 */
export function useTenantHistoryGrouping(): {
  groupBy: TenantHistoryGroupBy;
  tagKey: string | null;
  setGroupBy: (next: TenantHistoryGroupBy) => void;
  setTagKey: (next: string | null) => void;
} {
  const [groupByRaw, setGroupByRaw] = useUrlSyncedParam("group_by", DEFAULT_GROUP_BY);
  const [tagKey, setTagKeyRaw] = useUrlSyncedNullable("tag_key");

  const groupBy: TenantHistoryGroupBy = isGroupBy(groupByRaw) ? groupByRaw : DEFAULT_GROUP_BY;

  const setGroupBy = useCallback(
    (next: TenantHistoryGroupBy) => {
      setGroupByRaw(next);
      // Leaving the tag dimension must also clear ?tag_key from the URL.
      if (next !== "tag") setTagKeyRaw(null);
    },
    [setGroupByRaw, setTagKeyRaw]
  );

  return { groupBy, tagKey, setGroupBy, setTagKey: setTagKeyRaw };
}

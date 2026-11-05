"use client";

import { useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useUrlFollowingState } from "./urlSyncedValue";

/**
 * URL-synced string state for a single query parameter. Reads `?<key>=`,
 * falls back to {@link fallback}; the setter writes back to the URL via
 * `history.replaceState` (no navigation) and deletes the param when its value
 * equals the fallback so the URL stays clean.
 *
 * The fallback also doubles as a "default" sentinel: passing `""` produces the
 * "optional present-as-string-or-empty" shape (used by cost-explorer's
 * `dim`/`tag_key`/`min`); passing a real default value produces the "always-set,
 * URL-clean-when-default" shape used by {@link useCostRange}. For the
 * "optional-null" shape (used by {@link useUrlSyncedNullable}) prefer that
 * sibling hook so the caller doesn't have to special-case empty strings.
 *
 * The value comes from `useSearchParams()`, not `window.location`: during a
 * client-side navigation the new page renders before the router updates
 * `window.location`, so a raw read would return the previous page's query
 * string. It also keeps following the URL: a client navigation to the same
 * page with another query (a sidebar link dropping `?owner=`) keeps this
 * component mounted, and the state adopts the new value. The rewrite passes
 * `null` as the history state: Next's patched `replaceState` treats a call
 * carrying its own state object as internal and skips syncing the router,
 * leaving `useSearchParams()` stale.
 */
export function useUrlSyncedParam(
  key: string,
  fallback: string
): [string, (next: string) => void] {
  const searchParams = useSearchParams();
  const [value, setValueRaw, recordWrite] = useUrlFollowingState<string>(
    searchParams.get(key) ?? fallback
  );
  const setValue = useCallback(
    (next: string) => {
      setValueRaw(next);
      if (typeof window === "undefined") return;
      const url = new URL(window.location.href);
      const before = url.search;
      if (next && next !== fallback) url.searchParams.set(key, next);
      else url.searchParams.delete(key);
      if (url.search === before) return;
      recordWrite(next && next !== fallback ? next : fallback);
      window.history.replaceState(null, "", url.pathname + url.search);
    },
    [key, fallback, setValueRaw, recordWrite]
  );
  return [value, setValue];
}

/**
 * URL-synced nullable string state. Same as {@link useUrlSyncedParam} but the
 * value type is `string | null` and `null` means "param absent".
 */
export function useUrlSyncedNullable(
  key: string
): [string | null, (next: string | null) => void] {
  const searchParams = useSearchParams();
  const [value, setValueRaw, recordWrite] = useUrlFollowingState<string | null>(
    searchParams.get(key)
  );
  const setValue = useCallback(
    (next: string | null) => {
      setValueRaw(next);
      if (typeof window === "undefined") return;
      const url = new URL(window.location.href);
      const before = url.search;
      if (next) url.searchParams.set(key, next);
      else url.searchParams.delete(key);
      if (url.search === before) return;
      recordWrite(next || null);
      window.history.replaceState(null, "", url.pathname + url.search);
    },
    [key, setValueRaw, recordWrite]
  );
  return [value, setValue];
}

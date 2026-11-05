"use client";

import { useSearchParams, useRouter, usePathname } from "next/navigation";
import { useCallback, useMemo } from "react";

interface QueryState {
  q: string;
  page: string[];
  limit: number;
  instance: string | null;
}

export function useQueryState() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  // Parse current state from URL - memoize arrays to prevent infinite loops
  const q = searchParams.get("q") || "";
  const page = useMemo(() => searchParams.getAll("page"), [searchParams]);
  const limit = parseInt(searchParams.get("limit") || "50", 10);
  const instance = searchParams.get("instance");

  // Update URL with new query state
  const setQueryState = useCallback(
    (updates: Partial<QueryState>) => {
      const params = new URLSearchParams(searchParams);

      // Update q parameter
      if (updates.q !== undefined) {
        if (updates.q) {
          params.set("q", updates.q);
        } else {
          params.delete("q");
        }
      }

      // Update page parameter (array)
      if (updates.page !== undefined) {
        params.delete("page");
        updates.page.forEach((p) => params.append("page", p));
      }

      // Update limit parameter
      if (updates.limit !== undefined) {
        if (updates.limit !== 50) {
          params.set("limit", updates.limit.toString());
        } else {
          params.delete("limit");
        }
      }

      // Update instance parameter
      if (updates.instance !== undefined) {
        if (updates.instance) {
          params.set("instance", updates.instance);
        } else {
          params.delete("instance");
        }
      }

      // Push new URL
      const newUrl = params.toString()
        ? `${pathname}?${params.toString()}`
        : pathname;
      router.push(newUrl);
    },
    [searchParams, router, pathname]
  );

  // Helper to reset pagination
  const resetPage = useCallback(() => {
    setQueryState({ page: [] });
  }, [setQueryState]);

  return {
    q,
    page,
    limit,
    instance,
    setQueryState,
    resetPage,
  };
}

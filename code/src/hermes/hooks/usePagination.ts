"use client";

import { useCallback, useMemo, useState } from "react";
import { pageBounds } from "@/lib/ui/paginate";

/** Feeds components/instances/PaginationControls directly:
 *  page/hasNext/hasPrevious/next/previous/totalPages/total map onto
 *  currentPage/hasNext/hasPrevious/onNext/onPrevious/totalPages/totalResults. */
export interface Pagination<T> {
  page: number;
  pageItems: T[];
  totalPages: number;
  total: number;
  hasNext: boolean;
  hasPrevious: boolean;
  next: () => void;
  previous: () => void;
  setPage: (p: number) => void;
}

/**
 * Client-side pagination over an in-memory array (the list pages fetch a bounded
 * page of rows via MQL, then filter + paginate locally).
 *
 * The requested page is stored raw and *clamped on read* via {@link pageBounds},
 * so a filter that shrinks the set never lands the view on an out-of-range page
 * — no reconciling effect (and no cascading re-render) required. Every reader
 * and every control works off the clamped page.
 *
 * Pass the active filters as `resetKey` to jump back to page 1 whenever they
 * change (clamping alone would leave the user mid-way into the new result
 * set). Compared with Object.is at read time — same no-effect design.
 */
export function usePagination<T>(items: T[], pageSize: number, resetKey?: unknown): Pagination<T> {
  const [state, setState] = useState<{ key: unknown; page: number }>({ key: resetKey, page: 1 });
  const requested = Object.is(state.key, resetKey) ? state.page : 1;
  const setRequested = useCallback((p: number) => setState({ key: resetKey, page: p }), [resetKey]);
  const total = items.length;
  const b = pageBounds(total, requested, pageSize);

  const pageItems = useMemo(() => items.slice(b.start, b.end), [items, b.start, b.end]);

  // Stable identities: consumers list the returned object (or its callbacks) in
  // effect/callback deps — see hooks/useDeepLinkRouter.ts for the incident this
  // guards against.
  const next = useCallback(() => setRequested(b.page + 1), [b.page, setRequested]);
  const previous = useCallback(() => setRequested(b.page - 1), [b.page, setRequested]);

  return useMemo(
    () => ({
      page: b.page,
      pageItems,
      totalPages: b.totalPages,
      total,
      hasNext: b.hasNext,
      hasPrevious: b.hasPrevious,
      next,
      previous,
      setPage: setRequested,
    }),
    [b.page, b.totalPages, b.hasNext, b.hasPrevious, pageItems, total, next, previous, setRequested],
  );
}

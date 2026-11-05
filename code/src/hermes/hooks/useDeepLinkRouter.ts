"use client";

/* eslint-disable react-hooks/preserve-manual-memoization -- The React Compiler
   bails on optimizing this hook (the `{ ...router }` spread of an external
   object), so it can't preserve the manual memoization. But the memo is required:
   consumers list the returned object in effect/callback deps, and an unstable
   identity causes infinite re-render loops (the Visualization/Dashboard viewers
   crash on load without it). Manual useMemo/useCallback stays. */

import { useCallback, useMemo } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTenant } from "@/contexts";

/** Whether a click started on a link or form control inside the element that
 *  handles it, rather than on that element itself. */
function fromNestedControl(e: React.MouseEvent): boolean {
  const hit = (e.target as Element).closest("a,button,input,select,textarea");
  return hit !== null && hit !== e.currentTarget;
}

/**
 * Drop-in replacement for Next.js useRouter() that auto-injects `tenant` and
 * `state` URL params into all push()/replace() calls, so every navigation
 * preserves the current tenant/state context and URLs stay shareable deep links.
 *
 * The returned object keeps a stable identity across renders (see the file-level
 * eslint-disable above for why the memoization is manual).
 */
export function useDeepLinkRouter() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { currentTenant } = useTenant();

  const injectParams = useCallback(
    (href: string): string => {
      const url = new URL(href, window.location.origin);
      if (currentTenant && !url.searchParams.has("tenant")) {
        url.searchParams.set("tenant", currentTenant.id);
      }
      const currentState = searchParams.get("state");
      if (currentState && !url.searchParams.has("state")) {
        url.searchParams.set("state", currentState);
      }
      return url.pathname + url.search;
    },
    [currentTenant, searchParams]
  );

  const push = useCallback(
    (href: string, options?: Parameters<typeof router.push>[1]) => router.push(injectParams(href), options),
    [router, injectParams]
  );
  const replace = useCallback(
    (href: string, options?: Parameters<typeof router.replace>[1]) => router.replace(injectParams(href), options),
    [router, injectParams]
  );

  /**
   * Click handlers for an element that navigates to `href`: plain click is an
   * SPA push, while ctrl/cmd/shift-click and middle-click open a new tab with
   * the tenant/state params included — matching what a real link would do.
   * A click on a link or control nested inside the element (a table row's PR
   * button, an external "Open" link) belongs to that control and is ignored.
   */
  const nav = useCallback(
    (href: string) => ({
      onClick: (e: React.MouseEvent) => {
        if (fromNestedControl(e)) return;
        if (e.ctrlKey || e.metaKey || e.shiftKey) {
          window.open(injectParams(href), "_blank", "noopener");
          return;
        }
        router.push(injectParams(href));
      },
      onAuxClick: (e: React.MouseEvent) => {
        if (e.button === 1 && !fromNestedControl(e)) window.open(injectParams(href), "_blank", "noopener");
      },
    }),
    [router, injectParams]
  );

  return useMemo(() => ({ ...router, push, replace, nav }), [router, push, replace, nav]);
}

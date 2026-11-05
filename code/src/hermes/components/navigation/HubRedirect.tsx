"use client";

import { Suspense, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useDeepLinkRouter, useInitialLoad } from "@/hooks";
import { PageLoading } from "@/components/page";

interface HubRedirectProps {
  /** Old hub tab id -> the screen's standalone route. */
  tabRoutes: Record<string, string>;
  /** Where the bare hub URL lands (its first screen). */
  defaultPath: string;
}

/**
 * Redirect page for a retired tab hub: every screen is a real route with its
 * own sidebar entry, so the hub URL only forwards. `?tab=` URLs map to the
 * standalone routes; remaining query params (filters, deep-link context)
 * carry over unchanged.
 */
function Redirector({ tabRoutes, defaultPath }: HubRedirectProps) {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();

  const redirect = useCallback(() => {
    const params = new URLSearchParams(searchParams.toString());
    const tab = params.get("tab");
    params.delete("tab");
    const rest = params.toString();
    const path = (tab && tabRoutes[tab]) || defaultPath;
    router.replace(rest ? `${path}?${rest}` : path);
  }, [router, searchParams, tabRoutes, defaultPath]);
  useInitialLoad(redirect);

  return <PageLoading />;
}

export function HubRedirect(props: HubRedirectProps) {
  return (
    <Suspense fallback={<PageLoading />}>
      <Redirector {...props} />
    </Suspense>
  );
}

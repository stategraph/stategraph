"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useMemo } from "react";
import { useTenant } from "@/contexts";

type LinkProps = React.ComponentProps<typeof Link>;

/**
 * Drop-in replacement for Next.js <Link> that auto-injects
 * `tenant` and `state` URL params into the href.
 *
 * Use this for navigation links that should preserve deep-link context.
 */
export function DeepLink({ href, ...props }: LinkProps) {
  const searchParams = useSearchParams();
  const { currentTenant } = useTenant();

  const enrichedHref = useMemo(() => {
    // Only process string hrefs (not UrlObject)
    if (typeof href !== "string") return href;

    const url = new URL(href, window.location.origin);

    // Inject tenant if present and not already in target URL
    if (currentTenant && !url.searchParams.has("tenant")) {
      url.searchParams.set("tenant", currentTenant.id);
    }

    // Carry forward state param if present in current URL and not in target
    const currentState = searchParams.get("state");
    if (currentState && !url.searchParams.has("state")) {
      url.searchParams.set("state", currentState);
    }

    return url.pathname + url.search;
  }, [href, currentTenant, searchParams]);

  return <Link href={enrichedHref} {...props} />;
}

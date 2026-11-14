"use client";

import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { ExternalLink } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getProductById, type StateAreaId } from "@/config/products";
import { useLicense } from "@/contexts";
import { useCapabilities, useDeepLinkRouter, useFeatureNavLock } from "@/hooks";
import {
  SETUP_COPY,
  STATE_DOCS_HREF,
  STATE_SETUP_HREF,
  stateAreaGate,
} from "@/lib/getting-started/setup-progress";

const COPY = SETUP_COPY.stateArea;

/** Renders the page, or the Infrastructure as a Database empty state in its place when the route
 *  belongs to a state area and the tenant has a run but no state. */
export function StateAreaGate({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const lock = useFeatureNavLock();
  const { mode } = useLicense();
  const { capabilities } = useCapabilities();

  const area = stateAreaGate({
    lock,
    pathname,
    mode,
    costsEnabled: capabilities?.costs.enabled === true,
    securityEnabled: capabilities?.security.enabled === true,
  });
  if (area === null) return <>{children}</>;
  return <StateAreaEmptyState area={area} />;
}

function StateAreaEmptyState({ area }: { area: StateAreaId }) {
  const router = useDeepLinkRouter();
  const product = getProductById(area)!;
  const Icon = product.icon;

  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] px-6 text-center">
      <div
        className="h-16 w-16 rounded-2xl flex items-center justify-center mb-6"
        style={{
          background: "var(--sg-accent-bg)",
          border: "1px solid var(--sg-border)",
        }}
      >
        <Icon className="h-8 w-8" style={{ color: "var(--sg-accent)" }} />
      </div>
      <h1 className="text-2xl font-semibold text-[var(--sg-text)]">{COPY.title(product.label)}</h1>
      <p className="mt-3 max-w-md text-sm leading-relaxed text-[var(--sg-text-muted)]">
        {COPY.areaBody[area]}
      </p>
      <p className="mt-2 max-w-md text-sm leading-relaxed text-[var(--sg-text-muted)]">{COPY.body}</p>
      <div className="mt-7 flex flex-wrap items-center justify-center gap-3">
        <Button size="lg" className="h-11 px-6 font-semibold" {...router.nav(STATE_SETUP_HREF)}>
          {COPY.setupAction}
        </Button>
        <Button asChild variant="outline" size="lg" className="h-11 px-6 font-semibold">
          <a href={STATE_DOCS_HREF} target="_blank" rel="noopener noreferrer">
            {COPY.docsAction}
            <ExternalLink className="h-4 w-4 ml-2" />
          </a>
        </Button>
      </div>
    </div>
  );
}

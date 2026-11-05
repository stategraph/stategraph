"use client";

import type { ReactNode } from "react";
import { Plug } from "lucide-react";

import { useAuth } from "@/components/auth";
import { Button } from "@/components/ui/button";
import { useSetupProgress, useTenant } from "@/contexts";
import { useDeepLinkRouter } from "@/hooks";
import { isTenantAdmin } from "@/lib/api/capabilities";
import {
  ORCHESTRATION_SETUP_HREF,
  SETUP_COPY,
  orchestrationEmptyKind,
} from "@/lib/getting-started/setup-progress";
import { cn } from "@/lib/utils";

const COPY = SETUP_COPY.orchestrationEmpty;

/**
 * The empty state of an orchestration screen. `children` is the screen's own empty copy; a tenant
 * with no connected provider gets the way into setup instead (tenant admin) or after it (member).
 * `centered` matches the alignment of the screen's copy.
 */
export function OrchestrationEmptyState({
  children,
  centered = false,
}: {
  children: ReactNode;
  centered?: boolean;
}) {
  const router = useDeepLinkRouter();
  const { user } = useAuth();
  const { currentTenant } = useTenant();
  const progress = useSetupProgress();

  const kind = progress.isLoading
    ? "plain"
    : orchestrationEmptyKind({
        tenantAdmin: isTenantAdmin(user?.capabilities, currentTenant?.id),
        linkedInstallation: progress.linkedInstallation,
        hasWorkManifest: progress.hasWorkManifest,
      });

  if (kind === "connect") {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <Plug className="h-8 w-8 mb-3 text-[var(--sg-text-muted)]" />
        <div className="text-sm font-medium text-[var(--sg-text)]">{COPY.connectTitle}</div>
        <div className="mt-1 max-w-md text-xs text-[var(--sg-text-muted)]">{COPY.connectBody}</div>
        <Button size="sm" className="mt-4" {...router.nav(ORCHESTRATION_SETUP_HREF)}>
          {COPY.connectAction}
        </Button>
      </div>
    );
  }

  if (kind === "ask-admin") {
    return (
      <>
        {children}
        <div className={cn("px-8 pb-8 text-sm text-[var(--sg-text-muted)]", centered && "text-center")}>
          {COPY.askAdmin}
        </div>
      </>
    );
  }

  return <>{children}</>;
}

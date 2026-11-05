"use client";

import { useAuth } from "@/components/auth";
import { DeepLink } from "@/components/navigation";
import { isTenantAdmin } from "@/lib/api/capabilities";
import { useTenant } from "@/contexts/TenantContext";

/**
 * Shown on the "Actual" basis when the tenant has no billed (FOCUS) data
 * loaded: the on-ramp to billing connections, with the expectation that
 * actuals are not instant -- cloud FOCUS exports deliver their first files
 * within about a day, then refresh daily.
 */
export function ActualsEmptyState() {
  const { user } = useAuth();
  const { currentTenant } = useTenant();
  return (
    <div className="flex flex-col items-center justify-center min-h-[280px] gap-3 text-center px-4 bg-[var(--sg-bg-1)] border border-dashed border-[var(--sg-border-light)] rounded-md">
      <div className="text-[var(--sg-text)] font-medium">No actual cost data yet</div>
      <div className="text-sm text-[var(--sg-text-muted)] max-w-lg">
        Point Stategraph at your cloud&apos;s FOCUS billing export and it will sync your actual
        spend, attribute it to the resources it manages, and show you what you&apos;re paying for
        that it doesn&apos;t manage. Expect the first actuals within a day or so of connecting —
        cloud exports deliver daily.
      </div>
      {/* Matches the gate on /billing-connections, which the link goes to. */}
      {isTenantAdmin(user?.capabilities, currentTenant?.id) ? (
        <DeepLink
          href="/billing-connections"
          className="px-3 py-1.5 text-sm font-medium rounded-md bg-[var(--sg-accent)] text-[var(--sg-bg-0)] hover:opacity-90"
        >
          Connect a billing export
        </DeepLink>
      ) : (
        <div className="text-xs text-[var(--sg-text-muted)]">
          Ask an admin to connect one under Billing connections.
        </div>
      )}
    </div>
  );
}

"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useLicense, useTenant } from "@/contexts";
import { useDedicatedAvailability } from "@/hooks";
import {
  AlertTriangle,
  ChevronDown,
  Check,
  Plus,
  Loader2,
  CircleAlert,
  CircleCheck,
  Minus,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { listDedicatedStategraphs, type Dedicated } from "@/lib/api/client";

// Statuses Aegis emits while a deployment is moving toward `active`. While
// any deployment is in one of these, the sidebar keeps polling so a new
// row appears or its status icon updates without a page reload. Once
// every deployment has settled (active / failed / suspended /
// pending_destroy / deleted), polling stops.
const IN_FLIGHT_STATUSES = new Set([
  "pending",
  "provisioning_project",
  "provisioning_database",
  "provisioning_secrets",
  "provisioning_services",
  "configuring_domain",
  "health_checking",
]);

/**
 * Sidebar tenant block + switcher (COMMUNISM mode only).
 *
 * One dropdown that surfaces every "place" the user can go:
 *   - their personal tenant (current context — never navigates away)
 *   - each dedicated Stategraph they've provisioned
 *   - "Create Dedicated Stategraph" CTA
 *
 * The trigger is intentionally thick — it's a substantial chrome block
 * so the user sees the personal-tenant warning, knows the dropdown
 * exists, and reads the count of dedicated instances at a glance.
 *
 * Click semantics: every dedicated row (regardless of status) navigates
 * to /provision?id=…; the provision status page is where the cross-origin
 * /claim?token=… handoff actually fires when the user clicks "Open". The
 * sidebar deliberately stays out of the handoff path so a stale dropdown
 * entry can't trigger a magic-link mint.
 *   - personal tenant row: no-op (already here); marked with a check
 *   - dedicated row (any status): /provision?id=…
 *   - Create: /provision
 *
 * Outside COMMUNISM mode the whole component is a no-op — self-hosted
 * and other deployments don't get this switcher.
 */
export function SidebarTenantSelector() {
  const router = useRouter();
  const { mode, isLoading: licenseLoading } = useLicense();
  const { capability: dedicatedCapability } = useDedicatedAvailability();
  const { currentTenant, isLoading: tenantLoading } = useTenant();
  const [dedicated, setDedicated] = useState<Dedicated[] | null>(null);

  // Default-off: until capabilities resolve, treat dedicated as disabled so the
  // whole block (warning chrome, dev/eval label, Create CTA) stays hidden
  // rather than flashing in.
  const dedicatedEnabled = dedicatedCapability?.enabled === true;

  useEffect(() => {
    if (mode !== "COMMUNISM" || !dedicatedEnabled) return;
    let cancelled = false;
    let handle: ReturnType<typeof setInterval> | null = null;

    const stopPolling = () => {
      if (handle !== null) {
        clearInterval(handle);
        handle = null;
      }
    };

    const fetchOnce = async () => {
      if (typeof document !== "undefined" && document.hidden) return;
      try {
        const resp = await listDedicatedStategraphs();
        if (cancelled) return;
        setDedicated(resp.results);
        // Stop polling once every deployment has reached a settled
        // state. A fresh provision (via the /provision form) re-mounts
        // this effect because the dropdown isn't where the new row
        // first appears, so re-arming on mount is the right hook.
        if (!resp.results.some((d) => IN_FLIGHT_STATUSES.has(d.status))) {
          stopPolling();
        }
      } catch {
        // Degrade silently — sidebar still works without the dedicated
        // list. If Aegis is down the user gets a clearer message when
        // they click Create. Keep prior data on transient errors so a
        // momentary blip doesn't wipe the list.
        if (cancelled) return;
        setDedicated((prev) => prev ?? []);
      }
    };

    // The console layout doesn't re-mount on `router.push`, so without
    // a poll a deployment that finishes after the user navigated away
    // from /provision wouldn't appear in the sidebar until a full
    // reload. 10s is plenty — provisioning is bounded to a few minutes.
    void fetchOnce();
    handle = setInterval(() => {
      void fetchOnce();
    }, 10_000);
    return () => {
      cancelled = true;
      stopPolling();
    };
  }, [mode, dedicatedEnabled]);

  if (mode !== "COMMUNISM" || !dedicatedEnabled) return null;
  if (licenseLoading || tenantLoading || !currentTenant) return null;

  const dedicatedCount = dedicated?.length ?? 0;
  const dedicatedActiveCount =
    dedicated?.filter((d) => d.status === "active").length ?? 0;
  const inFlight =
    dedicated?.filter((d) => IN_FLIGHT_STATUSES.has(d.status)) ?? [];
  const dedicatedInFlight = inFlight.length;

  const subtitle =
    dedicatedCount === 0
      ? "Personal · development & evaluation"
      : dedicatedInFlight > 0
        ? `Personal · ${dedicatedActiveCount} dedicated · ${dedicatedInFlight} provisioning`
        : `Personal · ${dedicatedActiveCount} dedicated`;

  return (
    <div className="mx-3 mt-3 mb-2">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button
            type="button"
            className="w-full group flex items-center gap-2.5 py-3 px-3 rounded-lg bg-[var(--sg-warning)]/8 border border-[var(--sg-warning)]/30 hover:bg-[var(--sg-warning)]/12 transition-colors text-left"
          >
            <AlertTriangle
              className="h-4 w-4 flex-shrink-0 text-[var(--sg-warning)]"
              aria-hidden="true"
            />
            <div className="flex-1 min-w-0">
              <div className="text-sm font-semibold text-[var(--sg-text)] truncate">
                {currentTenant.name}
              </div>
              <div className="text-[11px] text-[var(--sg-text-muted)] mt-0.5 leading-snug break-words">
                {subtitle}
              </div>
            </div>
            <ChevronDown
              className="h-4 w-4 flex-shrink-0 text-[var(--sg-text-muted)] group-hover:text-[var(--sg-text)] transition-colors"
              aria-hidden="true"
            />
          </button>
        </DropdownMenuTrigger>

        <DropdownMenuContent
          align="start"
          sideOffset={6}
          className="w-80 p-1.5 bg-[var(--sg-bg-1)] border-[var(--sg-border)]"
        >
          <DropdownMenuLabel className="text-[10px] uppercase tracking-wider text-[var(--sg-text-muted)] px-2 pt-1 pb-1.5 font-semibold">
            Personal
          </DropdownMenuLabel>

          <DropdownMenuItem
            disabled
            className="flex items-start gap-2.5 px-2.5 py-2.5 rounded-md cursor-default opacity-100 data-[disabled]:opacity-100 hover:bg-transparent focus:bg-transparent"
          >
            <AlertTriangle
              className="h-4 w-4 mt-0.5 flex-shrink-0 text-[var(--sg-warning)]"
              aria-hidden="true"
            />
            <div className="flex-1 min-w-0">
              <div className="text-sm font-semibold text-[var(--sg-text)] truncate">
                {currentTenant.name}
              </div>
              <div className="text-[11px] text-[var(--sg-text-muted)] mt-0.5 leading-snug">
                Development &amp; evaluation only.
              </div>
            </div>
            <Check
              className="h-4 w-4 mt-0.5 flex-shrink-0 text-[var(--sg-success)]"
              aria-hidden="true"
            />
          </DropdownMenuItem>

          {dedicatedCount > 0 && (
            <>
              <DropdownMenuSeparator className="bg-[var(--sg-border)] my-1.5" />
              <DropdownMenuLabel className="text-[10px] uppercase tracking-wider text-[var(--sg-text-muted)] px-2 pt-1 pb-1.5 font-semibold">
                Dedicated Stategraphs
              </DropdownMenuLabel>
              {dedicated!.map((d) => (
                <DedicatedDropdownItem
                  key={d.id}
                  dedicated={d}
                  onNavigate={(href) => router.push(href)}
                />
              ))}
            </>
          )}

          <DropdownMenuSeparator className="bg-[var(--sg-border)] my-1.5" />
          <DropdownMenuItem
            onSelect={() => router.push("/provision")}
            className="flex items-center gap-2.5 px-2.5 py-2.5 rounded-md cursor-pointer text-sm font-medium text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)] focus:bg-[var(--sg-bg-2)]"
          >
            <Plus className="h-4 w-4 text-[var(--sg-text-muted)]" aria-hidden="true" />
            Create Dedicated Stategraph
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      {inFlight.length > 0 && (
        <ProvisioningChip
          inFlight={inFlight}
          onNavigate={(href) => router.push(href)}
        />
      )}
    </div>
  );
}

const STATUS_LABEL: Record<string, string> = {
  pending: "Queued",
  provisioning_project: "Allocating project",
  provisioning_database: "Provisioning database",
  provisioning_secrets: "Wiring credentials",
  provisioning_services: "Starting service",
  configuring_domain: "Configuring domain",
  health_checking: "Verifying health",
  active: "Ready",
  failed: "Failed",
  suspended: "Suspended",
  pending_destroy: "Tearing down",
  deleted: "Deleted",
};

function DedicatedDropdownItem({
  dedicated,
  onNavigate,
}: {
  dedicated: Dedicated;
  onNavigate: (href: string) => void;
}) {
  const isActive = dedicated.status === "active" && !!dedicated.fqdn;
  const isFailed = dedicated.status === "failed";
  const isInFlight = IN_FLIGHT_STATUSES.has(dedicated.status);

  const statusLabel = STATUS_LABEL[dedicated.status] ?? dedicated.status;

  // Every row navigates to /provision?id=… — the status page is the
  // single source of truth for deployment info and is the only place
  // the Open / Destroy / etc. actions live. Cross-origin handoff
  // happens from there, never directly from the sidebar.
  function handleSelect() {
    onNavigate(`/provision?id=${encodeURIComponent(dedicated.id)}`);
  }

  return (
    <DropdownMenuItem
      onSelect={handleSelect}
      className="flex items-start gap-2.5 px-2.5 py-2.5 rounded-md cursor-pointer hover:bg-[var(--sg-bg-2)] focus:bg-[var(--sg-bg-2)]"
    >
      <StatusIcon status={dedicated.status} />
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium text-[var(--sg-text)] truncate">
          {dedicated.name}
        </div>
        <div className="text-[11px] text-[var(--sg-text-muted)] mt-0.5 truncate leading-tight">
          {isActive && dedicated.fqdn ? (
            <span className="font-mono">{dedicated.fqdn}</span>
          ) : (
            statusLabel
          )}
        </div>
      </div>
      {isActive && (
        <span className="text-[10px] uppercase tracking-wider font-semibold text-[var(--sg-success)] mt-1">
          Ready
        </span>
      )}
      {isInFlight && (
        <span className="text-[10px] uppercase tracking-wider font-semibold text-[var(--sg-warning)] mt-1">
          View
        </span>
      )}
      {isFailed && (
        <span className="text-[10px] uppercase tracking-wider font-semibold text-[var(--sg-error)] mt-1">
          View
        </span>
      )}
    </DropdownMenuItem>
  );
}

// Always-visible chip pinned below the tenant selector while at least one
// deployment is provisioning. The dropdown also lists in-flight rows, but
// that requires a click to discover; the chip surfaces the same signal
// without the user having to open the dropdown — addressing the "I hit
// Create and nothing showed up" feedback. State is reused from the
// existing 10s poll, so there's no second polling loop.
function ProvisioningChip({
  inFlight,
  onNavigate,
}: {
  inFlight: Dedicated[];
  onNavigate: (href: string) => void;
}) {
  const first = inFlight[0];
  const isSingle = inFlight.length === 1;

  const label = isSingle
    ? `Provisioning ${first.name}…`
    : `Provisioning ${inFlight.length} stategraphs…`;

  const statusLabel = STATUS_LABEL[first.status] ?? "Provisioning";

  function handleClick() {
    onNavigate(`/provision?id=${encodeURIComponent(first.id)}`);
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      title={isSingle ? statusLabel : "View provisioning status"}
      className="mt-1.5 w-full flex items-center gap-2 py-2 px-3 rounded-md bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30 hover:bg-[var(--sg-warning)]/18 transition-colors text-left"
    >
      <Loader2
        className="h-3.5 w-3.5 flex-shrink-0 text-[var(--sg-warning)] animate-spin"
        aria-hidden="true"
      />
      <span className="flex-1 min-w-0 text-xs font-medium text-[var(--sg-text)] truncate">
        {label}
      </span>
      <span className="text-[10px] uppercase tracking-wider font-semibold text-[var(--sg-warning)]">
        View
      </span>
    </button>
  );
}

function StatusIcon({ status }: { status: string }) {
  if (IN_FLIGHT_STATUSES.has(status)) {
    return (
      <Loader2
        className="h-4 w-4 mt-0.5 flex-shrink-0 text-[var(--sg-warning)] animate-spin"
        aria-hidden="true"
      />
    );
  }
  if (status === "failed") {
    return (
      <CircleAlert
        className="h-4 w-4 mt-0.5 flex-shrink-0 text-[var(--sg-error)]"
        aria-hidden="true"
      />
    );
  }
  if (status === "active") {
    return (
      <CircleCheck
        className="h-4 w-4 mt-0.5 flex-shrink-0 text-[var(--sg-success)]"
        aria-hidden="true"
      />
    );
  }
  // suspended / pending_destroy / deleted / anything else terminal: a
  // neutral dim icon rather than a misleading spinner or success check.
  return (
    <Minus
      className="h-4 w-4 mt-0.5 flex-shrink-0 text-[var(--sg-text-muted)]"
      aria-hidden="true"
    />
  );
}

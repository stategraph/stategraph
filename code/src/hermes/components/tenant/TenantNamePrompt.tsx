"use client";

import { useState, type ReactNode } from "react";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/components/auth";
import { useLicense, useTenant } from "@/contexts";
import { renameTenant } from "@/lib/api/client";
import { tenantNameErrorMessage } from "@/lib/api/tenantNameErrors";
import {
  MAX_TENANT_NAME,
  TENANT_NAME_RULE_MESSAGE,
  isReservedTenantName,
  isValidTenantName,
  markTenantNamingSeen,
  randomTenantName,
  shouldPromptForTenantName,
} from "@/lib/tenant-naming";
import { track } from "@/lib/analytics";

/**
 * Owns whether the first-run tenant naming page is due and renders it in
 * place of the console while it is.
 */
export function TenantNamingProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const { mode, isLoading: licenseLoading } = useLicense();
  const { currentTenant, tenants, isLoading: tenantLoading } = useTenant();
  const [done, setDone] = useState(false);

  const open =
    !done &&
    currentTenant !== null &&
    shouldPromptForTenantName({
      mode,
      licenseLoading,
      tenantLoading,
      user,
      currentTenant,
      tenantCount: tenants.length,
    });

  if (open) return <TenantNamePage tenantId={currentTenant.id} onDone={() => setDone(true)} />;
  return <>{children}</>;
}

/**
 * First-run tenant naming (#1772, COMMUNISM mode only). The OAuth callback
 * names the auto-created tenant after the user's display name or email; this
 * page replaces that with a chosen or suggested name before the console
 * opens. Shown once per tenant per browser; a rename here or in Settings
 * breaks the derived-name match for good.
 */
function TenantNamePage({ tenantId, onDone }: { tenantId: string; onDone: () => void }) {
  const { refreshTenants } = useTenant();
  const [name, setName] = useState(() => randomTenantName());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const trimmed = name.trim();
  const reserved = isReservedTenantName(trimmed);
  const valid = isValidTenantName(trimmed) && !reserved;

  const save = async () => {
    setSaving(true);
    setError(null);
    try {
      await renameTenant(tenantId, { name: trimmed });
      track("tenant_renamed", { source: "first_run_prompt" });
      markTenantNamingSeen(tenantId);
      // The rename has been accepted; a failed re-list must not read as a
      // failed rename. The console shows the old name until the next fetch.
      await refreshTenants().catch((err: unknown) => {
        console.error("[TenantNamePage] Failed to refresh tenants after rename:", err);
      });
      onDone();
    } catch (e: unknown) {
      setError(tenantNameErrorMessage(e, "Failed to rename tenant"));
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-[var(--sg-bg-0)] px-4 py-16">
      <form
        className="mx-auto flex w-full max-w-2xl flex-col gap-6"
        onSubmit={(e) => {
          e.preventDefault();
          if (!valid || saving) return;
          void save();
        }}
      >
        <div className="space-y-3">
          <div className="text-xs font-semibold uppercase tracking-wide text-[var(--sg-text-muted)]">
            Welcome to Stategraph
          </div>
          <h1 className="text-3xl font-semibold text-[var(--sg-text)]">Name your tenant</h1>
          <p className="max-w-prose text-base text-[var(--sg-text-muted)]">
            A tenant is the shared workspace for your team and its states. Pick a name your team
            will recognize. You can change it any time in Settings.
          </p>
        </div>
        <div className="space-y-4 rounded-xl border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-6">
          <div className="space-y-2">
            <Label htmlFor="tenant-name-prompt">Tenant name</Label>
            <div className="flex items-center gap-2">
              <Input
                id="tenant-name-prompt"
                value={name}
                onChange={(e) => setName(e.target.value)}
                maxLength={MAX_TENANT_NAME}
                autoFocus
                className="max-w-sm"
              />
              <Button
                type="button"
                variant="outline"
                onClick={() => setName(randomTenantName())}
                title="Suggest another name"
              >
                <RefreshCw className="h-4 w-4" aria-hidden="true" />
                Suggest another
              </Button>
            </div>
            <p className="text-xs text-[var(--sg-text-muted)]">{TENANT_NAME_RULE_MESSAGE}</p>
            {reserved && <p className="text-xs text-[var(--sg-error)]">That name is reserved.</p>}
            {!valid && !reserved && name.length > 0 && (
              <p className="text-xs text-[var(--sg-error)]">{TENANT_NAME_RULE_MESSAGE}</p>
            )}
            {error && <p className="text-xs text-[var(--sg-error)]">{error}</p>}
          </div>
          <div className="flex justify-end">
            <Button type="submit" size="lg" disabled={!valid || saving}>
              {saving ? "Saving..." : "Continue"}
            </Button>
          </div>
        </div>
      </form>
    </div>
  );
}

"use client";

import { useEffect, useState } from "react";
import { Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { renameTenant } from "@/lib/api/client";
import {
  tenantNameErrorMessage,
  tenantRenamedButUnlistedMessage,
} from "@/lib/api/tenantNameErrors";
import {
  MAX_TENANT_NAME,
  TENANT_NAME_RULE_MESSAGE,
  isValidTenantName,
} from "@/lib/tenant-naming";
import { useTenant } from "@/contexts";
import { track } from "@/lib/analytics";

/**
 * Rename the current tenant (#1773): a pencil button that opens a dialog with
 * the current and the new name. Rendered only for tenant admins — the endpoint
 * requires the admin capability, not users-manage.
 */
export function TenantRename({
  tenantId,
  tenantName,
}: {
  tenantId: string;
  tenantName: string;
}) {
  const { refreshTenants } = useTenant();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState(tenantName);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // The rename landed but the re-list did not, so the sidebar and the headers still say the old
  // name. Not an error -- the write happened -- so it is reported apart from `error`, and the
  // dialog stays open to show it.
  const [staleNotice, setStaleNotice] = useState<string | null>(null);

  // Start from the upstream name on every opening, and when the selection changes or a refresh
  // lands.
  useEffect(() => {
    setName(tenantName);
    setError(null);
    setStaleNotice(null);
  }, [open, tenantId, tenantName]);

  const trimmed = name.trim();
  const dirty = trimmed !== tenantName;
  const valid = isValidTenantName(name);

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setStaleNotice(null);
    try {
      const renamed = await renameTenant(tenantId, { name: trimmed });
      track("tenant_renamed", { source: "settings" });
      // refreshTenants() rejects on failure (its create-tenant caller needs the
      // fresh list). Here the rename has already been accepted by the server, so
      // a failed re-list must not be reported as a failed rename -- say what is
      // stale and let the next fetch pick the new name up.
      const refreshed = await refreshTenants().then(
        () => true,
        (err: unknown) => {
          console.error("[TenantRename] Failed to refresh tenants after rename:", err);
          setStaleNotice(tenantRenamedButUnlistedMessage(renamed.name));
          return false;
        }
      );
      if (refreshed) setOpen(false);
    } catch (e: unknown) {
      setError(tenantNameErrorMessage(e, "Failed to rename tenant"));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Rename tenant"
          title="Rename tenant"
          className="size-6 text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
        >
          <Pencil className="h-3.5 w-3.5" />
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[450px]">
        <DialogHeader>
          <DialogTitle>Rename tenant</DialogTitle>
          <DialogDescription>The new name shows everywhere the tenant is listed.</DialogDescription>
        </DialogHeader>
        <form onSubmit={(e) => void save(e)}>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="tenant-rename-current">Current name</Label>
              <Input id="tenant-rename-current" value={tenantName} disabled />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="tenant-rename-new">New name</Label>
              <Input
                id="tenant-rename-new"
                value={name}
                onChange={(e) => setName(e.target.value)}
                maxLength={MAX_TENANT_NAME}
                autoFocus
              />
              {!valid && name.length > 0 && (
                <p className="text-xs text-[var(--sg-error)]">{TENANT_NAME_RULE_MESSAGE}</p>
              )}
            </div>
            {error && <p className="text-xs text-[var(--sg-error)]">{error}</p>}
            {staleNotice && <p className="text-xs text-[var(--sg-warning)]">{staleNotice}</p>}
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setOpen(false)} disabled={saving}>
              {staleNotice ? "Close" : "Cancel"}
            </Button>
            <Button type="submit" disabled={!dirty || !valid || saving || staleNotice !== null}>
              {saving ? "Renaming..." : "Rename"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

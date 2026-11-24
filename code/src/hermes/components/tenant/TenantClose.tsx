"use client";

import { useState } from "react";
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
import { closeTenant } from "@/lib/api/client";
import { useTenant } from "@/contexts";
import { track } from "@/lib/analytics";

/**
 * Close the current tenant. Rendered only for tenant admins in Stategraph Cloud. A closed tenant
 * refuses every request but its reopen, and its data is deleted after 30 days.
 */
export function TenantClose({
  tenantId,
  tenantName,
}: {
  tenantId: string;
  tenantName: string;
}) {
  const { refreshTenants } = useTenant();
  const [open, setOpen] = useState(false);
  const [closing, setClosing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const close = async () => {
    setClosing(true);
    setError(null);
    try {
      await closeTenant(tenantId);
      track("tenant_closed", { source: "settings" });
      setOpen(false);
      await refreshTenants().catch((err: unknown) => {
        console.error(
          "[TenantClose] Failed to refresh tenants after close:",
          err,
        );
      });
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "The tenant could not be closed.",
      );
    } finally {
      setClosing(false);
    }
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next);
        setError(null);
      }}
    >
      <DialogTrigger asChild>
        <Button variant="destructive">Close tenant</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Close {tenantName}</DialogTitle>
          <DialogDescription>
            Members lose access to its states, transactions, and settings. You
            can reopen it from Settings for 30 days. After that, its data is
            deleted.
          </DialogDescription>
        </DialogHeader>
        {error && <p className="text-sm text-[var(--sg-error)]">{error}</p>}
        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => setOpen(false)}
            disabled={closing}
          >
            Cancel
          </Button>
          <Button variant="destructive" onClick={close} disabled={closing}>
            Close tenant
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

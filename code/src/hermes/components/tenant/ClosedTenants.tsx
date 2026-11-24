"use client";

import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import {
  listClosedTenants,
  reopenTenant,
  type ClosedTenant,
} from "@/lib/api/client";
import { useTenant } from "@/contexts";
import { track } from "@/lib/analytics";

/**
 * The closed tenants of the user, each with a reopen button. Rendered only in Stategraph Cloud.
 * The reopen endpoint requires the admin capability; a member who is not an admin gets its refusal.
 */
export function ClosedTenants() {
  const { refreshTenants } = useTenant();
  const [tenants, setTenants] = useState<ClosedTenant[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const r = await listClosedTenants();
      setTenants(r.results);
    } catch (err) {
      console.error("[ClosedTenants] Failed to list closed tenants:", err);
      setTenants([]);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const reopen = async (id: string) => {
    setBusy(id);
    setError(null);
    try {
      await reopenTenant(id);
      track("tenant_reopened", { source: "settings" });
      await load();
      await refreshTenants().catch((err: unknown) => {
        console.error(
          "[ClosedTenants] Failed to refresh tenants after reopen:",
          err,
        );
      });
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "The tenant could not be reopened.",
      );
    } finally {
      setBusy(null);
    }
  };

  if (!tenants || tenants.length === 0) return null;

  return (
    <div className="space-y-3">
      <p className="text-sm text-[var(--sg-text-muted)]">
        The data of a closed tenant is deleted 30 days after it was closed.
      </p>
      <ul className="divide-y divide-[var(--sg-border)]">
        {tenants.map((t) => (
          <li
            key={t.id}
            className="flex items-center justify-between gap-4 py-2"
          >
            <div className="text-sm">
              <div className="font-medium text-[var(--sg-text)]">{t.name}</div>
              <div className="text-[var(--sg-text-muted)]">
                Closed {t.ended_at.slice(0, 10)}
              </div>
            </div>
            <Button
              variant="outline"
              onClick={() => reopen(t.id)}
              disabled={busy !== null}
            >
              Reopen
            </Button>
          </li>
        ))}
      </ul>
      {error && <p className="text-sm text-[var(--sg-error)]">{error}</p>}
    </div>
  );
}

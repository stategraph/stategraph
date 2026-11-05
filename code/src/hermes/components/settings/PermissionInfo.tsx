"use client";

import { CopyButton } from "@/components/ui/copy-button";
import type { Capabilities } from "@/lib/api/capabilities";

/**
 * The signed-in session's raw capability record, for debugging.
 *
 * Rendered verbatim rather than through the {@link @/lib/api/capabilities} predicates on purpose:
 * when a screen or an endpoint refuses an action, what you need to see is exactly what the session
 * carries, not an interpretation of it. The shape matters as much as the keys — `{"admin": {}}` is
 * installation-wide, `{"admin": {"tenants": [...]}}` is scoped to those tenants, and an absent key
 * is no grant at all.
 *
 * These are the capabilities the *credential* carries, which is a snapshot taken when it was minted
 * and not necessarily what the user holds today: an API token keeps the capabilities it was created
 * with, so a stale-looking value here usually means the token predates a capability change.
 */
export function PermissionInfo({ capabilities }: { capabilities: Capabilities | undefined }) {
  const json = JSON.stringify(capabilities ?? {}, null, 2);

  return (
    <div className="space-y-4">
      <div className="space-y-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="text-sm font-semibold text-[var(--sg-text)]">Session Capabilities</div>
          <CopyButton text={json} />
        </div>
        <div className="text-xs text-[var(--sg-text-muted)]">
          What this session is allowed to do, as the server resolved it.
        </div>
      </div>

      {capabilities === undefined ? (
        <div className="text-sm text-[var(--sg-text-muted)]">Loading...</div>
      ) : (
        <pre className="text-xs font-mono bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded p-3 overflow-x-auto text-[var(--sg-text)]">
          {json}
        </pre>
      )}
    </div>
  );
}

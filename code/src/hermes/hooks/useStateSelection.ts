"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { useStates, useTenant } from "@/contexts";
import { useUrlFollowingState } from "./urlSyncedValue";

interface UseStateSelectionOptions {
  /** When true, "all" is a valid selection (default: true). */
  allowAll?: boolean;
}

/**
 * Drop-in replacement for the per-page `useState<string | null>(null)` +
 * auto-select pattern used with StateFilter.
 *
 * Reads the initial state from the `state` URL query param (if present),
 * auto-selects the first state if nothing is specified.
 *
 * Pass `{ allowAll: false }` on pages that only work with a single state.
 * When "all" would be selected, it falls back to the first available state.
 *
 * Usage:
 * ```tsx
 * const [selectedStateId, setSelectedStateId] = useStateSelection();
 * const [selectedStateId, setSelectedStateId] = useStateSelection({ allowAll: false });
 * ```
 */
export function useStateSelection(
  options?: UseStateSelectionOptions
): [string | null, (id: string | null) => void] {
  const { states, isLoading: statesLoading } = useStates();
  const { currentTenant } = useTenant();
  const searchParams = useSearchParams();
  const allowAll = options?.allowAll ?? true;

  // User's explicit selection, following the URL: a client navigation that
  // keeps this page mounted but changes ?state= is adopted.
  const [userSelection, setUserSelection, recordWrite] = useUrlFollowingState<string | null>(
    searchParams.get("state")
  );

  // State ids are tenant-scoped, so a pin cannot survive a tenant switch: it
  // would keep this page querying a state the new tenant cannot see. Reset
  // during render (the React adjust-on-prop-change pattern); the URL param is
  // already scrubbed by TenantContext.setCurrentTenant. Only an id-to-id
  // change counts: the initial null-to-id resolution is not a switch, which
  // keeps ?state= deep links working.
  const tenantId = currentTenant?.id ?? null;
  const [seenTenantId, setSeenTenantId] = useState<string | null>(tenantId);
  if (tenantId !== null && seenTenantId !== tenantId) {
    setSeenTenantId(tenantId);
    if (seenTenantId !== null) setUserSelection(null);
  }

  // Compute effective state ID derivatively:
  //   user selection (if any) > auto-select "all" (or first state) > null
  // Auto-selection does NOT write to the URL — only explicit selections do.
  let effectiveStateId: string | null = null;
  if (userSelection === "all") {
    effectiveStateId = allowAll ? "all" : (states[0]?.id ?? null);
  } else if (userSelection) {
    // Honor an explicit pin (URL ?state= or a user pick) even when it isn't in
    // the currently-loaded list — the list may still be loading, or be stale
    // after an out-of-band change (e.g. a state deleted via the CLI). Falling
    // back to states[0] here would silently desync the URL from the on-screen
    // selection, since effectiveStateId is derived and never written back.
    effectiveStateId = userSelection;
  } else if (!statesLoading && (states.length > 0 || allowAll)) {
    // A settled-empty tenant resolves to "all" rather than staying null:
    // consumers gate their fetch on a selection, and a permanent null leaves
    // every screen in its initial loading state instead of its empty state.
    effectiveStateId = allowAll ? "all" : (states[0]?.id ?? null);
  }

  // Setter updates user selection and syncs to URL
  function setSelectedStateId(id: string | null) {
    setUserSelection(id);
    if (syncStateToUrl(id)) recordWrite(id || null);
  }

  return [effectiveStateId, setSelectedStateId];
}

/** Update (or remove) the `state` query param in the URL without a navigation;
 *  true when the URL changed. */
function syncStateToUrl(stateId: string | null): boolean {
  if (typeof window === "undefined") return false;
  const url = new URL(window.location.href);
  const before = url.search;
  if (stateId) {
    url.searchParams.set("state", stateId);
  } else {
    url.searchParams.delete("state");
  }
  if (url.search === before) return false;
  window.history.replaceState(null, "", url.pathname + url.search);
  return true;
}

"use client";

import { useCallback, useState } from "react";
import { useAuth } from "@/components/auth";
import { useInitialLoad } from "@/hooks";
import {
  listVcsInstallations,
  type VcsInstallation,
} from "@/lib/api/client";
import { isTenantAdmin } from "@/lib/api/capabilities";
import { ORCHESTRATION_COPY } from "@/lib/getting-started/orchestration-constants";
import type { VcsProvider } from "@/lib/vcs/links";

export type InstallationListState =
  | { status: "loading"; rows: VcsInstallation[] }
  | { status: "ready"; rows: VcsInstallation[] }
  | { status: "forbidden"; rows: VcsInstallation[] }
  | { status: "error"; rows: VcsInstallation[]; message: string };

export type InstallationGate =
  | "loading"
  | "linked"
  | "empty"
  | "forbidden"
  | "error";

export function installationGateForProvider(
  state: InstallationListState,
  provider: VcsProvider | null,
): InstallationGate {
  if (state.status !== "ready") return state.status;
  const linked = provider
    ? state.rows.some((row) => row.provider === provider)
    : state.rows.length > 0;
  return linked ? "linked" : "empty";
}

export function useInstallationGate(
  tenantId: string,
  { enabled = true }: { enabled?: boolean } = {},
): {
  state: InstallationListState;
  refresh: () => Promise<void>;
} {
  const { isLoading: authLoading, user } = useAuth();
  const admin = isTenantAdmin(user?.capabilities, tenantId);
  const [state, setState] = useState<InstallationListState>({
    status: "loading",
    rows: [],
  });

  const refresh = useCallback(async (): Promise<void> => {
    // Until the session loads there are no capabilities to read, and an
    // admin must not flash "forbidden" in the meantime.
    if (!enabled || authLoading) return;
    // The list endpoint requires admin_tenant, so a member's call is a
    // guaranteed 403: answer it locally instead of spending the request.
    if (!admin) {
      setState({ status: "forbidden", rows: [] });
      return;
    }
    setState((previous) => ({ status: "loading", rows: previous.rows }));
    try {
      const response = await listVcsInstallations(tenantId);
      setState({ status: "ready", rows: response.results });
    } catch (error) {
      const status = (error as { status?: unknown } | null)?.status;
      if (status === 401 || status === 403) {
        setState({ status: "forbidden", rows: [] });
        return;
      }
      setState({
        status: "error",
        rows: [],
        message:
          error instanceof Error
            ? error.message
            : ORCHESTRATION_COPY.common.errorDetailFallback,
      });
    }
  }, [admin, authLoading, enabled, tenantId]);

  // `refresh` is a no-op while disabled or while the session loads, and its
  // identity changes with those and with `admin` and `tenantId`, so enabling,
  // the session loading or switching tenant reloads.
  useInitialLoad(refresh);

  return { state, refresh };
}

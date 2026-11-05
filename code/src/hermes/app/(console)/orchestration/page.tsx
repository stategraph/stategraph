"use client";

import { HubRedirect } from "@/components/navigation";

/** Where each tab of the retired /orchestration hub lives now. Remaining
 *  query params (filters, deep-link context) carry over unchanged. */
const TAB_ROUTE: Record<string, string> = {
  runs: "/runs",
  "pull-requests": "/pull-requests",
  repositories: "/repositories",
  workspaces: "/workspaces",
  stacks: "/stacks",
  drift: "/drift",
  "state-changes": "/state-changes",
  audit: "/audit",
};

/**
 * The orchestration screens are real routes with their own sidebar entries;
 * this page only redirects. `?tab=` URLs from the old hub map to the standalone
 * routes; the bare URL always lands on Runs.
 */
export default function OrchestrationPage() {
  return <HubRedirect tabRoutes={TAB_ROUTE} defaultPath="/runs" />;
}

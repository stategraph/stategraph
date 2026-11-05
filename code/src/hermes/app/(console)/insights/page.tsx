"use client";

import { HubRedirect } from "@/components/navigation";

// Tab ids of the retired Insights hub.
const TAB_ROUTE: Record<string, string> = {
  "timeline": "/timeline",
  "search": "/search",
  "blast-radius": "/blast-radius",
  "graph": "/graph-explorer",
};

export default function InsightsPage() {
  return <HubRedirect tabRoutes={TAB_ROUTE} defaultPath="/timeline" />;
}

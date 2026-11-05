"use client";

import { HubRedirect } from "@/components/navigation";

// Tab ids of the retired Analyze hub.
const TAB_ROUTE: Record<string, string> = {
  "query": "/query",
  "dashboards": "/dashboards",
};

export default function AnalyzePage() {
  return <HubRedirect tabRoutes={TAB_ROUTE} defaultPath="/query" />;
}

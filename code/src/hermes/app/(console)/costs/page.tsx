"use client";

import { HubRedirect } from "@/components/navigation";

// Tab ids of the retired Costs hub.
const TAB_ROUTE: Record<string, string> = {
  "overview": "/cost-overview",
  "explorer": "/cost-explorer",
  "analysis": "/cost-analysis",
  "budgets": "/cost-budgets",
  "policies": "/cost-policies",
  "optimization": "/cost-optimization",
  "connections": "/billing-connections",
};

export default function CostsPage() {
  return <HubRedirect tabRoutes={TAB_ROUTE} defaultPath="/cost-overview" />;
}

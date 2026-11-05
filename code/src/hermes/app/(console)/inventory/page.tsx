"use client";

import { HubRedirect } from "@/components/navigation";

// Tab ids of the retired Inventory hub.
const TAB_ROUTE: Record<string, string> = {
  "resources": "/instances",
  "modules": "/modules",
  "types": "/types",
  "gaps": "/gap-analysis",
};

export default function InventoryPage() {
  return <HubRedirect tabRoutes={TAB_ROUTE} defaultPath="/instances" />;
}

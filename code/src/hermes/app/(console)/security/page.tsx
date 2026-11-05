"use client";

import { HubRedirect } from "@/components/navigation";

// Tab ids of the retired Security hub.
const TAB_ROUTE: Record<string, string> = {
  "overview": "/security/overview",
  "findings": "/security/findings",
};

export default function SecurityPage() {
  return <HubRedirect tabRoutes={TAB_ROUTE} defaultPath="/security/overview" />;
}

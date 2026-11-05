"use client";

import { useTenant } from "@/contexts";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { track } from "@/lib/analytics";

export function TenantSelector() {
  const { currentTenant, tenants, setCurrentTenant, isLoading } = useTenant();

  if (isLoading) {
    return (
      <div
        className="flex items-center gap-2 h-9 px-3 rounded-[var(--sg-button-radius)] text-sm font-medium animate-pulse"
        style={{
          background: "var(--sg-bg-2)",
          border: "1px solid var(--sg-border)",
          color: "var(--sg-text-dim)",
        }}
      >
        <span>Loading...</span>
      </div>
    );
  }

  if (tenants.length === 0) {
    return (
      <div
        className="flex items-center gap-2 h-9 px-3 rounded-[var(--sg-button-radius)] text-sm font-medium"
        style={{
          background: "var(--sg-bg-2)",
          border: "1px solid var(--sg-border)",
          color: "var(--sg-text-dim)",
        }}
      >
        <span>No Tenants</span>
      </div>
    );
  }

  return (
    <Select
      value={currentTenant?.id || ""}
      onValueChange={(value) => {
        const tenant = tenants.find((t) => t.id === value);
        if (tenant) {
          track("tenant_switched", { to_tenant_id: tenant.id, source: "sidebar" });
          setCurrentTenant(tenant);
        }
      }}
    >
      <SelectTrigger
        className="h-9 w-full gap-2"
        style={{
          background: "var(--sg-bg-2)",
          borderColor: "var(--sg-border)",
          color: "var(--sg-text)",
        }}
      >
        <SelectValue placeholder="Select Tenant" />
      </SelectTrigger>
      <SelectContent>
        {tenants.map((tenant) => (
          <SelectItem
            key={tenant.id}
            value={tenant.id}
          >
            {tenant.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}

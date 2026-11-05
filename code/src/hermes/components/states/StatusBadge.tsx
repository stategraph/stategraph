// State status badge component
// Displays state health status with color coding and clear visual hierarchy

import type { StateStatus } from "@/lib/states/adapter";
import { cn } from "@/lib/utils";

interface StatusBadgeProps {
  status: StateStatus;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const variants: Record<
    StateStatus,
    { bg: string; text: string; border: string }
  > = {
    Healthy: {
      bg: "bg-[var(--sg-status-healthy-bg)]",
      text: "text-[var(--sg-status-healthy-text)]",
      border: "border-[var(--sg-status-healthy-border)]",
    },
    "Drift detected": {
      bg: "bg-[var(--sg-status-drift-bg)]",
      text: "text-[var(--sg-status-drift-text)]",
      border: "border-[var(--sg-status-drift-border)]",
    },
    Locked: {
      bg: "bg-[var(--sg-status-locked-bg)]",
      text: "text-[var(--sg-status-locked-text)]",
      border: "border-[var(--sg-status-locked-border)]",
    },
    Failed: {
      bg: "bg-[var(--sg-status-failed-bg)]",
      text: "text-[var(--sg-status-failed-text)]",
      border: "border-[var(--sg-status-failed-border)]",
    },
  };

  const variant = variants[status];

  return (
    <span
      className={cn(
        "inline-flex items-center whitespace-nowrap rounded-md border px-2 py-0.5 text-xs font-medium",
        variant.bg,
        variant.text,
        variant.border,
        className
      )}
    >
      {status}
    </span>
  );
}

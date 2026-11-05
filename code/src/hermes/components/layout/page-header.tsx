import { cn } from "@/lib/utils";
import type { ProductStatus } from "@/config/products";

interface PageHeaderProps {
  title: string;
  description?: string;
  status?: ProductStatus;
  actions?: React.ReactNode;
  className?: string;
}

export function PageHeader({
  title,
  description,
  status,
  actions,
  className,
}: PageHeaderProps) {
  return (
    <div className={cn("flex items-start justify-between mb-6", className)}>
      <div className="space-y-1">
        <div className="flex items-center gap-3">
          <h1 className="text-3xl font-bold tracking-tight text-[var(--sg-text)]">{title}</h1>
          {status && <StatusBadge status={status} />}
        </div>
        {description && (
          <p className="text-[var(--sg-text-muted)]">{description}</p>
        )}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}

interface StatusBadgeProps {
  status: ProductStatus;
}

function StatusBadge({ status }: StatusBadgeProps) {
  const styles = {
    available: "bg-[var(--sg-accent-bg)] text-[var(--sg-accent)] border-[var(--sg-accent)]",
    coming_soon: "bg-[var(--sg-bg-2)] text-[var(--sg-text-dim)] border-[var(--sg-border)]",
  };

  const labels = {
    available: "Available",
    coming_soon: "Coming Soon",
  };

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-[var(--sg-radius-xs)] border px-2.5 py-0.5 text-xs font-semibold",
        styles[status]
      )}
    >
      {labels[status]}
    </span>
  );
}

import { Product } from "@/config/products";
import { PageHeader } from "@/components/page/PageHeader";
import { PageSection } from "@/components/page/PageSection";
import { PageSurface } from "@/components/page/PageSurface";
import { Button } from "@/components/ui/button";
import { ArrowRight, type LucideIcon } from "lucide-react";
import { DeepLink } from "@/components/navigation";

// ============================================================================
// Types
// ============================================================================

export interface ProductMetric {
  label: string;
  value: number | string;
  icon: LucideIcon;
  trend?: {
    value: number;
    direction: "up" | "down" | "neutral";
  };
}

export interface QuickAction {
  label: string;
  onClick: () => void;
  icon: LucideIcon;
  variant?: "default" | "outline" | "secondary";
}

export interface ProductHomeTemplateProps {
  product: Product;
  metrics?: ProductMetric[];
  quickActions?: QuickAction[];
  explorerHref?: string;
  children?: React.ReactNode;
}

// ============================================================================
// Component
// ============================================================================

export function ProductHomeTemplate({
  product,
  metrics,
  quickActions,
  explorerHref,
  children,
}: ProductHomeTemplateProps) {
  const Icon = product.icon;

  return (
    <div className="flex flex-col w-full">
      {/* Page Header */}
      <PageHeader
        title={product.label}
        subtitle={product.description}
      />

      {/* Hero Section */}
      <PageSection>
        <PageSurface className="p-8">
          <div className="flex items-start gap-6">
            {/* Icon */}
            <div
              className="w-16 h-16 rounded-lg flex items-center justify-center flex-shrink-0"
              style={{
                background: "var(--sg-accent-bg)",
                border: "2px solid var(--sg-border)",
              }}
            >
              <Icon
                className="w-8 h-8"
                style={{ color: "var(--sg-accent)" }}
              />
            </div>

            {/* Content */}
            <div className="flex-1">
              <h2
                className="text-2xl font-bold mb-2"
                style={{ color: "var(--sg-text)" }}
              >
                {product.label}
              </h2>
              <p
                className="text-base mb-4"
                style={{ color: "var(--sg-text-muted)" }}
              >
                {product.description}
              </p>

              {/* Explorer CTA */}
              {explorerHref && (
                <DeepLink href={explorerHref}>
                  <Button
                    variant="default"
                    size="sm"
                    className="gap-2"
                  >
                    Open {product.label}
                    <ArrowRight className="w-4 h-4" />
                  </Button>
                </DeepLink>
              )}
            </div>
          </div>
        </PageSurface>
      </PageSection>

      {/* Metrics Section */}
      {metrics && metrics.length > 0 && (
        <PageSection title="Key Metrics">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {metrics.map((metric, index) => (
              <MetricCard
                key={index}
                metric={metric}
              />
            ))}
          </div>
        </PageSection>
      )}

      {/* Quick Actions Section */}
      {quickActions && quickActions.length > 0 && (
        <PageSection title="Quick Actions">
          <PageSurface className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {quickActions.map((action, index) => (
                <QuickActionButton
                  key={index}
                  action={action}
                />
              ))}
            </div>
          </PageSurface>
        </PageSection>
      )}

      {/* Custom Content */}
      {children && <PageSection>{children}</PageSection>}
    </div>
  );
}

// ============================================================================
// Helper Components
// ============================================================================

function MetricCard({ metric }: { metric: ProductMetric }) {
  const Icon = metric.icon;

  return (
    <PageSurface className="p-4">
      <div className="flex items-start justify-between mb-2">
        <div
          className="w-10 h-10 rounded-md flex items-center justify-center"
          style={{ background: "var(--sg-bg-1)" }}
        >
          <Icon
            className="w-5 h-5"
            style={{ color: "var(--sg-text-muted)" }}
          />
        </div>
        {metric.trend && (
          <div
            className="text-xs font-medium"
            style={{
              color:
                metric.trend.direction === "up"
                  ? "var(--sg-success)"
                  : metric.trend.direction === "down"
                    ? "var(--sg-error)"
                    : "var(--sg-text-muted)",
            }}
          >
            {metric.trend.direction === "up" && "↑"}
            {metric.trend.direction === "down" && "↓"}
            {metric.trend.value}%
          </div>
        )}
      </div>
      <div
        className="text-2xl font-bold mb-1"
        style={{ color: "var(--sg-text)" }}
      >
        {typeof metric.value === "number"
          ? metric.value.toLocaleString()
          : metric.value}
      </div>
      <div
        className="text-sm"
        style={{ color: "var(--sg-text-muted)" }}
      >
        {metric.label}
      </div>
    </PageSurface>
  );
}

function QuickActionButton({ action }: { action: QuickAction }) {
  const Icon = action.icon;

  return (
    <Button
      variant={action.variant || "outline"}
      size="sm"
      onClick={action.onClick}
      className="justify-start gap-2 h-auto py-3"
    >
      <Icon className="w-4 h-4" />
      {action.label}
    </Button>
  );
}

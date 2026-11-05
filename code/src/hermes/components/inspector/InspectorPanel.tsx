"use client";

import { useEffect } from "react";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";
import { useInspector } from "./useInspector";

/**
 * Extract short provider name from full Terraform provider string
 * Example: provider["registry.terraform.io/hashicorp/aws"] -> hashicorp/aws
 */
function getShortProviderName(provider: string): string {
  // Match the pattern: provider[".../.../..."]
  const match = provider.match(/provider\["[^/]+\/([^/]+\/[^"]+)"\]/);
  if (match && match[1]) {
    return match[1];
  }
  // Fallback: return as-is if pattern doesn't match
  return provider;
}

/**
 * InspectorSection - Reusable section component for the inspector
 */
function InspectorSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="border-b border-[var(--sg-border)] pb-4 mb-4 last:border-b-0">
      <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] mb-3">
        {title}
      </h3>
      <div className="space-y-2">{children}</div>
    </div>
  );
}

/**
 * InfoRow - Displays a label-value pair
 */
function InfoRow({ label, value }: { label: string; value?: string | number }) {
  if (!value) return null;

  return (
    <div className="flex flex-col gap-0.5">
      <div className="text-xs text-[var(--sg-text-muted)]">{label}</div>
      <div className="text-sm text-[var(--sg-text)] font-mono break-all">
        {value}
      </div>
    </div>
  );
}

/**
 * TagRow - Displays a single tag key-value pair
 */
function TagRow({ tag, value }: { tag: string; value: string }) {
  return (
    <div className="flex items-center gap-2 text-xs">
      <span className="text-[var(--sg-text-muted)] font-mono">{tag}</span>
      <span className="text-[var(--sg-text-dim)]">=</span>
      <span className="text-[var(--sg-text)] font-mono">{value}</span>
    </div>
  );
}

/**
 * MetricRow - Displays a graph metric
 */
function MetricRow({ label, count }: { label: string; count?: number }) {
  if (count === undefined) return null;

  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-[var(--sg-text-muted)]">{label}</span>
      <span className="text-[var(--sg-text)] font-semibold font-mono">
        {count}
      </span>
    </div>
  );
}

/**
 * InspectorPanel - Right-side panel for displaying resource details
 */
export function InspectorPanel() {
  const { isOpen, resource, closeInspector } = useInspector();

  // Close inspector with Escape key
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeInspector();
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isOpen, closeInspector]);

  // Don't render anything if inspector is closed or no resource
  if (!isOpen || !resource) {
    return null;
  }

  return (
    <>
      {/* Backdrop — mobile/tablet only, dismisses the sheet on tap */}
      <div
        className="fixed inset-0 z-40 bg-black/50 lg:hidden"
        onClick={closeInspector}
        aria-hidden="true"
      />
      <aside
        className={cn(
          "flex flex-col bg-[var(--sg-bg-2)] border-l border-[var(--sg-border)]",
          "w-[var(--sg-inspector-width)] max-w-[90vw]",
          // Off-canvas sheet on mobile/tablet …
          "fixed inset-y-0 right-0 z-50",
          // … static side column on lg+
          "lg:static lg:z-auto lg:max-w-none"
        )}
      >
      {/* Header */}
      <div className="sticky top-0 bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] px-4 py-3 flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="text-sm font-mono text-[var(--sg-text)] break-all mb-1">
            {resource.address}
          </div>
          <div className="text-xs text-[var(--sg-text-muted)] flex items-center gap-2">
            <span>{resource.type}</span>
            {resource.provider && (
              <>
                <span className="text-[var(--sg-text-dim)]">•</span>
                <span>{getShortProviderName(resource.provider)}</span>
              </>
            )}
          </div>
        </div>
        <button
          onClick={closeInspector}
          className="flex-shrink-0 p-1 rounded-[var(--sg-radius-xs)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)] transition-colors"
          aria-label="Close inspector"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      {/* Body */}
      <div className="flex-1 overflow-y-auto p-4">
        {/* Overview Section */}
        <InspectorSection title="Overview">
          <InfoRow label="Address" value={resource.address} />
          <InfoRow label="Type" value={resource.type} />
          <InfoRow label="Module Path" value={resource.modulePath} />
          {resource.summary && (
            <div className="flex flex-col gap-0.5 pt-2">
              <div className="text-xs text-[var(--sg-text-muted)]">Summary</div>
              <div className="text-sm text-[var(--sg-text)]">
                {resource.summary}
              </div>
            </div>
          )}
        </InspectorSection>

        {/* Graph Section */}
        {(resource.dependencyCount !== undefined ||
          resource.dependentCount !== undefined ||
          resource.instanceCount !== undefined) && (
          <InspectorSection title="Graph">
            <MetricRow label="Dependencies" count={resource.dependencyCount} />
            <MetricRow label="Dependents" count={resource.dependentCount} />
            <MetricRow label="Resources" count={resource.instanceCount} />
          </InspectorSection>
        )}

        {/* Tags Section */}
        {resource.tags && Object.keys(resource.tags).length > 0 && (
          <InspectorSection title="Tags">
            {Object.entries(resource.tags).map(([key, value]) => (
              <TagRow key={key} tag={key} value={value} />
            ))}
          </InspectorSection>
        )}

        {/* Attributes Section */}
        {resource.attributes && Object.keys(resource.attributes).length > 0 && (
          <InspectorSection title="Attributes">
            {Object.entries(resource.attributes)
              .filter(([key]) => key !== 'tags') // Don't duplicate tags
              .map(([key, value]) => {
                // Format the value for display
                let displayValue: string;
                if (value === null || value === undefined) {
                  displayValue = '(empty)';
                } else if (typeof value === 'object') {
                  displayValue = JSON.stringify(value, null, 2);
                } else {
                  displayValue = String(value);
                }

                return (
                  <div key={key} className="flex flex-col gap-0.5">
                    <div className="text-xs text-[var(--sg-text-muted)]">{key}</div>
                    <div className="text-sm text-[var(--sg-text)] font-mono break-all whitespace-pre-wrap">
                      {displayValue}
                    </div>
                  </div>
                );
              })}
          </InspectorSection>
        )}
      </div>
      </aside>
    </>
  );
}

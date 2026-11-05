"use client";

import { Module } from "@/lib/api/client";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Box, Eye, GitBranch, Layers, Info, DollarSign } from "lucide-react";
import { formatCurrency } from "@/lib/cost/format";

interface ModuleCardProps {
  module: Module;
  onViewInstances: (moduleName: string) => void;
  onOpenInspector: (module: Module) => void;
  isSelected?: boolean;
  monthlyCost?: number;
  currency?: string;
}

export function ModuleCard({
  module,
  onViewInstances,
  onOpenInspector,
  isSelected = false,
  monthlyCost,
  currency,
}: ModuleCardProps) {
  // Format module name for display (show last segment if nested)
  const displayName = module.name === "root"
    ? "Root Module"
    : module.name.split('.').filter(s => s !== 'module').pop() || module.name;

  // Get module depth indicator
  const depth = module.name === "root" ? 0 : module.name.split('.').filter(s => s === 'module').length;

  return (
    <div
      className={`
        sg-card p-4 transition-colors duration-150
        hover:border-[var(--sg-accent)]
        cursor-pointer
        ${isSelected ? 'ring-2 ring-[var(--sg-accent)] bg-[var(--sg-accent-bg)]' : ''}
      `}
      onClick={() => onOpenInspector(module)}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <Box className="h-4 w-4 text-[var(--sg-accent)] flex-shrink-0" />
          <div className="flex-1 min-w-0">
            <div className="sg-secondary-header truncate" title={module.name}>
              {displayName}
            </div>
            {module.name !== "root" && (
              <div className="sg-metadata text-[var(--sg-text-dim)] truncate mt-0.5" title={module.name}>
                {module.name}
              </div>
            )}
          </div>
        </div>
        {depth > 0 && (
          <Badge variant="outline" className="flex-shrink-0 ml-2">
            L{depth}
          </Badge>
        )}
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 mb-3">
        <div className="flex items-center gap-2">
          <Layers className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
          <div>
            <div className="sg-numeric-value text-sm">{module.instance_count.toLocaleString()}</div>
            <div className="sg-metadata text-[var(--sg-text-dim)]">Resources</div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <GitBranch className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
          <div>
            <div className="sg-numeric-value text-sm">{module.resource_count.toLocaleString()}</div>
            <div className="sg-metadata text-[var(--sg-text-dim)]">Resources</div>
          </div>
        </div>
      </div>

      {typeof monthlyCost === "number" && (
        <div className="flex items-center gap-2 mb-3">
          <DollarSign className="h-3.5 w-3.5 text-[var(--sg-text-dim)]" />
          <div>
            <div className="sg-numeric-value text-sm">
              {formatCurrency(monthlyCost, currency ?? "")}
            </div>
            <div className="sg-metadata text-[var(--sg-text-dim)]">Monthly cost</div>
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-2 pt-3 border-t border-[var(--sg-border)]">
        <Button
          variant="outline"
          size="sm"
          className="flex-1 min-w-0"
          onClick={(e) => {
            e.stopPropagation();
            onViewInstances(module.name);
          }}
        >
          <Eye className="h-3.5 w-3.5 mr-1.5 flex-shrink-0" />
          <span className="truncate">View Resources</span>
        </Button>
        <Button
          variant="ghost"
          size="sm"
          className="flex-shrink-0"
          onClick={(e) => {
            e.stopPropagation();
            onOpenInspector(module);
          }}
          title="View details"
        >
          <Info className="h-3.5 w-3.5" />
        </Button>
      </div>
    </div>
  );
}

// Loading skeleton
export function ModuleCardSkeleton() {
  return (
    <div className="sg-card p-4">
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2 flex-1">
          <div className="h-4 w-4 bg-[var(--sg-bg-0)] rounded animate-pulse" />
          <div className="flex-1 space-y-2">
            <div className="h-4 bg-[var(--sg-bg-0)] rounded w-3/4 animate-pulse" />
            <div className="h-3 bg-[var(--sg-bg-0)] rounded w-1/2 animate-pulse" />
          </div>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3 mb-3">
        <div className="h-12 bg-[var(--sg-bg-0)] rounded animate-pulse" />
        <div className="h-12 bg-[var(--sg-bg-0)] rounded animate-pulse" />
      </div>
      <div className="flex gap-2 pt-3 border-t border-[var(--sg-border)]">
        <div className="h-8 bg-[var(--sg-bg-0)] rounded flex-1 animate-pulse" />
        <div className="h-8 bg-[var(--sg-bg-0)] rounded w-20 animate-pulse" />
      </div>
    </div>
  );
}

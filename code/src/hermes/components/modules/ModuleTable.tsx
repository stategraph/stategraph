"use client";

import { Module } from "@/lib/api/client";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Eye, Info } from "lucide-react";
import { formatCurrency } from "@/lib/cost/format";

interface ModuleTableProps {
  modules: Module[];
  onViewInstances: (moduleName: string) => void;
  onOpenInspector: (module: Module) => void;
  selectedModule?: Module | null;
  isLoading?: boolean;
  costByModule?: Map<string, number>;
  costCurrency?: string;
}

export function ModuleTable({
  modules,
  onViewInstances,
  onOpenInspector,
  selectedModule,
  isLoading = false,
  costByModule,
  costCurrency,
}: ModuleTableProps) {
  if (isLoading) {
    return <ModuleTableSkeleton />;
  }

  return (
    <>
    {/* Desktop / tablet table (lg+) */}
    <div className="hidden lg:block sg-card overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
            <th className="text-left p-3 sg-metadata font-medium text-[var(--sg-text)]">Module Path</th>
            <th className="text-left p-3 sg-metadata font-medium text-[var(--sg-text)]">Level</th>
            <th className="text-right p-3 sg-metadata font-medium text-[var(--sg-text)]">Resources</th>
            <th className="text-right p-3 sg-metadata font-medium text-[var(--sg-text)]">Resource Types</th>
            {costByModule && (
              <th className="text-right p-3 sg-metadata font-medium text-[var(--sg-text)]">Monthly cost</th>
            )}
            <th className="text-right p-3 sg-metadata font-medium text-[var(--sg-text)]">Actions</th>
          </tr>
        </thead>
        <tbody>
          {modules.map((module) => {
            const isSelected = selectedModule?.name === module.name;
            const depth = module.name === "root" ? 0 : module.name.split('.').filter(s => s === 'module').length;
            const displayName = module.name === "root" ? "Root Module" : module.name;
            const moduleCost = costByModule?.get(module.name);

            return (
              <tr
                key={module.name}
                className={`
                  border-b transition-colors duration-150
                  hover:bg-[var(--sg-bg-2)] cursor-pointer
                  ${isSelected
                    ? 'bg-[var(--sg-accent-bg)] border-[var(--sg-accent)]'
                    : 'border-[var(--sg-border)]'}
                `}
                onClick={() => onOpenInspector(module)}
              >
                <td className="p-3">
                  <div className="sg-secondary-header font-mono">{displayName}</div>
                </td>
                <td className="p-3">
                  {depth > 0 && (
                    <Badge variant="outline" className="sg-metadata">
                      Level {depth}
                    </Badge>
                  )}
                </td>
                <td className="p-3 text-right">
                  <span className="sg-numeric-value text-sm">
                    {module.instance_count.toLocaleString()}
                  </span>
                </td>
                <td className="p-3 text-right">
                  <span className="sg-numeric-value text-sm">
                    {module.resource_count.toLocaleString()}
                  </span>
                </td>
                {costByModule && (
                  <td className="p-3 text-right">
                    <span className="sg-numeric-value text-sm">
                      {typeof moduleCost === "number"
                        ? formatCurrency(moduleCost, costCurrency ?? "")
                        : "—"}
                    </span>
                  </td>
                )}
                <td className="p-3">
                  <div className="flex gap-2 justify-end">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) => {
                        e.stopPropagation();
                        onViewInstances(module.name);
                      }}
                      title="View resources in this module"
                    >
                      <Eye className="h-3.5 w-3.5 mr-1.5" />
                      Resources
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) => {
                        e.stopPropagation();
                        onOpenInspector(module);
                      }}
                      title="Open inspector panel"
                    >
                      <Info className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>

    {/* Mobile / small-screen card list (below lg) */}
    <div className="lg:hidden space-y-3">
      {modules.map((module) => {
        const isSelected = selectedModule?.name === module.name;
        const depth = module.name === "root" ? 0 : module.name.split('.').filter(s => s === 'module').length;
        const displayName = module.name === "root" ? "Root Module" : module.name;
        const moduleCost = costByModule?.get(module.name);

        return (
          <div
            key={module.name}
            onClick={() => onOpenInspector(module)}
            className={`rounded-lg border p-3 cursor-pointer transition-colors ${
              isSelected
                ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                : 'border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:bg-[var(--sg-bg-2)]'
            }`}
          >
            <div className="flex items-start justify-between gap-2">
              <div className="sg-secondary-header font-mono break-all min-w-0">{displayName}</div>
              {depth > 0 && (
                <Badge variant="outline" className="sg-metadata flex-shrink-0">
                  Level {depth}
                </Badge>
              )}
            </div>

            <div className="mt-3 grid grid-cols-2 gap-3">
              <div>
                <div className="sg-metadata text-[var(--sg-text-dim)]">Resources</div>
                <div className="sg-numeric-value text-sm">{module.instance_count.toLocaleString()}</div>
              </div>
              <div>
                <div className="sg-metadata text-[var(--sg-text-dim)]">Resource Types</div>
                <div className="sg-numeric-value text-sm">{module.resource_count.toLocaleString()}</div>
              </div>
              {costByModule && (
                <div>
                  <div className="sg-metadata text-[var(--sg-text-dim)]">Monthly cost</div>
                  <div className="sg-numeric-value text-sm">
                    {typeof moduleCost === "number"
                      ? formatCurrency(moduleCost, costCurrency ?? "")
                      : "—"}
                  </div>
                </div>
              )}
            </div>

            <div className="mt-3 flex gap-2 pt-3 border-t border-[var(--sg-border)]">
              <Button
                variant="outline"
                size="sm"
                className="flex-1 min-w-0"
                onClick={(e) => {
                  e.stopPropagation();
                  onViewInstances(module.name);
                }}
                title="View resources in this module"
              >
                <Eye className="h-3.5 w-3.5 mr-1.5 flex-shrink-0" />
                <span className="truncate">Resources</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="flex-shrink-0"
                onClick={(e) => {
                  e.stopPropagation();
                  onOpenInspector(module);
                }}
                title="Open inspector panel"
              >
                <Info className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        );
      })}
    </div>
    </>
  );
}

function ModuleTableSkeleton() {
  return (
    <>
    {/* Mobile skeleton (below lg) */}
    <div className="lg:hidden space-y-3">
      {Array.from({ length: 6 }).map((_, i) => (
        <div key={i} className="sg-card p-3 space-y-2">
          <div className="h-4 bg-[var(--sg-bg-0)] rounded w-2/3 sg-skeleton-shimmer" />
          <div className="h-3 bg-[var(--sg-bg-0)] rounded w-1/3 sg-skeleton-shimmer" />
        </div>
      ))}
    </div>

    {/* Desktop / tablet skeleton (lg+) */}
    <div className="hidden lg:block sg-card overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
            <th className="text-left p-3 sg-metadata">Module Path</th>
            <th className="text-left p-3 sg-metadata">Level</th>
            <th className="text-right p-3 sg-metadata">Resources</th>
            <th className="text-right p-3 sg-metadata">Resource Types</th>
            <th className="text-right p-3 sg-metadata">Actions</th>
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: 10 }).map((_, i) => (
            <tr key={i} className="border-b border-[var(--sg-border)]">
              <td className="p-3">
                <div className="h-4 bg-[var(--sg-bg-0)] rounded w-64 sg-skeleton-shimmer" />
              </td>
              <td className="p-3">
                <div className="h-6 bg-[var(--sg-bg-0)] rounded w-16 sg-skeleton-shimmer" />
              </td>
              <td className="p-3 text-right">
                <div className="h-4 bg-[var(--sg-bg-0)] rounded w-12 ml-auto sg-skeleton-shimmer" />
              </td>
              <td className="p-3 text-right">
                <div className="h-4 bg-[var(--sg-bg-0)] rounded w-12 ml-auto sg-skeleton-shimmer" />
              </td>
              <td className="p-3">
                <div className="flex gap-2 justify-end">
                  <div className="h-8 bg-[var(--sg-bg-0)] rounded w-24 sg-skeleton-shimmer" />
                  <div className="h-8 bg-[var(--sg-bg-0)] rounded w-10 sg-skeleton-shimmer" />
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
    </>
  );
}

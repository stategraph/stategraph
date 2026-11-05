"use client";

import { Module } from "@/lib/api/client";
import { ModuleCard, ModuleCardSkeleton } from "./ModuleCard";

interface ModuleGridProps {
  modules: Module[];
  onViewInstances: (moduleName: string) => void;
  onOpenInspector: (module: Module) => void;
  selectedModule?: Module | null;
  isLoading?: boolean;
  costByModule?: Map<string, number>;
  costCurrency?: string;
}

export function ModuleGrid({
  modules,
  onViewInstances,
  onOpenInspector,
  selectedModule,
  isLoading = false,
  costByModule,
  costCurrency,
}: ModuleGridProps) {
  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {Array.from({ length: 12 }).map((_, i) => (
          <ModuleCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      {modules.map((module) => (
        <ModuleCard
          key={module.name}
          module={module}
          onViewInstances={onViewInstances}
          onOpenInspector={onOpenInspector}
          isSelected={selectedModule?.name === module.name}
          monthlyCost={costByModule?.get(module.name)}
          currency={costCurrency}
        />
      ))}
    </div>
  );
}

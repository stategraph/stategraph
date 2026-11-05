"use client";

import { useEffect } from "react";
import { Module } from "@/lib/api/client";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { X, Eye, GitBranch, Layers, Box, Network } from "lucide-react";
import { ModuleBreadcrumb } from "./ModuleBreadcrumb";

interface ModuleInspectorProps {
  module: Module;
  onClose: () => void;
  onViewInstances: (moduleName: string) => void;
  onNavigateToModule: (modulePath: string) => void;
}

export function ModuleInspector({
  module,
  onClose,
  onViewInstances,
  onNavigateToModule,
}: ModuleInspectorProps) {
  // Close inspector on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  const depth = module.name === "root" ? 0 : module.name.split('.').filter(s => s === 'module').length;
  const displayName = module.name === "root" ? "Root Module" : module.name;

  return (
    <>
    {/* Mobile backdrop (below lg) */}
    <div
      className="lg:hidden fixed inset-0 bg-black/30 z-40"
      onClick={onClose}
      aria-hidden="true"
    />
    <div className="fixed inset-y-0 right-0 z-50 w-full max-w-[480px] lg:static lg:z-auto lg:w-[480px] lg:max-w-none h-full bg-[var(--sg-bg-2)] border-l border-[var(--sg-border)] flex flex-col sg-fade-in">
      {/* Header */}
      <div className="flex-shrink-0 p-6 border-b border-[var(--sg-border)]">
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <Box className="h-5 w-5 text-[var(--sg-accent)] flex-shrink-0" />
            <h2 className="sg-secondary-header break-words">{displayName}</h2>
          </div>
          <button
            onClick={onClose}
            className="flex-shrink-0 p-1 rounded hover:bg-[var(--sg-bg-1)] transition-colors"
            title="Close (Esc)"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Badges */}
        <div className="flex gap-2 flex-wrap">
          {depth > 0 && (
            <Badge variant="outline" className="sg-metadata">
              Level {depth}
            </Badge>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        {/* Breadcrumb Navigation */}
        {module.name !== "root" && (
          <InspectorSection title="Module Path">
            <div className="bg-[var(--sg-bg-0)] p-3 rounded border border-[var(--sg-border)]">
              <ModuleBreadcrumb
                path={module.name}
                onNavigate={(path) => {
                  onNavigateToModule(path);
                  onClose();
                }}
              />
            </div>
          </InspectorSection>
        )}

        {/* Stats */}
        <InspectorSection title="Statistics">
          <div className="space-y-3">
            <InfoRow
              icon={<Layers className="h-4 w-4 text-[var(--sg-text-dim)]" />}
              label="Resources"
              value={module.instance_count.toLocaleString()}
            />
            <InfoRow
              icon={<GitBranch className="h-4 w-4 text-[var(--sg-text-dim)]" />}
              label="Resources"
              value={module.resource_count.toLocaleString()}
            />
          </div>
        </InspectorSection>

        {/* Actions */}
        <InspectorSection title="Actions">
          <div className="space-y-2">
            <Button
              variant="outline"
              className="w-full justify-start"
              onClick={() => onViewInstances(module.name)}
            >
              <Eye className="h-4 w-4 mr-2" />
              View All Resources
            </Button>
            <Button
              variant="outline"
              className="w-full justify-start"
              disabled
              title="Graph visualization coming soon"
            >
              <Network className="h-4 w-4 mr-2" />
              Open as Graph Root
              <Badge variant="secondary" className="ml-auto sg-metadata">
                Soon
              </Badge>
            </Button>
          </div>
        </InspectorSection>

        {/* Full Path */}
        <InspectorSection title="Full Path">
          <div className="bg-[var(--sg-bg-0)] p-3 rounded border border-[var(--sg-border)]">
            <code className="sg-metadata font-mono text-[var(--sg-text)] break-all">
              {module.name}
            </code>
          </div>
        </InspectorSection>
      </div>
    </div>
    </>
  );
}

// Helper components
function InspectorSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <h3 className="sg-secondary-header mb-3">{title}</h3>
      {children}
    </div>
  );
}

function InfoRow({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-2">
        {icon}
        <span className="sg-metadata text-[var(--sg-text-dim)]">{label}</span>
      </div>
      <span className="sg-numeric-value text-sm">{value}</span>
    </div>
  );
}

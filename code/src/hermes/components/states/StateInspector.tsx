"use client";

import { useState, useMemo } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Copy, Search, ChevronDown, ChevronRight, Check, Download } from "lucide-react";
import type { TerraformStateFile } from "@/lib/states/inspector";
import {
  extractProviders,
  matchesSearch,
} from "@/lib/states/inspector";

interface StateInspectorProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  stateFile: TerraformStateFile;
  stateName: string;
}

export function StateInspector({
  open,
  onOpenChange,
  stateFile,
  stateName,
}: StateInspectorProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    new Set(["providers"])
  );
  const [expandedResources, setExpandedResources] = useState<Set<string>>(
    new Set()
  );
  const [copiedPath, setCopiedPath] = useState<string | null>(null);

  // Extract providers
  const providers = useMemo(
    () => extractProviders(stateFile.resources),
    [stateFile.resources]
  );

  // Filter resources by search
  const filteredResources = useMemo(() => {
    return stateFile.resources.filter((r) => matchesSearch(r, searchQuery));
  }, [stateFile.resources, searchQuery]);

  // Toggle section
  const toggleSection = (section: string) => {
    const newExpanded = new Set(expandedSections);
    if (newExpanded.has(section)) {
      newExpanded.delete(section);
    } else {
      newExpanded.add(section);
    }
    setExpandedSections(newExpanded);
  };

  // Toggle resource
  const toggleResource = (resourceKey: string) => {
    const newExpanded = new Set(expandedResources);
    if (newExpanded.has(resourceKey)) {
      newExpanded.delete(resourceKey);
    } else {
      newExpanded.add(resourceKey);
    }
    setExpandedResources(newExpanded);
  };

  // Copy to clipboard
  const copyToClipboard = async (text: string, path: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedPath(path);
      setTimeout(() => setCopiedPath(null), 2000);
    } catch (err) {
      console.error("Failed to copy:", err);
    }
  };

  // Download full state
  const downloadFullState = () => {
    try {
      const json = JSON.stringify(stateFile, null, 2);
      const blob = new Blob([json], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${stateName}-state.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      setCopiedPath("full-state");
      setTimeout(() => setCopiedPath(null), 2000);
    } catch (err) {
      console.error("Failed to download:", err);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl h-[90vh] flex flex-col p-0">
        <DialogHeader className="px-6 pt-6 pb-4 border-b border-[var(--sg-border)]">
          <DialogTitle>Inspect state: {stateName}</DialogTitle>
          <DialogDescription>
            This is a read-only view of the underlying Terraform state.
          </DialogDescription>
        </DialogHeader>

        {/* Search and actions bar */}
        <div className="px-6 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)] flex items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search resources, types, attributes..."
              className="w-full pl-9 pr-3 py-2 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent"
            />
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={downloadFullState}
            className="flex items-center gap-2"
          >
            {copiedPath === "full-state" ? (
              <>
                <Check className="h-4 w-4" />
                Downloaded
              </>
            ) : (
              <>
                <Download className="h-4 w-4" />
                Download full state
              </>
            )}
          </Button>
        </div>

        {/* State content */}
        <div className="flex-1 overflow-y-auto px-6 py-4">
          <div className="space-y-4">
            {/* Providers Section */}
            <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
              <button
                onClick={() => toggleSection("providers")}
                className="w-full flex items-center justify-between p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("providers") ? (
                    <ChevronDown className="h-4 w-4" />
                  ) : (
                    <ChevronRight className="h-4 w-4" />
                  )}
                  <span className="font-semibold text-[var(--sg-text)]">
                    Providers
                  </span>
                  <span className="text-xs text-[var(--sg-text-dim)]">
                    {providers.size} provider{providers.size !== 1 ? "s" : ""}
                  </span>
                </div>
              </button>
              {expandedSections.has("providers") && (
                <div className="px-3 pb-3 space-y-2">
                  {Array.from(providers.entries()).map(
                    ([provider, data]) => (
                      <div
                        key={provider}
                        className="p-3 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]"
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-mono text-sm font-medium text-[var(--sg-text)]">
                            {provider}
                          </span>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() =>
                              copyToClipboard(provider, `provider-${provider}`)
                            }
                            className="h-6 w-6 p-0"
                          >
                            {copiedPath === `provider-${provider}` ? (
                              <Check className="h-3 w-3" />
                            ) : (
                              <Copy className="h-3 w-3" />
                            )}
                          </Button>
                        </div>
                        <div className="mt-1 text-xs text-[var(--sg-text-dim)]">
                          {data.count} resource{data.count !== 1 ? "s" : ""} ·{" "}
                          {data.types.size} type{data.types.size !== 1 ? "s" : ""}
                        </div>
                      </div>
                    )
                  )}
                </div>
              )}
            </div>

            {/* Resources Section */}
            <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
              <button
                onClick={() => toggleSection("resources")}
                className="w-full flex items-center justify-between p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("resources") ? (
                    <ChevronDown className="h-4 w-4" />
                  ) : (
                    <ChevronRight className="h-4 w-4" />
                  )}
                  <span className="font-semibold text-[var(--sg-text)]">
                    Resources
                  </span>
                  <span className="text-xs text-[var(--sg-text-dim)]">
                    {filteredResources.length} resource
                    {filteredResources.length !== 1 ? "s" : ""}
                  </span>
                </div>
              </button>
              {expandedSections.has("resources") && (
                <div className="px-3 pb-3 space-y-2">
                  {filteredResources.length === 0 ? (
                    <div className="p-4 text-center text-sm text-[var(--sg-text-dim)]">
                      {searchQuery
                        ? "No resources match your search"
                        : "No resources in this state"}
                    </div>
                  ) : (
                    filteredResources.map((resource, idx) => {
                      const resourceKey = `${resource.type}.${resource.name}`;
                      const isExpanded = expandedResources.has(resourceKey);

                      return (
                        <div
                          key={idx}
                          className="border border-[var(--sg-border)] rounded bg-[var(--sg-bg-0)]"
                        >
                          <button
                            onClick={() => toggleResource(resourceKey)}
                            className="w-full flex items-center justify-between p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
                          >
                            <div className="flex items-center gap-2">
                              {isExpanded ? (
                                <ChevronDown className="h-3 w-3" />
                              ) : (
                                <ChevronRight className="h-3 w-3" />
                              )}
                              <span className="font-mono text-sm text-[var(--sg-text)]">
                                {resourceKey}
                              </span>
                            </div>
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-[var(--sg-text-dim)]">
                                {resource.provider}
                              </span>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  copyToClipboard(
                                    JSON.stringify(resource, null, 2),
                                    resourceKey
                                  );
                                }}
                                className="h-6 w-6 p-0"
                              >
                                {copiedPath === resourceKey ? (
                                  <Check className="h-3 w-3" />
                                ) : (
                                  <Copy className="h-3 w-3" />
                                )}
                              </Button>
                            </div>
                          </button>
                          {isExpanded && (
                            <div className="px-3 pb-3">
                              <pre className="text-xs font-mono bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded p-3 overflow-x-auto">
                                <code className="text-[var(--sg-text)]">
                                  {JSON.stringify(resource, null, 2)}
                                </code>
                              </pre>
                            </div>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
              )}
            </div>

            {/* Outputs Section */}
            <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
              <button
                onClick={() => toggleSection("outputs")}
                className="w-full flex items-center justify-between p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("outputs") ? (
                    <ChevronDown className="h-4 w-4" />
                  ) : (
                    <ChevronRight className="h-4 w-4" />
                  )}
                  <span className="font-semibold text-[var(--sg-text)]">
                    Outputs
                  </span>
                  <span className="text-xs text-[var(--sg-text-dim)]">
                    {Object.keys(stateFile.outputs).length} output
                    {Object.keys(stateFile.outputs).length !== 1 ? "s" : ""}
                  </span>
                </div>
              </button>
              {expandedSections.has("outputs") && (
                <div className="px-3 pb-3">
                  {Object.keys(stateFile.outputs).length === 0 ? (
                    <div className="p-4 text-center text-sm text-[var(--sg-text-dim)]">
                      No outputs defined
                    </div>
                  ) : (
                    <pre className="text-xs font-mono bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded p-3 overflow-x-auto">
                      <code className="text-[var(--sg-text)]">
                        {JSON.stringify(stateFile.outputs, null, 2)}
                      </code>
                    </pre>
                  )}
                </div>
              )}
            </div>

            {/* Metadata Section */}
            <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
              <button
                onClick={() => toggleSection("metadata")}
                className="w-full flex items-center justify-between p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("metadata") ? (
                    <ChevronDown className="h-4 w-4" />
                  ) : (
                    <ChevronRight className="h-4 w-4" />
                  )}
                  <span className="font-semibold text-[var(--sg-text)]">
                    Metadata
                  </span>
                </div>
              </button>
              {expandedSections.has("metadata") && (
                <div className="px-3 pb-3">
                  <div className="space-y-2">
                    <div className="p-3 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
                      <div className="text-xs text-[var(--sg-text-dim)] mb-1">
                        Terraform Version
                      </div>
                      <div className="font-mono text-sm text-[var(--sg-text)]">
                        {stateFile.terraform_version}
                      </div>
                    </div>
                    <div className="p-3 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
                      <div className="text-xs text-[var(--sg-text-dim)] mb-1">
                        State Version
                      </div>
                      <div className="font-mono text-sm text-[var(--sg-text)]">
                        {stateFile.version}
                      </div>
                    </div>
                    {stateFile.metadata?.workspace && (
                      <div className="p-3 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
                        <div className="text-xs text-[var(--sg-text-dim)] mb-1">
                          Workspace
                        </div>
                        <div className="font-mono text-sm text-[var(--sg-text)]">
                          {stateFile.metadata.workspace}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

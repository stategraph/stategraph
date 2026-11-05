"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { useSearchParams } from "next/navigation";
import { useDeepLinkRouter, usePublishSelectedState } from "@/hooks";
import { getProviderLabel } from "@/lib/instances/attributes";
import { useAuth, AuthGuard } from "@/components/auth";
import { useTenant } from "@/contexts/TenantContext";
import { Button } from "@/components/ui/button";
import {
  ArrowLeft,
  Copy,
  Search,
  ChevronDown,
  ChevronRight,
  Check,
  Download,
} from "lucide-react";
import {
  getStateSummary,
  getAllStateInstances,
  executeMQL,
  type State,
} from "@/lib/api/client";
import { stateByIdQuery } from "../mqlQueries";
import {
  constructTerraformState,
  sanitizeForDisplay,
  extractProviders,
  matchesSearch,
  type TerraformStateFile,
} from "@/lib/states/inspector";

function StateInspectClientContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const stateId = searchParams.get('id') || '';

  // Redirect if no ID provided
  useEffect(() => {
    if (!stateId) {
      router.push('/states');
    }
  }, [stateId, router]);

  // Keep this state selected when navigating onward (Graph Explorer / Blast
  // Radius), overriding any stale `state` carried in from a previous page.
  usePublishSelectedState(stateId);

  const { isAuthenticated } = useAuth();
  const { currentTenant } = useTenant();

  // State
  const [stateFile, setStateFile] = useState<TerraformStateFile | null>(null);
  const [stateName, setStateName] = useState<string>("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // UI state
  const [searchQuery, setSearchQuery] = useState("");
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    new Set(["providers", "resources"])
  );
  const [expandedResources, setExpandedResources] = useState<Set<string>>(
    new Set()
  );
  const [copiedPath, setCopiedPath] = useState<string | null>(null);

  // Load state file
  const loadData = useCallback(async () => {
    if (!currentTenant || !stateId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Fetch state (direct by-id MQL lookup — fixes the >20-states .find() bug,
      // #1063), instances, and summary. (The instances fetch still truncates at
      // the endpoint's page cap — that's #1057, out of scope here.)
      const [stateResult, allInstances, summary] = await Promise.all([
        executeMQL(stateByIdQuery(stateId)),
        getAllStateInstances(stateId),
        getStateSummary(stateId),
      ]);

      const state = (stateResult.data[0] ?? null) as State | null;
      if (!state) {
        throw new Error("State not found");
      }

      setStateName(state.name);

      // Construct and sanitize the state file
      const constructed = constructTerraformState(
        state,
        allInstances,
        summary
      );
      const sanitized = sanitizeForDisplay(constructed);

      setStateFile(sanitized);
    } catch (e: unknown) {
      const message =
        e instanceof Error ? e.message : "Failed to load state file";
      setError(message);
      console.error("[StateInspectPage] Error:", e);
    } finally {
      setLoading(false);
    }
  }, [currentTenant, stateId]);

  useEffect(() => {
    if (isAuthenticated && currentTenant && stateId) {
      loadData();
    }
  }, [isAuthenticated, currentTenant, stateId, loadData]);

  // Extract providers
  const providers = useMemo(
    () => (stateFile ? extractProviders(stateFile.resources) : new Map()),
    [stateFile]
  );

  // Filter resources by search
  const filteredResources = useMemo(() => {
    if (!stateFile) return [];
    return stateFile.resources.filter((r) => matchesSearch(r, searchQuery));
  }, [stateFile, searchQuery]);

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
    if (!stateFile) return;

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


  if (!currentTenant) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen">
        <div className="text-[var(--sg-text-muted)] text-center max-w-md">
          <div className="text-xl font-semibold mb-2">No Tenant Selected</div>
          <div className="text-sm mb-4">
            Please select a tenant from the dropdown in the sidebar.
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between w-full px-6 py-4 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-3 min-w-0">
          <Button
            variant="ghost"
            size="sm"
            {...router.nav(`/states/detail?id=${stateId}`)}
            className="h-8 w-8 p-0 flex-shrink-0"
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="flex flex-col gap-1 min-w-0">
            <h1 className="text-2xl font-semibold text-[var(--sg-text)] break-words min-w-0">
              Inspect state: {stateName || "Loading..."}
            </h1>
            <p className="text-sm text-[var(--sg-text-muted)]">
              This is a read-only view of the underlying Terraform state.
            </p>
          </div>
        </div>
      </div>

      {/* Search and actions bar */}
      <div className="px-6 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)] flex flex-col sm:flex-row sm:items-center gap-3">
        <div className="relative w-full sm:flex-1 sm:max-w-2xl">
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
          disabled={!stateFile}
          className="flex items-center justify-center gap-2 w-full sm:w-auto"
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

      {/* Error */}
      {error && (
        <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
          <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
            Failed to load state file
          </div>
          <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-4">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-[var(--sg-text-muted)]">Loading state file...</div>
          </div>
        ) : stateFile ? (
          <div className="space-y-4 max-w-7xl">
            {/* Providers Section */}
            <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
              <button
                onClick={() => toggleSection("providers")}
                className="w-full flex items-center justify-between p-4 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("providers") ? (
                    <ChevronDown className="h-5 w-5" />
                  ) : (
                    <ChevronRight className="h-5 w-5" />
                  )}
                  <span className="text-lg font-semibold text-[var(--sg-text)]">
                    Providers
                  </span>
                  <span className="text-sm text-[var(--sg-text-dim)]">
                    {providers.size} provider{providers.size !== 1 ? "s" : ""}
                  </span>
                </div>
              </button>
              {expandedSections.has("providers") && (
                <div className="px-4 pb-4 grid grid-cols-1 lg:grid-cols-2 gap-4">
                  {Array.from(providers.entries()).map(([provider, data]) => (
                    <div
                      key={provider}
                      className="p-4 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]"
                    >
                      <div className="flex items-start justify-between mb-2 gap-3">
                        <span className="font-mono text-sm font-medium text-[var(--sg-text)] break-all flex-1">
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
                      <div className="text-xs text-[var(--sg-text-dim)]">
                        {data.count} resource{data.count !== 1 ? "s" : ""} ·{" "}
                        {data.types.size} type{data.types.size !== 1 ? "s" : ""}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Resources Section */}
            <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
              <button
                onClick={() => toggleSection("resources")}
                className="w-full flex items-center justify-between p-4 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("resources") ? (
                    <ChevronDown className="h-5 w-5" />
                  ) : (
                    <ChevronRight className="h-5 w-5" />
                  )}
                  <span className="text-lg font-semibold text-[var(--sg-text)]">
                    Resources
                  </span>
                  <span className="text-sm text-[var(--sg-text-dim)]">
                    {filteredResources.length} resource
                    {filteredResources.length !== 1 ? "s" : ""}
                  </span>
                </div>
              </button>
              {expandedSections.has("resources") && (
                <div className="px-4 pb-4 space-y-2">
                  {filteredResources.length === 0 ? (
                    <div className="p-8 text-center text-sm text-[var(--sg-text-dim)]">
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
                            className="w-full flex items-center justify-between gap-2 min-w-0 p-3 hover:bg-[var(--sg-bg-2)] transition-colors"
                          >
                            <div className="flex items-center gap-2 min-w-0">
                              {isExpanded ? (
                                <ChevronDown className="h-4 w-4 flex-shrink-0" />
                              ) : (
                                <ChevronRight className="h-4 w-4 flex-shrink-0" />
                              )}
                              <span className="font-mono text-sm text-[var(--sg-text)] truncate">
                                {resourceKey}
                              </span>
                            </div>
                            <div className="flex items-center gap-2 flex-shrink-0">
                              <span
                                className="hidden sm:inline text-xs text-[var(--sg-text-dim)]"
                                title={resource.provider}
                              >
                                {getProviderLabel(resource.provider)}
                              </span>
                              <span
                                onClick={(e) => {
                                  e.stopPropagation();
                                  copyToClipboard(
                                    JSON.stringify(resource, null, 2),
                                    resourceKey
                                  );
                                }}
                                className="inline-flex items-center justify-center h-6 w-6 rounded hover:bg-[var(--sg-bg-2)] cursor-pointer transition-colors"
                              >
                                {copiedPath === resourceKey ? (
                                  <Check className="h-3 w-3" />
                                ) : (
                                  <Copy className="h-3 w-3" />
                                )}
                              </span>
                            </div>
                          </button>
                          {isExpanded && (
                            <div className="px-3 pb-3">
                              <pre className="text-xs font-mono bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded p-4 overflow-x-auto">
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
                className="w-full flex items-center justify-between p-4 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("outputs") ? (
                    <ChevronDown className="h-5 w-5" />
                  ) : (
                    <ChevronRight className="h-5 w-5" />
                  )}
                  <span className="text-lg font-semibold text-[var(--sg-text)]">
                    Outputs
                  </span>
                  <span className="text-sm text-[var(--sg-text-dim)]">
                    {Object.keys(stateFile.outputs).length} output
                    {Object.keys(stateFile.outputs).length !== 1 ? "s" : ""}
                  </span>
                </div>
              </button>
              {expandedSections.has("outputs") && (
                <div className="px-4 pb-4">
                  {Object.keys(stateFile.outputs).length === 0 ? (
                    <div className="p-8 text-center text-sm text-[var(--sg-text-dim)]">
                      No outputs defined
                    </div>
                  ) : (
                    <pre className="text-sm font-mono bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded p-4 overflow-x-auto">
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
                className="w-full flex items-center justify-between p-4 hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <div className="flex items-center gap-2">
                  {expandedSections.has("metadata") ? (
                    <ChevronDown className="h-5 w-5" />
                  ) : (
                    <ChevronRight className="h-5 w-5" />
                  )}
                  <span className="text-lg font-semibold text-[var(--sg-text)]">
                    Metadata
                  </span>
                </div>
              </button>
              {expandedSections.has("metadata") && (
                <div className="px-4 pb-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                    <div className="p-4 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
                      <div className="text-xs text-[var(--sg-text-dim)] mb-1">
                        Terraform Version
                      </div>
                      <div className="font-mono text-sm text-[var(--sg-text)]">
                        {stateFile.terraform_version}
                      </div>
                    </div>
                    <div className="p-4 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
                      <div className="text-xs text-[var(--sg-text-dim)] mb-1">
                        State Version
                      </div>
                      <div className="font-mono text-sm text-[var(--sg-text)]">
                        {stateFile.version}
                      </div>
                    </div>
                    {stateFile.metadata?.workspace && (
                      <div className="p-4 bg-[var(--sg-bg-0)] rounded border border-[var(--sg-border)]">
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
        ) : null}
      </div>
    </div>
  );
}

export function StateInspectClient() {
  return (
    <AuthGuard>
      <StateInspectClientContent />
    </AuthGuard>
  );
}

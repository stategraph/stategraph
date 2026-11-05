"use client";

import { useState, useCallback, useEffect, useMemo } from "react";
import { useSearchParams } from "next/navigation";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { Button } from "@/components/ui/button";
import { Target, GitBranch, AlertCircle } from "lucide-react";
import { useStates } from "@/contexts";
import { useStateSelection } from "@/hooks";
import { getInstanceBlastRadius, type InstanceBlastRadiusResponse, type BlastRadiusNode } from "@/lib/api/client";
import { transformBlastRadiusToGraph, getGraphStats, DEFAULT_GRAPH_LIMITS } from "@/lib/graph";
import { useInspector } from "@/components/inspector";
import { InstanceSelector } from "@/components/instances";
import { StateFilter } from "@/components/filters";

export function BlastRadiusContent() {
  const searchParams = useSearchParams();
  const { states } = useStates();
  const { openInspector } = useInspector();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  const [instanceAddress, setInstanceAddressRaw] = useState(
    searchParams.get("resource") || searchParams.get("instance") || ""
  );

  // Sync resource param to URL for deep linking
  const setInstanceAddress = useCallback((address: string) => {
    setInstanceAddressRaw(address);
    if (typeof window === "undefined") return;
    const url = new URL(window.location.href);
    if (address) {
      url.searchParams.set("resource", address);
    } else {
      url.searchParams.delete("resource");
    }
    window.history.replaceState(null, "", url.pathname + url.search);
  }, []);
  // Track the state ID for the selected instance (needed for "All States" mode)
  const [selectedInstanceStateId, setSelectedInstanceStateId] = useState<string | null>(null);
  const [blastRadius, setBlastRadius] = useState<InstanceBlastRadiusResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Determine which state ID to use for the blast radius API call
  const effectiveStateId = isAllStates ? selectedInstanceStateId : currentState?.id ?? null;

  const loadBlastRadius = useCallback(async () => {
    if (!effectiveStateId || !instanceAddress.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const data = await getInstanceBlastRadius(
        effectiveStateId,
        instanceAddress,
        { maxDepth: DEFAULT_GRAPH_LIMITS.requestDepth }
      );
      setBlastRadius(data);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to load blast radius";
      setError(message);
      console.error("Blast radius load error:", err);
    } finally {
      setLoading(false);
    }
  }, [effectiveStateId, instanceAddress]);

  useEffect(() => {
    if (instanceAddress && effectiveStateId) {
      loadBlastRadius();
    }
  }, [instanceAddress, effectiveStateId, loadBlastRadius]);

  // The metrics come from the graph, and two of them could not be right before it existed. "Max
  // Distance" read a field the server always set to 0, and "Direct Dependencies" counted
  // `distance <= 2` -- which, with every distance 0, matched every row and made that tile a copy of
  // the one beside it. Both are now derived from the edges.
  const graphResult = useMemo(
    () => (blastRadius ? transformBlastRadiusToGraph(blastRadius, DEFAULT_GRAPH_LIMITS) : null),
    [blastRadius]
  );
  const stats = useMemo(
    () =>
      graphResult?.graph
        ? getGraphStats(graphResult.graph)
        : { totalNodes: 0, maxDepth: 0, directDependents: 0, affectedResources: 0, statesTouched: 0 },
    [graphResult]
  );
  const distanceOf = useMemo(() => {
    const m = new Map<string, number>();
    graphResult?.graph?.nodes.forEach((n) => m.set(n.id, n.distance));
    return m;
  }, [graphResult]);
  // The list is the blocks that hold infrastructure, nearest first. The intermediates are in the
  // graph, where they show the route; in a list of "what is affected" they are noise.
  const listed = useMemo(
    () =>
      (blastRadius?.nodes ?? [])
        .filter((n) => n.is_seed || n.kind === "resource" || n.kind === "data")
        .sort(
          (a, b) =>
            (distanceOf.get(a.id) ?? 0) - (distanceOf.get(b.id) ?? 0) ||
            a.address.localeCompare(b.address)
        ),
    [blastRadius, distanceOf]
  );

  return (
    <div className="flex flex-col w-full">
      <PageHeader
        title="Blast Radius"
        subtitle="Analyze the impact radius of infrastructure changes"
      >
        <StateFilter
          value={selectedStateId}
          onChange={setSelectedStateId}
          showAllOption
          className="min-w-[200px]"
        />
      </PageHeader>

      {/* Input Section */}
      <PageSection>
        <PageSurface className="p-4">
          <div className="flex flex-col gap-3 sm:flex-row">
            <InstanceSelector
              stateId={currentState?.id}
              allStates={isAllStates ? states : undefined}
              value={instanceAddress}
              onChange={setInstanceAddress}
              onSelect={(instance) => {
                setInstanceAddress(instance.address);
                if (instance.state_id) {
                  setSelectedInstanceStateId(instance.state_id);
                }
              }}
              placeholder="Select a resource..."
            />
            <Button
              onClick={loadBlastRadius}
              disabled={!instanceAddress.trim() || !effectiveStateId || loading}
            >
              <Target className="w-4 h-4 mr-2" />
              {loading ? "Analyzing..." : "Analyze"}
            </Button>
          </div>
        </PageSurface>
      </PageSection>

      {/* Error State */}
      {error && (
        <PageSection>
          <PageSurface className="p-6 border-l-4" style={{ borderLeftColor: "var(--sg-error)" }}>
            <div className="flex items-start gap-3">
              <AlertCircle
                className="w-5 h-5 flex-shrink-0"
                style={{ color: "var(--sg-error)" }}
              />
              <div>
                <div
                  className="font-medium mb-1"
                  style={{ color: "var(--sg-error)" }}
                >
                  Failed to Load Blast Radius
                </div>
                <div
                  className="text-sm"
                  style={{ color: "var(--sg-text-muted)" }}
                >
                  {error}
                </div>
              </div>
            </div>
          </PageSurface>
        </PageSection>
      )}

      {/* Loading State */}
      {loading && (
        <PageSection>
          <PageSurface className="p-12 text-center">
            <div className="flex flex-col items-center gap-3">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[var(--sg-accent)]"></div>
              <div className="text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                Analyzing blast radius...
              </div>
            </div>
          </PageSurface>
        </PageSection>
      )}

      {/* Results Section */}
      {blastRadius && (
        <>
          {/* Metrics */}
          <PageSection title="Impact Metrics">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: "var(--sg-bg-1)" }}
                  >
                    <GitBranch
                      className="w-5 h-5"
                      style={{ color: "var(--sg-text-muted)" }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: "var(--sg-text)" }}
                    >
                      {stats.affectedResources}
                      {blastRadius.truncated ? "+" : ""}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: "var(--sg-text-muted)" }}
                    >
                      Affected Resources
                    </div>
                  </div>
                </div>
              </PageSurface>

              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: "var(--sg-bg-1)" }}
                  >
                    <Target
                      className="w-5 h-5"
                      style={{ color: "var(--sg-text-muted)" }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: "var(--sg-text)" }}
                    >
                      {stats.maxDepth}
                      {blastRadius.truncated ? "+" : ""}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: "var(--sg-text-muted)" }}
                    >
                      Max Distance
                    </div>
                  </div>
                </div>
              </PageSurface>

              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: "var(--sg-bg-1)" }}
                  >
                    <AlertCircle
                      className="w-5 h-5"
                      style={{ color: "var(--sg-text-muted)" }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: "var(--sg-text)" }}
                    >
                      {stats.directDependents}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: "var(--sg-text-muted)" }}
                    >
                      Direct References
                    </div>
                  </div>
                </div>
              </PageSurface>
            </div>
          </PageSection>

          {/* Affected Resources List */}
          <PageSection title="Affected Resources">
            <PageSurface>
              <div className="divide-y" style={{ borderColor: "var(--sg-border)" }}>
                {listed.map((resource: BlastRadiusNode) => (
                  <div
                    key={resource.id}
                    className="p-4 hover:bg-[var(--sg-bg-1)] transition-colors cursor-pointer"
                    onClick={() => {
                      openInspector({
                        address: resource.address,
                        type: resource.resource_type ?? resource.kind,
                        modulePath: resource.module_address,
                        provider: "unknown",
                      });
                    }}
                  >
                    <div className="flex items-center justify-between gap-3">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span
                            className="text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wide flex-shrink-0"
                            style={{
                              color: resource.is_seed ? "var(--sg-text-muted)" : "var(--sg-accent)",
                              background: "var(--sg-bg-0)",
                              border: "1px solid var(--sg-border)",
                            }}
                          >
                            {resource.is_seed ? "Selected" : resource.kind}
                          </span>
                          <div
                            className="font-medium break-all"
                            style={{ color: "var(--sg-text)" }}
                          >
                            {resource.address}
                          </div>
                        </div>
                        <div
                          className="text-sm break-all"
                          style={{ color: "var(--sg-text-muted)" }}
                        >
                          {resource.resource_type ?? resource.kind}
                          {resource.instance_count > 0 ? ` · ${resource.instance_count} instance${resource.instance_count === 1 ? "" : "s"}` : ""}
                          {resource.state_name ? ` · ${resource.state_name}` : ""}
                        </div>
                      </div>
                      <div className="flex items-center gap-4 flex-shrink-0">
                        <div className="text-right">
                          <div
                            className="text-xs uppercase tracking-wide mb-1"
                            style={{ color: "var(--sg-text-dim)" }}
                          >
                            Hops
                          </div>
                          <div
                            className="text-lg font-bold"
                            style={{ color: "var(--sg-accent)" }}
                          >
                            {distanceOf.get(resource.id) ?? "-"}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </PageSurface>
          </PageSection>
        </>
      )}

      {/* Empty State */}
      {!loading && !error && !blastRadius && (isAllStates || currentState) && (
        <PageSection>
          <PageSurface className="p-8 text-center">
            <Target
              className="w-12 h-12 mx-auto mb-3 opacity-40"
              style={{ color: "var(--sg-text-muted)" }}
            />
            <div
              className="text-sm mb-4"
              style={{ color: "var(--sg-text-dim)" }}
            >
              Select a resource above to analyze its blast radius.
            </div>
          </PageSurface>
        </PageSection>
      )}
    </div>
  );
}

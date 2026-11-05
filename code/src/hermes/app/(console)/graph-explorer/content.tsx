'use client';

/**
 * Graph Explorer Page
 *
 * DESIGN PHILOSOPHY:
 * This is NOT a generic graph visualization tool.
 * This is NOT a full-environment topology map.
 * This is NOT an attempt to visualize "everything".
 *
 * PURPOSE:
 * The Graph page exists for explanation and learning, not completeness.
 * It answers: "Why does this resource exist? What does it depend on? What depends on it?"
 *
 * PRINCIPLES (non-negotiable):
 * 1. Always scoped - No "entire environment" graph
 * 2. Depth is capped by default
 * 3. Repetition is collapsed
 * 4. Hover is the primary interaction
 * 5. Illegibility is not acceptable - we refuse to render if graph would be illegible
 *
 * INSPIRED BY:
 * Blast Radius project - we studied its design principles and failure modes,
 * but this is a fresh implementation, not a port.
 */

import { useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { PageHeader, PageSection, PageSurface } from '@/components/page';
import { Network, AlertCircle, Target, GitBranch } from 'lucide-react';
import { useStates } from '@/contexts';
import { useStateSelection } from '@/hooks';
import { getInstanceBlastRadius, getStateInstances } from '@/lib/api/client';
import type { Instance } from '@/lib/api/client';
import { InstanceSelector } from '@/components/instances';
import { DependencyGraph, GraphRefusal } from '@/components/graph';
import { transformBlastRadiusToGraph, getGraphStats, DEFAULT_GRAPH_LIMITS } from '@/lib/graph';
import type { GraphData, GraphNode, RefusalReason } from '@/lib/graph';
import { useInspector } from '@/components/inspector';
import { StateFilter } from '@/components/filters';

export function GraphExplorerContent() {
  const searchParams = useSearchParams();
  const { states } = useStates();
  const { openInspector } = useInspector();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  const [instanceAddress, setInstanceAddressRaw] = useState(
    searchParams.get('resource') || searchParams.get('instance') || ''
  );

  // Sync resource param to URL for deep linking
  const setInstanceAddress = useCallback((address: string) => {
    setInstanceAddressRaw(address);
    if (typeof window === 'undefined') return;
    const url = new URL(window.location.href);
    if (address) {
      url.searchParams.set('resource', address);
    } else {
      url.searchParams.delete('resource');
    }
    window.history.replaceState(null, '', url.pathname + url.search);
  }, []);
  const [selectedInstanceStateId, setSelectedInstanceStateId] = useState<string | null>(null);
  const [instance, setInstance] = useState<Instance | null>(null);
  const [graph, setGraph] = useState<GraphData | null>(null);
  const [refusal, setRefusal] = useState<RefusalReason | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Determine which state ID to use for API calls
  const effectiveStateId = isAllStates ? selectedInstanceStateId : currentState?.id ?? null;

  const loadGraph = useCallback(async (selectedInstance: Instance) => {
    const stateIdForCall = isAllStates ? (selectedInstance.state_id ?? null) : currentState?.id ?? null;
    if (!stateIdForCall) return;

    setLoading(true);
    setError(null);
    setRefusal(null);
    setGraph(null);

    try {
      setInstance(selectedInstance);

      // The server returns the graph the subgraph walk itself computed: the blocks a change to
      // this resource would reach, and the dependencies between them.
      const blastRadius = await getInstanceBlastRadius(
        stateIdForCall,
        selectedInstance.address,
        { maxDepth: DEFAULT_GRAPH_LIMITS.requestDepth }
      );

      const result = transformBlastRadiusToGraph(blastRadius, DEFAULT_GRAPH_LIMITS);

      if (result.error) {
        setError(result.error);
      } else if (result.refusal) {
        // Graph refused due to excessive complexity - this is intentional
        setRefusal(result.refusal);
      } else if (result.graph) {
        // Graph is safe to render
        setGraph(result.graph);
      }
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : 'Failed to load graph';
      setError(message);
      console.error('Graph load error:', err);
    } finally {
      setLoading(false);
    }
  }, [isAllStates, currentState]);

  // Auto-load graph from URL resource param on deep link
  const hasAutoLoaded = useRef(false);
  useEffect(() => {
    if (hasAutoLoaded.current) return;
    if ((!isAllStates && !currentState) || !instanceAddress) return;

    hasAutoLoaded.current = true;

    (async () => {
      try {
        if (isAllStates) {
          // Resolve the resource with a targeted server-side lookup per state —
          // a window scan missed any resource past the first page (#1065).
          for (const state of states) {
            const response = await getStateInstances(state.id, {
              q: `address:${instanceAddress}`,
              limit: 1,
            });
            const matched = response.data.results[0];
            if (matched) {
              setSelectedInstanceStateId(state.id);
              loadGraph({ ...matched, state_id: state.id });
              break;
            }
          }
        } else {
          const response = await getStateInstances(currentState!.id, {
            q: `address:${instanceAddress}`,
            limit: 1,
          });
          const matched = response.data.results[0];
          if (matched) {
            loadGraph(matched);
          }
        }
      } catch (err) {
        console.error('[GraphExplorer] Failed to auto-load from URL:', err);
      }
    })();
  }, [isAllStates, currentState, states, instanceAddress, loadGraph]);

  const handleNodeClick = useCallback(async (node: GraphNode) => {
    // A node lives in its own state, which is not always the queried one: a blast radius crosses a
    // terraform_remote_state boundary, and looking the node up in the wrong state finds nothing.
    const nodeStateId = node.stateId ?? effectiveStateId;
    if (!nodeStateId) return;

    // If it's the root node, we already have all the data
    if (node.isRoot) {
      openInspector({
        address: node.address,
        type: node.type ?? node.kind,
        provider: node.provider,
        modulePath: node.module,
        tags: node.attributes?.tags as Record<string, string> | undefined,
        attributes: node.attributes,
      });
      return;
    }

    // Only a block with instances is worth looking up. A locals entry, a variable or a module call
    // is not an instance, so the query below would always come back empty and fall through to the
    // same panel it reaches directly.
    if (node.kind !== 'resource' && node.kind !== 'data') {
      openInspector({
        address: node.address,
        type: node.type ?? node.kind,
        provider: node.provider,
        modulePath: node.module,
      });
      return;
    }

    // Resolve the clicked node with a targeted server-side address lookup (the
    // old fetch-a-page-and-scan missed nodes past the window — #1065).
    try {
      const response = await getStateInstances(nodeStateId, {
        q: `address:${node.address}`,
        limit: 1,
      });

      const matchedInstance = response.data.results[0];
      if (matchedInstance) {
        openInspector({
          address: matchedInstance.address,
          type: matchedInstance.type,
          provider: matchedInstance.provider,
          modulePath: matchedInstance.module,
          tags: matchedInstance.attributes?.tags as Record<string, string> | undefined,
          attributes: matchedInstance.attributes as Record<string, unknown> | undefined,
          dependencyCount: matchedInstance.dependencies?.length,
        });
      } else {
        // Instance not in first page, show what we have
        openInspector({
          address: node.address,
          type: node.type ?? node.kind,
          provider: node.provider,
          modulePath: node.module,
        });
      }
    } catch (err) {
      console.error('[GraphExplorer] Failed to fetch instance details:', err);
      // Fallback to basic info
      openInspector({
        address: node.address,
        type: node.type ?? node.kind,
        provider: node.provider,
        modulePath: node.module,
      });
    }
  }, [effectiveStateId, openInspector]);

  return (
    <div className="flex flex-col w-full">
      <PageHeader
        title="Graph Explorer"
        subtitle="Explore focused dependency graphs for infrastructure resources"
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
          <div className="flex gap-3">
            <InstanceSelector
              stateId={currentState?.id}
              allStates={isAllStates ? states : undefined}
              value={instanceAddress}
              onChange={setInstanceAddress}
              onSelect={(selectedInstance) => {
                setInstanceAddress(selectedInstance.address);
                if (selectedInstance.state_id) {
                  setSelectedInstanceStateId(selectedInstance.state_id);
                }
                loadGraph(selectedInstance);
              }}
              placeholder="Select a resource to visualize..."
            />
          </div>
        </PageSurface>
      </PageSection>

      {/* Error State */}
      {error && (
        <PageSection>
          <PageSurface
            className="p-6 border-l-4"
            style={{ borderLeftColor: 'var(--sg-error)' }}
          >
            <div className="flex items-start gap-3">
              <AlertCircle
                className="w-5 h-5 flex-shrink-0"
                style={{ color: 'var(--sg-error)' }}
              />
              <div>
                <div
                  className="font-medium mb-1"
                  style={{ color: 'var(--sg-error)' }}
                >
                  Failed to Load Graph
                </div>
                <div
                  className="text-sm"
                  style={{ color: 'var(--sg-text-muted)' }}
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
                Loading graph...
              </div>
            </div>
          </PageSurface>
        </PageSection>
      )}

      {/* Graph Stats & Visualization */}
      {graph && instance && (
        <>
          {/* Stats */}
          <PageSection title="Graph Metrics">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: 'var(--sg-bg-1)' }}
                  >
                    <Target
                      className="w-5 h-5"
                      style={{ color: 'var(--sg-text-muted)' }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: 'var(--sg-text)' }}
                    >
                      {graph.nodeCount}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: 'var(--sg-text-muted)' }}
                    >
                      Resources
                    </div>
                  </div>
                </div>
              </PageSurface>

              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: 'var(--sg-bg-1)' }}
                  >
                    <GitBranch
                      className="w-5 h-5"
                      style={{ color: 'var(--sg-text-muted)' }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: 'var(--sg-text)' }}
                    >
                      {graph.edgeCount}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: 'var(--sg-text-muted)' }}
                    >
                      Dependencies
                    </div>
                  </div>
                </div>
              </PageSurface>

              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: 'var(--sg-bg-1)' }}
                  >
                    <Network
                      className="w-5 h-5"
                      style={{ color: 'var(--sg-text-muted)' }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: 'var(--sg-text)' }}
                    >
                      {graph.maxDistance}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: 'var(--sg-text-muted)' }}
                    >
                      Max Depth
                    </div>
                  </div>
                </div>
              </PageSurface>

              <PageSurface className="p-4">
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-md flex items-center justify-center"
                    style={{ background: 'var(--sg-bg-1)' }}
                  >
                    <AlertCircle
                      className="w-5 h-5"
                      style={{ color: 'var(--sg-text-muted)' }}
                    />
                  </div>
                  <div>
                    <div
                      className="text-2xl font-bold"
                      style={{ color: 'var(--sg-text)' }}
                    >
                      {getGraphStats(graph).directDependents}
                    </div>
                    <div
                      className="text-sm"
                      style={{ color: 'var(--sg-text-muted)' }}
                    >
                      Direct Links
                    </div>
                  </div>
                </div>
              </PageSurface>
            </div>
          </PageSection>

          {/* Graph Visualization */}
          <PageSection title={`Dependency Graph: ${instance.type}`}>
            <PageSurface className="p-6">
              {/* Usage Instructions */}
              <div
                className="mb-4 p-3 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded text-xs"
                style={{ color: 'var(--sg-text-dim)' }}
              >
                <strong>Hover</strong> over nodes to explore relationships.
                <strong> Click</strong> nodes to inspect details.
                <strong> Drag</strong> to pan, <strong>scroll</strong> to zoom, or use the zoom controls.
              </div>

              {/* Graph */}
              <DependencyGraph
                graph={graph}
                onNodeClick={handleNodeClick}
              />
            </PageSurface>
          </PageSection>
        </>
      )}

      {/* Refusal State */}
      {refusal && instance && (
        <PageSection title={`Dependency Graph: ${instance.type}`}>
          <PageSurface className="p-6">
            <GraphRefusal refusal={refusal} />
          </PageSurface>
        </PageSection>
      )}

      {/* Empty State */}
      {!loading && !error && !graph && !refusal && (isAllStates || currentState) && (
        <PageSection>
          <PageSurface className="p-8 text-center">
            <Network
              className="w-12 h-12 mx-auto mb-3 opacity-40"
              style={{ color: 'var(--sg-text-muted)' }}
            />
            <div
              className="text-sm mb-2"
              style={{ color: 'var(--sg-text-dim)' }}
            >
              Select a resource above to visualize its dependency graph.
            </div>
            <div
              className="text-xs"
              style={{ color: 'var(--sg-text-dim)' }}
            >
              The graph shows what a change to the selected resource would reach,
              out to {DEFAULT_GRAPH_LIMITS.requestDepth} levels of dependency.
            </div>
          </PageSurface>
        </PageSection>
      )}
    </div>
  );
}

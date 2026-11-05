/**
 * Graph Data Transformation
 *
 * Turns the blast-radius API response into the structure the renderer draws.
 *
 * WHAT THIS REPLACED, AND WHY IT MATTERS. The previous version received a flat list of affected
 * instances and had to INVENT the shape: it emitted one edge from the root to each dependent, so a
 * chain `a -> local.mid -> b -> c` was drawn as a star of three nodes around `a`, and `local.mid`
 * -- which is how the change actually travels -- was not drawn at all. The server now returns the
 * edges the subgraph walk itself crossed, so the shape is read rather than guessed.
 *
 * HARD REFUSAL RULES:
 * - Graphs exceeding limits will NOT be rendered
 * - This is intentional product design, not an error
 */

import type { InstanceBlastRadiusResponse, BlastRadiusNode } from '@/lib/api/client';
import type {
  GraphNode,
  GraphEdge,
  GraphData,
  GraphLimits,
  GraphNodeKind,
  GraphEdgeKind,
  GraphTruncation,
  RefusalReason,
} from './types';
import { DEFAULT_GRAPH_LIMITS, VALUE_KINDS } from './types';

export interface GraphTransformResult {
  graph: GraphData | null;
  refusal: RefusalReason | null;
  /**
   * A contract failure rather than a legibility refusal -- the response held no root node. Kept
   * apart from `refusal` so a server problem is never dressed up as an intentional product
   * decision.
   */
  error: string | null;
}

const NODE_KINDS: ReadonlySet<string> = new Set<GraphNodeKind>([
  'resource',
  'data',
  'locals',
  'variable',
  'output',
  'module',
  'provider',
  'terraform',
]);

/** The server states the kind. An unrecognised one is carried as 'other', never guessed at. */
function nodeKind(kind: string): GraphNodeKind {
  return NODE_KINDS.has(kind) ? (kind as GraphNodeKind) : 'other';
}

/** A node that only holds a value is drawn small; one that acts is drawn full size. */
function nodeSize(kind: GraphNodeKind, isRoot: boolean): { width: number; height: number } {
  if (isRoot) return { width: 220, height: 80 };
  if (VALUE_KINDS.has(kind)) return { width: 150, height: 40 };
  return { width: 180, height: 60 };
}

/**
 * Transform the blast-radius response into a graph.
 *
 * @param response - the API response: nodes, edges, root_id and a truncation flag
 * @param limits - rendering limits (defaults to the hard-coded ones)
 */
export function transformBlastRadiusToGraph(
  response: InstanceBlastRadiusResponse,
  limits: GraphLimits = DEFAULT_GRAPH_LIMITS
): GraphTransformResult {
  const {
    nodes: wireNodes,
    edges: wireEdges,
    root_id: rootId,
    truncated,
    total_nodes: totalNodes,
  } = response;
  const truncation: GraphTruncation = {
    serverTruncated: truncated,
    serverTotalNodes: totalNodes,
    serverReturnedNodes: wireNodes.length,
  };

  if (wireNodes.length === 0) {
    return {
      graph: {
        rootId: '',
        nodes: [],
        edges: [],
        maxDistance: 0,
        nodeCount: 0,
        edgeCount: 0,
        truncation,
      },
      refusal: null,
      error: null,
    };
  }

  const byId = new Map<string, BlastRadiusNode>(wireNodes.map((n) => [n.id, n]));

  if (!byId.has(rootId)) {
    return { graph: null, refusal: null, error: 'The blast radius response named no root node.' };
  }

  // The direction flip, and it is the easiest thing here to get wrong.
  // The wire says `from_id` depends on `to_id`. A GraphEdge points the way the value flows, so the
  // dependency becomes the source and the dependent becomes the target. Reverse this and dagre
  // lays the graph out upside down and every arrowhead points backwards -- a plausible-looking
  // failure, which is why `transform.test.ts` asserts it on its own.
  const edges: GraphEdge[] = [];
  const seenEdge = new Set<string>();
  for (const e of wireEdges) {
    if (!byId.has(e.from_id) || !byId.has(e.to_id)) continue;
    const key = `${e.to_id}|${e.from_id}|${e.kind}`;
    if (seenEdge.has(key)) continue;
    seenEdge.add(key);
    edges.push({ source: e.to_id, target: e.from_id, kind: e.kind as GraphEdgeKind });
  }

  // Distance is BFS from the root along the edges, which is what the removed `distance` field
  // claimed to be and never was.
  const outOf = new Map<string, string[]>();
  for (const e of edges) {
    const l = outOf.get(e.source);
    if (l) l.push(e.target);
    else outOf.set(e.source, [e.target]);
  }
  const distance = new Map<string, number>([[rootId, 0]]);
  let frontier = [rootId];
  let depth = 0;
  while (frontier.length > 0) {
    const next: string[] = [];
    for (const id of frontier) {
      for (const to of outOf.get(id) ?? []) {
        if (!distance.has(to)) {
          distance.set(to, depth + 1);
          next.push(to);
        }
      }
    }
    frontier = next;
    depth += 1;
  }

  const directRelationships = (outOf.get(rootId) ?? []).length;
  if (directRelationships > limits.maxDirectRelationships) {
    return {
      graph: null,
      refusal: {
        type: 'direct_relationships',
        message: `This resource has ${directRelationships} direct relationships, exceeding the display limit of ${limits.maxDirectRelationships}.`,
        actualCount: directRelationships,
        limit: limits.maxDirectRelationships,
        serverTruncated: truncated,
        details: { directDependents: directRelationships, totalNodes: wireNodes.length },
      },
      error: null,
    };
  }

  if (wireNodes.length > limits.maxNodes) {
    return {
      graph: null,
      refusal: {
        type: 'node_count',
        message: `This graph would contain ${wireNodes.length} nodes, exceeding the display limit of ${limits.maxNodes}.`,
        actualCount: wireNodes.length,
        limit: limits.maxNodes,
        serverTruncated: truncated,
        details: { totalNodes: wireNodes.length },
      },
      error: null,
    };
  }

  const nodes: GraphNode[] = wireNodes.map((n) => {
    const kind = nodeKind(n.kind);
    const isRoot = n.id === rootId;
    return {
      id: n.id,
      address: n.address,
      kind,
      type: n.resource_type,
      module: n.module_address,
      stateId: n.state_id,
      stateName: n.state_name,
      instanceCount: n.instance_count,
      distance: distance.get(n.id) ?? 0,
      isRoot,
      ...nodeSize(kind, isRoot),
    };
  });

  const maxDistance = nodes.reduce((m, n) => (n.distance > m ? n.distance : m), 0);

  return {
    graph: {
      rootId,
      nodes,
      edges,
      maxDistance,
      nodeCount: nodes.length,
      edgeCount: edges.length,
      truncation,
    },
    refusal: null,
    error: null,
  };
}

/**
 * True when the address denotes a real Terraform resource. False for
 * data sources, locals, providers, variables, outputs, and the terraform
 * block — these exist in the reified subgraph as dependency context but
 * rarely matter to a plan reader.
 */
export function isResourceAddress(address: string): boolean {
  let rest = address;
  while (rest.startsWith('module.')) {
    const parts = rest.split('.');
    rest = parts.slice(2).join('.');
  }
  // A bare module node ("module.foo") has nothing left after the prefix.
  if (rest === '') return false;
  if (rest === 'terraform') return false;
  if (rest.startsWith('data.')) return false;
  if (rest.startsWith('local.') || rest.startsWith('locals.')) return false;
  if (rest.startsWith('var.') || rest.startsWith('variable.')) return false;
  if (rest.startsWith('provider.')) return false;
  if (rest.startsWith('output.')) return false;
  return true;
}

/**
 * Calculate graph statistics for display.
 *
 * `directDependents` is the root's out-degree over the edges, which is what "direct" means now
 * that a real edge set exists.
 */
export function getGraphStats(graph: GraphData): {
  totalNodes: number;
  maxDepth: number;
  directDependents: number;
  affectedResources: number;
  statesTouched: number;
} {
  return {
    totalNodes: graph.nodeCount,
    maxDepth: graph.maxDistance,
    directDependents: graph.edges.filter((e) => e.source === graph.rootId).length,
    // A locals entry is not a resource anyone applies, so it is not an affected resource.
    affectedResources: graph.nodes.filter(
      (n) => !n.isRoot && (n.kind === 'resource' || n.kind === 'data')
    ).length,
    statesTouched: new Set(graph.nodes.map((n) => n.stateId).filter(Boolean)).size,
  };
}

/**
 * Graph Types for Dependency Visualization
 *
 * These types support the scoped, depth-limited graph visualization
 * described in the Graph page design requirements.
 */

/**
 * The HCL block kinds a node can be.
 *
 * A block that only HOLDS a value ('locals', 'variable', 'output') is drawn differently from one
 * that ACTS ('resource', 'data', 'module'), because a graph that shows every block the same size
 * hides the thing including intermediates was meant to reveal: which nodes are infrastructure and
 * which are only the wiring between them.
 */
export type GraphNodeKind =
  | 'resource'
  | 'data'
  | 'locals'
  | 'variable'
  | 'output'
  | 'module'
  | 'provider'
  | 'terraform'
  | 'other';

/** Block kinds that hold a value rather than doing something. */
export const VALUE_KINDS: ReadonlySet<GraphNodeKind> = new Set<GraphNodeKind>([
  'locals',
  'variable',
  'output',
]);

export interface GraphNode {
  /** Opaque server-assigned id. Never parsed. */
  id: string;
  address: string;
  /** HCL block kind, stated by the server. Never guessed from the address. */
  kind: GraphNodeKind;
  /** Terraform type of a resource or data block. Absent for a block that has none. */
  type?: string;
  provider?: string;
  module?: string;
  /** State the block lives in; a blast radius can span states. */
  stateId?: string;
  stateName?: string;
  /** Instances this block has, from count / for_each. 0 for a block with none. */
  instanceCount?: number;
  attributes?: Record<string, unknown>;
  /** Hops from the root, computed by BFS over the edges. */
  distance: number;
  isRoot: boolean;
  // Layout properties (set by dagre)
  x?: number;
  y?: number;
  width: number;
  height: number;
}

/** What a dependency is made of. A depends_on is absent: no value travels along one. */
export type GraphEdgeKind = 'reads' | 'binds' | 'reads_file' | 'reads_tfvar';

export interface GraphEdge {
  /** Node the value flows FROM: the one depended upon. */
  source: string;
  /** Node the value flows TO: the one that depends on it. */
  target: string;
  kind: GraphEdgeKind;
}

export interface GraphTruncation {
  /** True when the SERVER stopped walking. Authoritative -- the client cannot recover the rest. */
  serverTruncated: boolean;
  /**
   * How many blocks the server reached within max_depth, BEFORE its node cap cut the answer.
   * Greater than serverReturnedNodes exactly when the cap bit, which is the only truncation the
   * viewer can be given a number for -- serverTruncated on its own also covers the depth cut.
   */
  serverTotalNodes: number;
  /** How many blocks the server actually returned. */
  serverReturnedNodes: number;
}

export interface GraphData {
  rootId: string;
  nodes: GraphNode[];
  edges: GraphEdge[];
  /** The deepest distance ACTUALLY present, not a configured limit. */
  maxDistance: number;
  nodeCount: number;
  edgeCount: number;
  truncation: GraphTruncation;
}

/**
 * Configuration for graph rendering limits.
 * These enforce the "illegibility is unacceptable" principle.
 *
 * HARD CONSTRAINTS (non-negotiable):
 * - Graphs exceeding these limits will NOT be rendered
 * - No override, toggle, or escape hatch exists
 * - This is intentional product design, not an error state
 */
export interface GraphLimits {
  /**
   * Maximum total nodes (including root) allowed in graph.
   * Graphs exceeding this are illegible.
   */
  maxNodes: number;

  /**
   * Maximum direct relationships on the root.
   * If root has more than this many direct connections, refuse to render.
   */
  maxDirectRelationships: number;

  /**
   * How many hops to ASK the server for.
   *
   * This is a request parameter and NOT a client-side filter. Cutting a returned graph by depth
   * here would sever a transitive chain and leave a partial graph that looks complete, which is
   * the one thing this view must not do. The server owns the cut and reports it.
   */
  requestDepth: number;
}

/**
 * Hard limits for graph legibility.
 * These values are intentionally conservative and NON-CONFIGURABLE.
 */
export const DEFAULT_GRAPH_LIMITS: GraphLimits = {
  maxNodes: 50,                    // Hard limit: total nodes
  maxDirectRelationships: 40,      // Hard limit: direct relationships on the root
  requestDepth: 100,               // How many hops to ask the server for
};

/**
 * Reason why a graph was refused.
 * This is NOT an error - it's intentional product design to maintain legibility.
 */
export interface RefusalReason {
  type: 'direct_relationships' | 'node_count';
  message: string;
  /**
   * Actual count that exceeded the limit
   */
  actualCount: number;
  /**
   * The limit that was exceeded
   */
  limit: number;
  /**
   * Breakdown (if applicable)
   */
  /** True when the server ALSO truncated, so the refused count is a lower bound. */
  serverTruncated?: boolean;
  details?: {
    directDependents?: number;
    totalNodes?: number;
  };
}

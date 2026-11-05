/**
 * Graph Layout Utilities
 *
 * Uses dagre for hierarchical graph layout.
 * Implements vertical stacking to minimize horizontal sprawl
 * (lesson learned from Blast Radius).
 */

import dagre from 'dagre';
import type { GraphData } from './types';

export interface LayoutOptions {
  /**
   * Direction of graph flow.
   * TB = Top to Bottom (vertical stacking, reduces horizontal sprawl)
   * LR = Left to Right (traditional)
   */
  rankdir: 'TB' | 'LR';

  /**
   * Spacing between nodes
   */
  nodesep: number;

  /**
   * Spacing between ranks (levels)
   */
  ranksep: number;

  /**
   * Padding around the graph
   */
  marginx: number;
  marginy: number;
}

/**
 * Default layout options.
 * Uses vertical (TB) orientation to reduce horizontal sprawl.
 */
export const DEFAULT_LAYOUT_OPTIONS: LayoutOptions = {
  rankdir: 'TB',
  nodesep: 60,
  ranksep: 100,
  marginx: 20,
  marginy: 20,
};

/**
 * Apply dagre layout to graph data.
 *
 * Mutates the nodes in-place to add x, y coordinates.
 *
 * @param graph - The graph data
 * @param options - Layout options
 * @returns The graph with layout coordinates applied
 */
export function applyLayout(
  graph: GraphData,
  options: LayoutOptions = DEFAULT_LAYOUT_OPTIONS
): GraphData {
  // Create a new dagre graph
  const g = new dagre.graphlib.Graph();

  // Set graph options
  g.setGraph({
    rankdir: options.rankdir,
    nodesep: options.nodesep,
    ranksep: options.ranksep,
    marginx: options.marginx,
    marginy: options.marginy,
  });

  // Default edge configuration
  g.setDefaultEdgeLabel(() => ({}));

  // Add nodes to dagre
  graph.nodes.forEach((node) => {
    g.setNode(node.id, {
      width: node.width,
      height: node.height,
    });
  });

  // Add edges to dagre
  graph.edges.forEach((edge) => {
    g.setEdge(edge.source, edge.target);
  });

  // Run the layout algorithm
  dagre.layout(g);

  // Extract layout coordinates and apply to nodes
  graph.nodes.forEach((node) => {
    const dagreNode = g.node(node.id);
    if (dagreNode) {
      node.x = dagreNode.x;
      node.y = dagreNode.y;
    }
  });

  return graph;
}

/**
 * Calculate the bounding box of the graph.
 * Useful for determining SVG viewBox dimensions.
 */
export function getGraphBounds(graph: GraphData): {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
  width: number;
  height: number;
} {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;

  graph.nodes.forEach((node) => {
    if (node.x !== undefined && node.y !== undefined) {
      // Account for node dimensions
      const halfWidth = node.width / 2;
      const halfHeight = node.height / 2;

      minX = Math.min(minX, node.x - halfWidth);
      minY = Math.min(minY, node.y - halfHeight);
      maxX = Math.max(maxX, node.x + halfWidth);
      maxY = Math.max(maxY, node.y + halfHeight);
    }
  });

  // Add padding
  const padding = 40;
  minX -= padding;
  minY -= padding;
  maxX += padding;
  maxY += padding;

  return {
    minX,
    minY,
    maxX,
    maxY,
    width: maxX - minX,
    height: maxY - minY,
  };
}

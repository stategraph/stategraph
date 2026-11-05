'use client';

/**
 * Dependency Graph Visualization Component
 *
 * Core principles:
 * 1. Always scoped - shows only selected resource and its immediate relationships
 * 2. Depth-limited - never shows more than configured maximum
 * 3. Hover-first interaction - primary way to explore relationships
 * 4. Refuses to render illegible graphs
 *
 * Hover behavior:
 * - Emphasizes the hovered node
 * - Highlights direct dependencies (incoming edges) in one style
 * - Highlights direct dependents (outgoing edges) in another style
 * - Dims all unrelated nodes and edges
 *
 * Visual distinction:
 * - Root node is larger and uses accent color
 * - Dependencies (things root depends on) use neutral styling
 * - Dependents (things that depend on root) use neutral styling
 * - Edge direction is always clear via arrows
 */

import { useEffect, useRef, useState } from 'react';
import * as d3 from 'd3';
import { ZoomIn, ZoomOut, Maximize2 } from 'lucide-react';
import type { GraphData, GraphNode, GraphEdge } from '@/lib/graph';
import { applyLayout, getGraphBounds, VALUE_KINDS } from '@/lib/graph';
import { Button } from '@/components/ui/button';

interface DependencyGraphProps {
  graph: GraphData;
  onNodeClick?: (node: GraphNode) => void;
}

/**
 * Renders an interactive dependency graph using SVG and D3.
 *
 * The graph is intentionally scoped and defensive:
 * - Only shows the selected resource and its direct relationships
 * - Refuses to render if the graph would be illegible
 * - Makes hover the primary interaction for exploration
 */
export function DependencyGraph({
  graph,
  onNodeClick,
}: DependencyGraphProps) {
  const svgRef = useRef<SVGSVGElement>(null);
  const zoomRef = useRef<d3.ZoomBehavior<SVGSVGElement, unknown> | null>(null);
  const [zoomLevel, setZoomLevel] = useState(1);

  // Zoom control functions
  const handleZoomIn = () => {
    if (svgRef.current && zoomRef.current) {
      d3.select(svgRef.current)
        .transition()
        .duration(300)
        .call(zoomRef.current.scaleBy, 1.3);
    }
  };

  const handleZoomOut = () => {
    if (svgRef.current && zoomRef.current) {
      d3.select(svgRef.current)
        .transition()
        .duration(300)
        .call(zoomRef.current.scaleBy, 0.7);
    }
  };

  const handleZoomReset = () => {
    if (svgRef.current && zoomRef.current) {
      d3.select(svgRef.current)
        .transition()
        .duration(300)
        .call(zoomRef.current.transform, d3.zoomIdentity);
    }
  };

  useEffect(() => {
    if (!svgRef.current) return;

    // Apply layout to graph
    const layoutGraph = applyLayout(graph);
    const bounds = getGraphBounds(layoutGraph);

    // Clear existing content
    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove();

    // Set viewBox to fit graph bounds
    svg.attr(
      'viewBox',
      `${bounds.minX} ${bounds.minY} ${bounds.width} ${bounds.height}`
    );

    // Create container group for zoom/pan
    const g = svg.append('g').attr('class', 'zoom-container');

    // Setup zoom behavior
    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.1, Infinity]) // Min zoom 10%, no max limit
      .on('start', () => {
        svg.style('cursor', 'grabbing');
      })
      .on('zoom', (event) => {
        g.attr('transform', event.transform);
        setZoomLevel(event.transform.k);
      })
      .on('end', () => {
        svg.style('cursor', 'grab');
      });

    // Apply zoom to SVG
    svg.call(zoom);

    // Store zoom behavior for controls
    zoomRef.current = zoom;

    // Define arrow markers for edges
    // Standard arrow for normal edges
    svg
      .append('defs')
      .append('marker')
      .attr('id', 'arrowhead')
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 8)
      .attr('refY', 0)
      .attr('markerWidth', 6)
      .attr('markerHeight', 6)
      .attr('orient', 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('fill', 'var(--sg-border)');

    // Highlighted arrow for dependencies (incoming to hovered)
    // Vibrant blue - matches incoming edge highlight
    svg
      .select('defs')
      .append('marker')
      .attr('id', 'arrowhead-dependency')
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 8)
      .attr('refY', 0)
      .attr('markerWidth', 7)
      .attr('markerHeight', 7)
      .attr('orient', 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('fill', '#2563eb'); // Vibrant blue

    // Highlighted arrow for dependents (outgoing from hovered)
    // Vibrant purple - matches outgoing edge highlight
    svg
      .select('defs')
      .append('marker')
      .attr('id', 'arrowhead-dependent')
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 8)
      .attr('refY', 0)
      .attr('markerWidth', 7)
      .attr('markerHeight', 7)
      .attr('orient', 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('fill', '#7c3aed'); // Vibrant purple

    // Draw edges first (so they appear behind nodes)
    const edges = g
      .append('g')
      .attr('class', 'edges')
      .selectAll('g')
      .data(layoutGraph.edges)
      .join('g')
      .attr('class', 'edge');

    edges.each(function (edge: GraphEdge) {
      const sourceNode = layoutGraph.nodes.find((n) => n.id === edge.source);
      const targetNode = layoutGraph.nodes.find((n) => n.id === edge.target);

      if (
        sourceNode &&
        sourceNode.x !== undefined &&
        sourceNode.y !== undefined &&
        targetNode &&
        targetNode.x !== undefined &&
        targetNode.y !== undefined
      ) {
        // Store coordinates to avoid TypeScript narrowing issues
        const sx = sourceNode.x;
        const sy = sourceNode.y;
        const sh = sourceNode.height;
        const tx = targetNode.x;
        const ty = targetNode.y;
        const th = targetNode.height;

        // Draw edge as a path
        d3.select(this)
          .append('path')
          .attr('class', 'edge-path')
          .attr('data-source', edge.source)
          .attr('data-target', edge.target)
          .attr('d', `M ${sx} ${sy + sh / 2} L ${tx} ${ty - th / 2}`)
          .attr('fill', 'none')
          .attr('stroke', 'var(--sg-border)')
          .attr('stroke-width', 2)
          // A [binds] edge is a module call filling a child variable: the dependency is real but
          // it is a wiring step rather than a value the author wrote, so it is drawn broken.  The
          // dash is set once, here, and no hover handler touches it.
          .attr('stroke-dasharray', edge.kind === 'binds' ? '5 4' : null)
          .attr('marker-end', 'url(#arrowhead)')
          .attr('opacity', 0.4);  // Lower default opacity for subtlety
      }
    });

    // Draw nodes
    const nodes = g
      .append('g')
      .attr('class', 'nodes')
      .selectAll('g')
      .data(layoutGraph.nodes)
      .join('g')
      .attr('class', 'node')
      .attr('data-node-id', (d: GraphNode) => d.id)
      .attr('transform', (d: GraphNode) => `translate(${d.x! - d.width / 2}, ${d.y! - d.height / 2})`)
      .style('cursor', 'pointer');

    // Add tooltip title to each node group
    nodes.append('title').text((d: GraphNode) => {
      const lines = [
        `Address: ${d.address}`,
        `Type: ${d.type}`,
      ];
      if (d.provider) lines.push(`Provider: ${d.provider}`);
      if (d.module) lines.push(`Module: ${d.module}`);
      if (d.attributes?.name) lines.push(`Name: ${d.attributes.name}`);
      if (d.attributes?.id) lines.push(`ID: ${d.attributes.id}`);
      return lines.join('\n');
    });

    // Node rectangles
    nodes
      .append('rect')
      .attr('class', 'node-rect')
      .attr('width', (d: GraphNode) => d.width)
      .attr('height', (d: GraphNode) => d.height)
      // A block that only holds a value is drawn as a pill, one that acts as a rounded rect. The
      // graph now includes the intermediates a change travels through -- a locals entry, a
      // variable -- and drawing them the same size as a resource would bury the resources among
      // the wiring between them.
      .attr('rx', (d: GraphNode) => (isValueKind(d) ? d.height / 2 : 6))
      .attr('ry', (d: GraphNode) => (isValueKind(d) ? d.height / 2 : 6))
      .attr('fill', (d: GraphNode) => {
        if (d.isRoot) return 'var(--sg-accent)';
        if (isValueKind(d)) return 'var(--sg-bg-2)';
        return 'var(--sg-bg-1)';
      })
      .attr('stroke', (d: GraphNode) => {
        if (d.isRoot) return 'var(--sg-accent)';
        return 'var(--sg-border)';
      })
      // A data source is read and never applied, so its border is broken.
      .attr('stroke-dasharray', (d: GraphNode) => (d.kind === 'data' && !d.isRoot ? '4 3' : null))
      .attr('stroke-width', (d: GraphNode) => (d.isRoot ? 3 : 1.5));

    // Node labels - Name (first line) - human-readable identifier
    nodes
      .append('text')
      .attr('class', 'node-name')
      .attr('x', (d: GraphNode) => d.width / 2)
      .attr('y', (d: GraphNode) => d.height / 2 - 8)
      .attr('text-anchor', 'middle')
      .attr('font-size', (d: GraphNode) => d.isRoot ? '12px' : '11px')
      .attr('font-weight', '700')
      .attr('fill', (d: GraphNode) =>
        d.isRoot ? 'white' : 'var(--sg-text)'
      )
      .attr('pointer-events', 'none')
      .text((d: GraphNode) => truncateText(getHumanName(d), d.isRoot ? 20 : 18));

    // Node labels - Type (second line for root) - what kind of resource
    nodes
      .filter((d: GraphNode) => d.isRoot)
      .append('text')
      .attr('class', 'node-type')
      .attr('x', (d: GraphNode) => d.width / 2)
      .attr('y', (d: GraphNode) => d.height / 2 + 6)
      .attr('text-anchor', 'middle')
      .attr('font-size', '9px')
      .attr('font-weight', '400')
      .attr('fill', 'rgba(255, 255, 255, 0.7)')
      .attr('pointer-events', 'none')
      .text((d: GraphNode) => truncateText(formatResourceType(d.type ?? d.kind), 22));

    // Node labels - Address (second line for non-root nodes, allow wrapping)
    nodes
      .filter((d: GraphNode) => !d.isRoot)
      .each(function(d: GraphNode) {
        const textElement = d3.select(this)
          .append('text')
          .attr('class', 'node-address')
          .attr('x', d.width / 2)
          .attr('text-anchor', 'middle')
          .attr('font-size', '8px')
          .attr('font-weight', '400')
          .attr('fill', 'var(--sg-text-muted)')
          .attr('pointer-events', 'none');

        // Split address into chunks that fit within node width
        const words = d.address.split('.');
        const lines: string[] = [];
        let currentLine = '';

        words.forEach((word) => {
          const testLine = currentLine ? `${currentLine}.${word}` : word;
          // Rough estimate: each char is ~5px at 8px font
          if (testLine.length * 5 > d.width - 10) {
            if (currentLine) lines.push(currentLine);
            currentLine = word;
          } else {
            currentLine = testLine;
          }
        });
        if (currentLine) lines.push(currentLine);

        // Add tspans for each line
        lines.forEach((line, i) => {
          textElement
            .append('tspan')
            .attr('x', d.width / 2)
            .attr('dy', i === 0 ? (d.height / 2 + 6) : 10)
            .text(line);
        });
      });

    // Root node label (add "selected" indicator)
    nodes
      .filter((d: GraphNode) => d.isRoot)
      .append('text')
      .attr('x', (d: GraphNode) => d.width / 2)
      .attr('y', -10)
      .attr('text-anchor', 'middle')
      .attr('font-size', '9px')
      .attr('font-weight', '700')
      .attr('letter-spacing', '0.05em')
      .attr('fill', 'var(--sg-accent)')
      .attr('pointer-events', 'none')
      .text('SELECTED');

    // Hover interactions
    // Hover is the PRIMARY interaction - it explains relationships clearly
    // The visual hierarchy must make relationships obvious without text
    nodes
      .on('mouseenter', function (event: MouseEvent, d: GraphNode) {
        // Find incoming edges (dependencies - things this node depends on)
        const incomingEdges = layoutGraph.edges.filter(e => e.target === d.id);
        const dependencies = new Set(incomingEdges.map(e => e.source));

        // Find outgoing edges (dependents - things that depend on this node)
        const outgoingEdges = layoutGraph.edges.filter(e => e.source === d.id);
        const dependents = new Set(outgoingEdges.map(e => e.target));

        // All connected nodes
        const connectedIds = new Set<string>([d.id, ...dependencies, ...dependents]);

        // Apply visual hierarchy to nodes:
        // 1. Hovered node: full brightness + emphasis
        // 2. Connected nodes: full brightness but less emphasis
        // 3. Unrelated nodes: aggressively ghosted
        svg.selectAll('.node').each(function(node: unknown) {
          const n = node as GraphNode;
          const nodeGroup = d3.select(this);
          const nodeRect = nodeGroup.select('.node-rect');

          if (n.id === d.id) {
            // HOVERED NODE: maximum emphasis
            nodeGroup.attr('opacity', 1);
            nodeRect
              .attr('stroke-width', 5)
              .attr('filter', 'drop-shadow(0 6px 16px rgba(0,0,0,0.3))')
              .attr('stroke', d.isRoot ? 'var(--sg-accent)' : 'var(--sg-text)');
          } else if (connectedIds.has(n.id)) {
            // CONNECTED NODES: fully visible but no emphasis
            nodeGroup.attr('opacity', 1);
          } else {
            // UNRELATED NODES: nearly ghosted
            nodeGroup.attr('opacity', 0.08);
          }
        });

        // Apply visual hierarchy to edges with strong directional signaling:
        // - Incoming edges (dependencies): vibrant blue, thick
        // - Outgoing edges (dependents): vibrant purple, thick
        // - Unrelated edges: nearly invisible
        svg.selectAll('.edge-path').each(function(edge: unknown) {
          const e = edge as GraphEdge;
          const path = d3.select(this);

          if (e.target === d.id) {
            // INCOMING EDGE (dependency): vibrant blue
            // This shows what the hovered node DEPENDS ON
            path
              .attr('opacity', 1)
              .attr('stroke', '#2563eb')  // Stronger blue
              .attr('stroke-width', 3.5)
              .attr('marker-end', 'url(#arrowhead-dependency)');
          } else if (e.source === d.id) {
            // OUTGOING EDGE (dependent): vibrant purple
            // This shows what DEPENDS ON the hovered node
            path
              .attr('opacity', 1)
              .attr('stroke', '#7c3aed')  // Stronger purple
              .attr('stroke-width', 3.5)
              .attr('marker-end', 'url(#arrowhead-dependent)');
          } else {
            // UNRELATED EDGE: nearly invisible
            path.attr('opacity', 0.02);
          }
        });

        // Slightly boost text contrast for connected nodes
        svg.selectAll('.node').each(function(node: unknown) {
          const n = node as GraphNode;
          if (connectedIds.has(n.id) && n.id !== d.id) {
            d3.select(this).select('.node-type')
              .attr('font-weight', '700');
            d3.select(this).select('.node-address')
              .attr('font-weight', '600');
          }
        });
      })
      .on('mouseleave', function () {
        // Reset to baseline state - all visual modifications must be reverted

        // Reset node opacity
        svg.selectAll('.node').attr('opacity', 1);

        // Reset edges to baseline
        svg.selectAll('.edge-path')
          .attr('opacity', 0.4)
          .attr('stroke', 'var(--sg-border)')
          .attr('stroke-width', 2)
          .attr('marker-end', 'url(#arrowhead)');

        // Reset all node visual properties
        svg.selectAll('.node').each(function() {
          const nodeData = d3.select(this).datum() as GraphNode;
          const nodeGroup = d3.select(this);

          // Reset rectangle stroke and filter
          nodeGroup
            .select('.node-rect')
            .attr('stroke-width', nodeData.isRoot ? 3 : 1.5)
            .attr('stroke', nodeData.isRoot ? 'var(--sg-accent)' : 'var(--sg-border)')
            .attr('filter', 'none');

          // Reset text font-weight
          nodeGroup
            .select('.node-type')
            .attr('font-weight', '600');
          nodeGroup
            .select('.node-address')
            .attr('font-weight', '400');
        });
      })
      .on('click', (event: MouseEvent, d: GraphNode) => {
        event.stopPropagation();
        onNodeClick?.(d);
      });
  }, [graph, onNodeClick]);

  return (
    <div className="relative w-full h-full" style={{ minHeight: '500px' }}>
      {/* Zoom Controls */}
      <div className="absolute top-4 right-4 z-10 flex flex-col gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={handleZoomIn}
          className="w-10 h-10 p-0"
          title="Zoom in"
        >
          <ZoomIn className="w-4 h-4" />
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={handleZoomOut}
          className="w-10 h-10 p-0"
          title="Zoom out"
        >
          <ZoomOut className="w-4 h-4" />
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={handleZoomReset}
          className="w-10 h-10 p-0"
          title="Reset zoom"
        >
          <Maximize2 className="w-4 h-4" />
        </Button>
        {/* Zoom level indicator */}
        <div className="px-2 py-1 text-xs text-center bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded">
          {Math.round(zoomLevel * 100)}%
        </div>
      </div>

      {/* SVG Canvas */}
      <svg
        ref={svgRef}
        className="w-full h-full"
        style={{ minHeight: '500px', cursor: 'grab' }}
      />
    </div>
  );
}

/**
 * Truncate text to a maximum length with ellipsis.
 */
function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength - 1) + '…';
}

/**
 * Extract a human-readable name from a graph node.
 * Priority:
 * 1. attributes.name (if exists)
 * 2. attributes.id (if exists and looks friendly)
 * 3. Last part of address (e.g., "updates" from "module.api.aws_sns_topic.updates")
 */
/** A block that only holds a value: a locals entry, a variable, an output. */
function isValueKind(node: GraphNode): boolean {
  return VALUE_KINDS.has(node.kind);
}

function getHumanName(node: GraphNode): string {
  // For a block that holds a value the address *is* the name. Trimming `local.mid` to `mid` throws
  // away the half that says what it is, and the whole reason such a node is drawn at all is to
  // show the route a change takes through it.
  if (isValueKind(node)) return node.address;

  // Try attributes.name first
  if (node.attributes?.name && typeof node.attributes.name === 'string') {
    return node.attributes.name;
  }

  // Try attributes.id if it looks human-friendly (not an ARN or UUID)
  if (node.attributes?.id && typeof node.attributes.id === 'string') {
    const id = node.attributes.id;
    // Skip if it looks like an ARN, UUID, or long hash
    if (!id.startsWith('arn:') && id.length < 50 && !id.match(/^[0-9a-f]{8}-[0-9a-f]{4}-/)) {
      return id;
    }
  }

  // Fall back to last part of address
  const parts = node.address.split('.');
  return parts[parts.length - 1] || node.address;
}

/**
 * Format a resource type for display.
 * Just removes the provider prefix and returns the type.
 * Example: "aws_api_gateway_deployment" -> "api_gateway_deployment"
 */
function formatResourceType(type: string): string {
  // Remove provider prefix (aws_, google_, azurerm_, etc.)
  return type.replace(/^[a-z]+_/, '');
}

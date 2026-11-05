/**
 * Tests for graph transformation utilities.
 *
 * THE FIRST TEST IS THE POINT OF THE WHOLE CHANGE. The previous transform received a flat list of
 * affected instances and had to invent the shape, so it drew every dependent as a direct child of
 * the root: `a -> local.mid -> b -> c` came out as a STAR around `a`, and `local.mid` was not
 * drawn at all. That test asserts the path AND asserts the absence of the star edges, so the
 * regression cannot come back looking like a pass.
 */

import { transformBlastRadiusToGraph, getGraphStats } from './transform';
import { DEFAULT_GRAPH_LIMITS } from './types';
import type { InstanceBlastRadiusResponse, BlastRadiusNode, BlastRadiusEdge } from '@/lib/api/client';

function node(
  id: string,
  address: string,
  kind: string,
  extra: Partial<BlastRadiusNode> = {}
): BlastRadiusNode {
  return {
    id,
    address,
    kind,
    module_address: '',
    state_id: 's1',
    state_name: 'prod',
    is_seed: false,
    instance_addresses: [],
    instance_count: 0,
    ...extra,
  };
}

/** The wire spells the dependency: `from` depends on `to`. */
function edge(from: string, to: string, kind: BlastRadiusEdge['kind'] = 'reads'): BlastRadiusEdge {
  return { from_id: from, to_id: to, kind, attr_path: [] };
}

/** a -> local.mid -> b -> c, seeded at a. Three hops, one of them a locals entry. */
const chain: InstanceBlastRadiusResponse = {
  root_id: 'a',
  truncated: false,
  total_nodes: 4,
  nodes: [
    node('a', 'terraform_data.a', 'resource', { is_seed: true, instance_count: 1 }),
    node('mid', 'local.mid', 'locals'),
    node('b', 'terraform_data.b', 'resource', { instance_count: 1 }),
    node('c', 'terraform_data.c', 'resource', { instance_count: 1 }),
  ],
  edges: [edge('mid', 'a'), edge('b', 'mid'), edge('c', 'b')],
};

let passedTests = 0;
let failedTests = 0;

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

async function runTests() {
  const tests = [
    {
      name: 'a transitive chain is a PATH and not a star',
      fn: () => {
        const { graph, refusal, error } = transformBlastRadiusToGraph(chain);
        assert(error === null, 'no error expected');
        assert(refusal === null, 'no refusal expected');
        if (!graph) throw new Error('expected a graph');

        const drawn = graph.edges
          .map((e) => `${e.source}->${e.target}`)
          .sort()
          .join(',');
        // Edges point the way the value flows: a -> mid -> b -> c.
        assert(drawn === 'a->mid,b->c,mid->b', `edges were ${drawn}`);

        // The star. Both of these would exist if the shape were invented from a flat list.
        assert(
          !graph.edges.some((e) => e.source === 'a' && e.target === 'b'),
          'a->b is a star edge and must not exist'
        );
        assert(
          !graph.edges.some((e) => e.source === 'a' && e.target === 'c'),
          'a->c is a star edge and must not exist'
        );

        // The intermediate is drawn, because it is how the change travels.
        assert(
          graph.nodes.some((n) => n.address === 'local.mid' && n.kind === 'locals'),
          'local.mid is a node of the graph'
        );
      },
    },
    {
      name: 'distance is BFS over the edges, not a field',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph(chain);
        if (!graph) throw new Error('expected a graph');
        const d = Object.fromEntries(graph.nodes.map((n) => [n.id, n.distance]));
        assert(d.a === 0, `a should be 0, got ${d.a}`);
        assert(d.mid === 1, `mid should be 1, got ${d.mid}`);
        assert(d.b === 2, `b should be 2, got ${d.b}`);
        assert(d.c === 3, `c should be 3, got ${d.c}`);
        assert(graph.maxDistance === 3, `maxDistance should be 3, got ${graph.maxDistance}`);
      },
    },
    {
      name: 'the wire direction is flipped: `from depends on to` becomes source=to',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({
          root_id: 'p',
          truncated: false,
          total_nodes: 2,
          nodes: [node('p', 'local.p', 'locals', { is_seed: true }), node('c', 'terraform_data.c', 'resource')],
          // c depends on p.
          edges: [edge('c', 'p')],
        });
        if (!graph) throw new Error('expected a graph');
        assert(graph.edges.length === 1, 'one edge');
        // The value flows p -> c, so p is the source. Reverse this and dagre draws the graph
        // upside down and every arrowhead points backwards.
        assert(graph.edges[0].source === 'p', 'source is the depended-upon node');
        assert(graph.edges[0].target === 'c', 'target is the dependent node');
      },
    },
    {
      name: 'a cycle terminates and every node gets a distance',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({
          root_id: 'a',
          truncated: false,
          total_nodes: 2,
          nodes: [node('a', 'x.a', 'resource', { is_seed: true }), node('b', 'x.b', 'resource')],
          edges: [edge('b', 'a'), edge('a', 'b')],
        });
        if (!graph) throw new Error('expected a graph');
        assert(graph.nodes.length === 2, 'both nodes');
        assert(graph.nodes.every((n) => n.distance >= 0), 'every node has a distance');
      },
    },
    {
      name: 'the shortest path wins when a node is reachable two ways',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({
          root_id: 'a',
          truncated: false,
          total_nodes: 3,
          nodes: [
            node('a', 'x.a', 'resource', { is_seed: true }),
            node('m', 'local.m', 'locals'),
            node('d', 'x.d', 'resource'),
          ],
          // d depends on a directly and also through m.
          edges: [edge('m', 'a'), edge('d', 'a'), edge('d', 'm')],
        });
        if (!graph) throw new Error('expected a graph');
        const d = graph.nodes.find((n) => n.id === 'd');
        assert(d?.distance === 1, `d should be 1 by the direct edge, got ${d?.distance}`);
        // Both routes are still drawn: the answer is the graph, not one spanning tree of it.
        assert(graph.edges.length === 3, `all three edges kept, got ${graph.edges.length}`);
      },
    },
    {
      name: 'an edge naming a node that is not in the response is dropped',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({
          root_id: 'a',
          truncated: false,
          total_nodes: 1,
          nodes: [node('a', 'x.a', 'resource', { is_seed: true })],
          edges: [edge('ghost', 'a')],
        });
        if (!graph) throw new Error('expected a graph');
        assert(graph.edges.length === 0, 'a half edge points at nothing drawable');
      },
    },
    {
      name: 'a block kind the client does not know becomes `other`, never a guess',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({
          root_id: 'a',
          truncated: false,
          total_nodes: 1,
          nodes: [node('a', 'moved.thing', 'moved', { is_seed: true })],
          edges: [],
        });
        if (!graph) throw new Error('expected a graph');
        assert(graph.nodes[0].kind === 'other', `got ${graph.nodes[0].kind}`);
        assert(graph.nodes[0].type === undefined, 'no type is invented from the address');
      },
    },
    {
      name: 'server truncation is carried through, not swallowed',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({ ...chain, truncated: true });
        if (!graph) throw new Error('expected a graph');
        assert(graph.truncation.serverTruncated, 'the graph says it is partial');
      },
    },
    {
      // The flag alone cannot carry this: it is also true for an ordinary depth cut, so only the
      // two counts tell a viewer how much of the answer the node cap removed.
      name: 'the node cap is carried as two counts, not only as a flag',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph({
          ...chain,
          truncated: true,
          total_nodes: 90,
        });
        if (!graph) throw new Error('expected a graph');
        assert(graph.truncation.serverTotalNodes === 90, 'the reached count survives');
        assert(
          graph.truncation.serverReturnedNodes === chain.nodes.length,
          'the returned count is what the wire carried'
        );
      },
    },
    {
      name: 'an uncut answer reports the two counts equal',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph(chain);
        if (!graph) throw new Error('expected a graph');
        assert(
          graph.truncation.serverTotalNodes === graph.truncation.serverReturnedNodes,
          'nothing was cut, so nothing is claimed to be'
        );
      },
    },
    {
      name: 'an empty response is an empty graph, not an error',
      fn: () => {
        const { graph, refusal, error } = transformBlastRadiusToGraph({
          root_id: '',
          truncated: false,
          total_nodes: 0,
          nodes: [],
          edges: [],
        });
        assert(error === null && refusal === null, 'neither an error nor a refusal');
        assert(graph !== null && graph.nodes.length === 0, 'an empty graph');
      },
    },
    {
      name: 'a response with no root node is an ERROR and not a refusal',
      fn: () => {
        const { graph, refusal, error } = transformBlastRadiusToGraph({
          root_id: 'missing',
          truncated: false,
          total_nodes: 1,
          nodes: [node('a', 'x.a', 'resource')],
          edges: [],
        });
        assert(graph === null, 'no graph');
        // A contract failure must not be dressed up as an intentional product decision.
        assert(refusal === null, 'not a refusal');
        assert(error !== null, 'an error');
      },
    },
    {
      name: 'too many direct relationships is refused',
      fn: () => {
        const n = DEFAULT_GRAPH_LIMITS.maxDirectRelationships + 1;
        const nodes = [node('a', 'x.a', 'resource', { is_seed: true })];
        const edges: BlastRadiusEdge[] = [];
        for (let i = 0; i < n; i++) {
          nodes.push(node(`d${i}`, `x.d${i}`, 'resource'));
          edges.push(edge(`d${i}`, 'a'));
        }
        const { graph, refusal } = transformBlastRadiusToGraph({
          root_id: 'a',
          truncated: false,
          total_nodes: nodes.length,
          nodes,
          edges,
        });
        assert(graph === null, 'no graph');
        assert(refusal?.type === 'direct_relationships', 'refused for direct relationships');
        assert(refusal?.actualCount === n, `counted ${refusal?.actualCount}`);
      },
    },
    {
      name: 'a refusal says when the count is a lower bound',
      fn: () => {
        const n = DEFAULT_GRAPH_LIMITS.maxDirectRelationships + 1;
        const nodes = [node('a', 'x.a', 'resource', { is_seed: true })];
        const edges: BlastRadiusEdge[] = [];
        for (let i = 0; i < n; i++) {
          nodes.push(node(`d${i}`, `x.d${i}`, 'resource'));
          edges.push(edge(`d${i}`, 'a'));
        }
        const { refusal } = transformBlastRadiusToGraph({
          root_id: 'a',
          truncated: true,
          total_nodes: nodes.length,
          nodes,
          edges,
        });
        assert(refusal?.serverTruncated === true, 'the refusal carries the truncation');
      },
    },
    {
      name: 'stats count resources, not every block on the path',
      fn: () => {
        const { graph } = transformBlastRadiusToGraph(chain);
        if (!graph) throw new Error('expected a graph');
        const stats = getGraphStats(graph);
        // b and c. `local.mid` is on the path but nobody applies a locals entry.
        assert(stats.affectedResources === 2, `got ${stats.affectedResources}`);
        assert(stats.directDependents === 1, `got ${stats.directDependents}`);
        assert(stats.maxDepth === 3, `got ${stats.maxDepth}`);
        assert(stats.statesTouched === 1, `got ${stats.statesTouched}`);
      },
    },
  ];

  for (const test of tests) {
    try {
      test.fn();
      console.log(`✓ ${test.name}`);
      passedTests++;
    } catch (err) {
      console.error(`✗ ${test.name}`);
      console.error(`  ${err instanceof Error ? err.message : String(err)}`);
      failedTests++;
    }
  }

  console.log(`\nTests: ${passedTests} passed, ${failedTests} failed`);
  process.exit(failedTests > 0 ? 1 : 0);
}

runTests();

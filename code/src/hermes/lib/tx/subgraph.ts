import { executeMQL } from "@/lib/api/client";
import { sqlLiteral } from "@/lib/mql/escape";
import { MQL_MAX_LIMIT, asNumber, asText } from "@/lib/mql/providers";

// ── Transaction subgraph (assembled client-side via MQL) ─────────────────────
// Reconstructs what the removed GET /api/v1/tx/{tx_id}/subgraph endpoint
// returned: nodes from transaction_subgraphs, edges from the reads of each node's
// block (hcl_refs, tf_module_hcl_refs) and of its module call. The UI
// composes the subgraph itself rather than the backend growing a bespoke
// endpoint, which is why this is an MQL builder here and not an API call in
// lib/api/client.ts (reserved for api.json endpoints). Tenant scoping is
// enforced by the MQL CTEs, so this only ever sees the caller's tenants. NB:
// each MQL query is capped at SUBGRAPH_LIMIT rows, so subgraphs larger than
// that truncate.

export type TxSubgraphDirection = "seed" | "cone" | "blast";

export interface TxSubgraphNode {
  /** "<state_id>:<node_id>" — matches the old backend composite id. */
  id: string;
  state_id: string;
  address: string;
  /** null when the node is in the root module (empty module_address). */
  module_path: string | null;
  direction: TxSubgraphDirection;
  /** Only hcl nodes are assembled (both queries filter on node_type = 'hcl'). */
  node_type: "hcl";
  depth: number;
}

export interface TxSubgraphEdge {
  /** "<state_id>:<source_node_id>" */
  source: string;
  /** "<state_id>:<target_node_id>" */
  target: string;
}

export interface TxSubgraphResponse {
  nodes: TxSubgraphNode[];
  edges: TxSubgraphEdge[];
}

interface SubgraphNodeRow {
  state_id?: unknown;
  node_id?: unknown;
  address?: unknown;
  module_path?: unknown;
  direction?: unknown;
  depth?: unknown;
}

// One read of a subgraph node: the address it names, in the coordinates of the
// body that holds the node.
interface SubgraphRefRow {
  state_id?: unknown;
  node_id?: unknown;
  module_path?: unknown;
  ref?: unknown;
}

// A module call of the subgraph and the reads of each of its arguments.
interface SubgraphCallRow {
  state_id?: unknown;
  address?: unknown;
  module_path?: unknown;
  module_input_edges?: unknown;
}

interface ModuleInputEdge {
  input: string;
  to_addr: string;
}

const moduleInputEdges = (v: unknown): ModuleInputEdge[] => {
  const parsed = typeof v === "string" ? safeParse(v) : v;
  if (!Array.isArray(parsed)) return [];
  return parsed.flatMap((e) =>
    e && typeof e === "object" && typeof e.input === "string" && typeof e.to_addr === "string"
      ? [{ input: e.input, to_addr: e.to_addr }]
      : [],
  );
};

const safeParse = (s: string): unknown => {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
};

// The address of a read at a module: a body names its own blocks and the
// outputs of its own calls, relative to the body, thus the read of a node at
// module [module.a] names [module.a.<ref>].
const atModule = (modulePath: string | null, ref: string): string =>
  modulePath ? `${modulePath}.${ref}` : ref;

const optText = (v: unknown): string | null => {
  const t = asText(v);
  return t.length > 0 ? t : null;
};

// "<state_id>:<node_id>" — matches the old backend composite_id.
const subgraphCompositeId = (stateId: string, nodeId: string): string =>
  `${stateId}:${nodeId}`;

// Mirrors the old OCaml mapping: unknown directions fall back to "seed".
const toSubgraphDirection = (v: unknown): TxSubgraphDirection =>
  v === "cone" || v === "blast" ? v : "seed";

const SUBGRAPH_LIMIT = Math.min(1000, MQL_MAX_LIMIT);

// RFD 1008 Phase 2: a block of a module body is stored one time, whatever calls
// it, thus no table holds a node of a module call.  A subgraph row names its
// instance -- its address, its module and the body row of its block -- and this
// loader makes the edges of the instances as the walk does: the reads of the body
// row, at the module of the instance, and the read of a child variable, which is
// what the argument of its call reads.
export async function getTxSubgraphViaMQL(txId: string): Promise<TxSubgraphResponse> {
  const id = sqlLiteral(txId);

  const nodesQuery = `select
      ts.state_id as state_id,
      ts.item->>'node_id' as node_id,
      ts.item->>'fq_address' as address,
      nullif(coalesce(ts.item->>'module_address', ''), '') as module_path,
      ts.direction as direction,
      ts.depth as depth
    from transaction_subgraphs as ts
    where ts.tx_id = ${id}
      and ts.node_type = 'hcl'
    order by ts.state_id, ts.item->>'module_address', ts.item->>'fq_address'
    limit ${SUBGRAPH_LIMIT}`;

  // The reads of a node of the root: its [hcl_refs] rows.
  const rootRefsQuery = `select
      ts.state_id as state_id,
      ts.item->>'node_id' as node_id,
      null as module_path,
      hr.ref as ref
    from transaction_subgraphs as ts, hcl_refs as hr
    where ts.tx_id = ${id}
      and ts.node_type = 'hcl'
      and coalesce(ts.item->'body'->>'source', '') = ''
      and hr.state_id = ts.state_id
      and hr.id = ts.item->>'node_id'
    limit ${SUBGRAPH_LIMIT}`;

  // The reads of a node of a body: the [tf_module_hcl_refs] rows of its body row.
  const bodyRefsQuery = `select
      ts.state_id as state_id,
      ts.item->>'node_id' as node_id,
      nullif(coalesce(ts.item->>'module_address', ''), '') as module_path,
      r.ref as ref
    from transaction_subgraphs as ts, tf_module_hcl_refs as r
    where ts.tx_id = ${id}
      and ts.node_type = 'hcl'
      and coalesce(ts.item->'body'->>'source', '') <> ''
      and r.state_id = ts.state_id
      and r.source = ts.item->'body'->>'source'
      and r.version = ts.item->'body'->>'version'
      and r.id = ts.item->'body'->>'id'
    limit ${SUBGRAPH_LIMIT}`;

  // The module calls of the subgraph, of the root and of a body, with the reads
  // of their arguments.
  const callsQuery = `select
      ts.state_id as state_id,
      ts.item->>'fq_address' as address,
      nullif(coalesce(ts.item->>'module_address', ''), '') as module_path,
      coalesce(h.module_input_edges, b.module_input_edges) as module_input_edges
    from transaction_subgraphs as ts
    left join hcl as h
      on h.state_id = ts.state_id
     and coalesce(ts.item->'body'->>'source', '') = ''
     and h.id = ts.item->>'node_id'
    left join tf_module_hcl as b
      on b.state_id = ts.state_id
     and b.source = ts.item->'body'->>'source'
     and b.version = ts.item->'body'->>'version'
     and b.id = ts.item->'body'->>'id'
    where ts.tx_id = ${id}
      and ts.node_type = 'hcl'
      and coalesce(h.module_input_edges, b.module_input_edges) is not null
    limit ${SUBGRAPH_LIMIT}`;

  const [nodesRes, rootRefsRes, bodyRefsRes, callsRes] = await Promise.all([
    executeMQL(nodesQuery),
    executeMQL(rootRefsQuery),
    executeMQL(bodyRefsQuery),
    executeMQL(callsQuery),
  ]);

  const nodes: TxSubgraphNode[] = (nodesRes.data as SubgraphNodeRow[]).map((r) => {
    const stateId = asText(r.state_id);
    const nodeId = asText(r.node_id);
    return {
      id: subgraphCompositeId(stateId, nodeId),
      state_id: stateId,
      address: asText(r.address),
      module_path: optText(r.module_path),
      direction: toSubgraphDirection(r.direction),
      node_type: "hcl",
      depth: asNumber(r.depth),
    };
  });

  // The node of each address, in each state.
  const byAddress = new Map<string, string>(
    nodes.map((n) => [subgraphCompositeId(n.state_id, n.address), n.id]),
  );
  const nodeAt = (stateId: string, address: string): string | undefined =>
    byAddress.get(subgraphCompositeId(stateId, address));

  const refEdges: TxSubgraphEdge[] = [
    ...(rootRefsRes.data as SubgraphRefRow[]),
    ...(bodyRefsRes.data as SubgraphRefRow[]),
  ].flatMap((r) => {
    const stateId = asText(r.state_id);
    const target = nodeAt(stateId, atModule(optText(r.module_path), asText(r.ref)));
    return target
      ? [{ source: subgraphCompositeId(stateId, asText(r.node_id)), target }]
      : [];
  });

  // A child variable reads what the argument of its call reads, at the module of
  // the call.
  const callEdges: TxSubgraphEdge[] = (callsRes.data as SubgraphCallRow[]).flatMap((r) => {
    const stateId = asText(r.state_id);
    const callAddress = asText(r.address);
    const modulePath = optText(r.module_path);
    return moduleInputEdges(r.module_input_edges).flatMap((e) => {
      const source = nodeAt(stateId, `${callAddress}.var.${e.input}`);
      const target = nodeAt(stateId, atModule(modulePath, e.to_addr));
      return source && target ? [{ source, target }] : [];
    });
  });

  const seen = new Set<string>();
  const edges = [...refEdges, ...callEdges]
    .filter((e) => {
      const key = `${e.source}\u0000${e.target}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) =>
      a.source === b.source ? a.target.localeCompare(b.target) : a.source.localeCompare(b.source),
    );

  return { nodes, edges };
}

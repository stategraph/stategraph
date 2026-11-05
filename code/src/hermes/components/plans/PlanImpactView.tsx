"use client";

import { useEffect, useMemo, useState } from "react";
import type { TxDetailResponse, TxPlanOperation } from "@/lib/api/client";
import { getTxSubgraphViaMQL, type TxSubgraphResponse } from "@/lib/tx/subgraph";
import { isResourceAddress } from "@/lib/graph";
import { OP_CLASS, OP_GLYPH, OP_LABEL } from "@/lib/plan/op-meta";
import type { Operation } from "@/lib/plan/tree";

interface PlanImpactViewProps {
  detail: TxDetailResponse;
  planOperations: TxPlanOperation[];
}

interface TreeLine {
  prefix: string;
  address: string;
  shared?: boolean;
}

interface SeedTree {
  address: string;
  operation: Operation;
  lines: TreeLine[];
}

// Collapses the raw subgraph into a resource-only adjacency. Stategraph
// edges point UPSTREAM (source depends on target) and pass through HCL
// intermediaries (vars / outputs / module boundaries), so we invert them
// and run one BFS per resource that emits the first resources reachable
// on each path. Done once per subgraph so the walker is plain DFS — no
// re-BFS through the same intermediaries on every visit.
function buildResourceAdjacency(subgraph: TxSubgraphResponse): {
  idToAddress: Map<string, string>;
  resourceDownAdj: Map<string, string[]>;
} {
  const idToAddress = new Map<string, string>();
  for (const n of subgraph.nodes) idToAddress.set(n.id, n.address);

  const rawDown = new Map<string, string[]>();
  for (const e of subgraph.edges) {
    if (!rawDown.has(e.target)) rawDown.set(e.target, []);
    rawDown.get(e.target)!.push(e.source);
  }

  const resourceDownAdj = new Map<string, string[]>();
  for (const [id, addr] of idToAddress) {
    if (!isResourceAddress(addr)) continue;
    const out: string[] = [];
    const queue: string[] = [...(rawDown.get(id) ?? [])];
    const seen = new Set<string>([id]);
    while (queue.length) {
      const childId = queue.shift()!;
      if (seen.has(childId)) continue;
      seen.add(childId);
      const childAddr = idToAddress.get(childId);
      if (childAddr && isResourceAddress(childAddr)) {
        out.push(childId);
      } else {
        queue.push(...(rawDown.get(childId) ?? []));
      }
    }
    out.sort((a, b) =>
      idToAddress.get(a)!.localeCompare(idToAddress.get(b)!),
    );
    resourceDownAdj.set(id, out);
  }
  return { idToAddress, resourceDownAdj };
}

// Visits the downstream resource subgraph from `nodeId`. Per-seed visited
// set so diamonds render their full subtree the first time and mark
// subsequent occurrences with `shared`.
function walk(
  nodeId: string,
  prefix: string,
  resourceDownAdj: Map<string, string[]>,
  idToAddress: Map<string, string>,
  visited: Set<string>,
  lines: TreeLine[],
) {
  const children = resourceDownAdj.get(nodeId) ?? [];
  children.forEach((childId, i) => {
    const isLast = i === children.length - 1;
    const branch = isLast ? "└── " : "├── ";
    const continuation = isLast ? "    " : "│   ";
    const addr = idToAddress.get(childId)!;
    if (visited.has(childId)) {
      lines.push({ prefix: prefix + branch, address: addr, shared: true });
      return;
    }
    visited.add(childId);
    lines.push({ prefix: prefix + branch, address: addr });
    walk(childId, prefix + continuation, resourceDownAdj, idToAddress, visited, lines);
  });
}

function buildSeedTrees(
  subgraph: TxSubgraphResponse,
  opByAddress: Map<string, Operation>,
): SeedTree[] {
  const { idToAddress, resourceDownAdj } = buildResourceAdjacency(subgraph);
  const trees: SeedTree[] = [];
  for (const node of subgraph.nodes) {
    if (node.direction !== "seed") continue;
    if (!isResourceAddress(node.address)) continue;
    const op = opByAddress.get(node.address);
    if (!op) continue;
    const lines: TreeLine[] = [];
    walk(node.id, "", resourceDownAdj, idToAddress, new Set([node.id]), lines);
    trees.push({ address: node.address, operation: op, lines });
  }
  trees.sort((a, b) => a.address.localeCompare(b.address));
  return trees;
}

const COLLAPSE_THRESHOLD = 25;

function SeedTreeBlock({ tree }: { tree: SeedTree }) {
  const [expanded, setExpanded] = useState(false);
  const oversized = tree.lines.length > COLLAPSE_THRESHOLD;
  const visibleLines =
    !oversized || expanded ? tree.lines : tree.lines.slice(0, COLLAPSE_THRESHOLD);
  const hidden = tree.lines.length - visibleLines.length;

  return (
    <div className="font-mono text-xs leading-5 whitespace-pre overflow-x-auto">
      <div>
        <span className={OP_CLASS[tree.operation]} title={OP_LABEL[tree.operation]}>
          ●
        </span>{" "}
        <span className={OP_CLASS[tree.operation]}>{OP_GLYPH[tree.operation]}</span>{" "}
        <span className="text-[var(--sg-text)]">{tree.address}</span>{" "}
        <span className="text-[var(--sg-text-dim)]">({OP_LABEL[tree.operation]})</span>
      </div>
      {tree.lines.length === 0 ? (
        <div className="text-[var(--sg-text-dim)] italic pl-4">
          (nothing downstream)
        </div>
      ) : (
        visibleLines.map((l, i) => (
          <div key={i}>
            <span className="text-[var(--sg-text-muted)]">{l.prefix}</span>
            <span className="text-[var(--sg-text)]">{l.address}</span>
            {l.shared && (
              <span className="text-[var(--sg-text-dim)]">  …</span>
            )}
          </div>
        ))
      )}
      {oversized && (
        <button
          type="button"
          onClick={() => setExpanded((e) => !e)}
          className="mt-1 text-xs text-[var(--sg-accent)] hover:underline cursor-pointer"
        >
          {expanded
            ? `Show less`
            : `Show all ${tree.lines.length} downstream (${hidden} hidden) →`}
        </button>
      )}
    </div>
  );
}

export function PlanImpactView({ detail, planOperations }: PlanImpactViewProps) {
  const [loaded, setLoaded] = useState<{
    id: string;
    subgraph: TxSubgraphResponse | null;
    error: string | null;
  } | null>(null);

  useEffect(() => {
    let cancelled = false;
    getTxSubgraphViaMQL(detail.tx.id)
      .then((s) => {
        if (!cancelled)
          setLoaded({ id: detail.tx.id, subgraph: s, error: null });
      })
      .catch((e) => {
        if (!cancelled)
          setLoaded({
            id: detail.tx.id,
            subgraph: null,
            error: e instanceof Error ? e.message : "Failed to load impact",
          });
      });
    return () => {
      cancelled = true;
    };
  }, [detail.tx.id]);

  // Derive loading/error from the loaded result rather than resetting state
  // synchronously inside the effect (react-hooks/set-state-in-effect). While a
  // newer tx.id is in flight, loaded.id won't match and we show loading again.
  const isCurrent = loaded?.id === detail.tx.id;
  const loading = !isCurrent;
  const error = isCurrent ? loaded!.error : null;
  const subgraph = isCurrent ? loaded!.subgraph : null;

  const opByAddress = useMemo(() => {
    const m = new Map<string, Operation>();
    for (const op of planOperations) m.set(op.address, op.operation);
    return m;
  }, [planOperations]);

  const seedTrees = useMemo(
    () => (subgraph ? buildSeedTrees(subgraph, opByAddress) : null),
    [subgraph, opByAddress],
  );

  if (loading) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading impact…</div>
    );
  }
  if (error) {
    return <div className="p-8 text-sm text-[var(--sg-error)]">{error}</div>;
  }
  if (!seedTrees) return null;

  if (seedTrees.length === 0) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        No resource changes recorded for this run.
      </div>
    );
  }

  return (
    <div className="p-6 space-y-4">
      <p className="text-xs text-[var(--sg-text-muted)]">
        Change cone — each tree starts at a changing resource and branches into
        what the change propagates to. <code>…</code> marks a node already
        shown above in the same tree. Trees with more than{" "}
        {COLLAPSE_THRESHOLD} downstream nodes collapse by default.
      </p>
      <div className="space-y-4">
        {seedTrees.map((tree) => (
          <SeedTreeBlock key={tree.address} tree={tree} />
        ))}
      </div>
    </div>
  );
}

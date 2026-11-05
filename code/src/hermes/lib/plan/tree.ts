import type { TxPlanOperation } from "@/lib/api/client";

export type Operation = TxPlanOperation["operation"];

export interface PlanTreeNode {
  /** Stable id, the full terraform-style address up to this node. */
  id: string;
  /** Short label rendered in the row (e.g. "module.foo", "aws_instance.web"). */
  label: string;
  /** Module nodes carry the resources nested under them. Resource leaves have []. */
  children: PlanTreeNode[];
  kind: "module" | "resource";
  /** Only set on resource leaves. */
  operation?: Operation;
  /** Aggregate counts of leaf operations beneath this node. For a leaf the
   *  counts are 1 for its own op and 0 elsewhere. */
  counts: OpCounts;
}

export interface OpCounts {
  create: number;
  update: number;
  replace: number;
  destroy: number;
  noop: number;
}

export const zeroCounts: OpCounts = {
  create: 0,
  update: 0,
  replace: 0,
  destroy: 0,
  noop: 0,
};

export function addCounts(a: OpCounts, b: OpCounts): OpCounts {
  return {
    create: a.create + b.create,
    update: a.update + b.update,
    replace: a.replace + b.replace,
    destroy: a.destroy + b.destroy,
    noop: a.noop + b.noop,
  };
}

export function countsForOp(op: Operation): OpCounts {
  // Every operation maps to its like-named count. The "noop" bucket stays in
  // OpCounts for renderers but is always 0 — the API only persists real ops.
  return { ...zeroCounts, [op]: 1 };
}

/**
 * Split a terraform address into its module path and the leaf resource label.
 *
 *  - "aws_instance.web"                            → { modules: [],         leaf: "aws_instance.web" }
 *  - "module.foo.aws_instance.web"                 → { modules: ["foo"],    leaf: "aws_instance.web" }
 *  - "module.foo.module.bar.aws_instance.web[0]"   → { modules: ["foo","bar"], leaf: "aws_instance.web[0]" }
 *  - "module.foo.data.aws_caller.current"          → { modules: ["foo"],    leaf: "data.aws_caller.current" }
 *
 * Index suffixes (`[0]`, `["key"]`) ride along with the leaf, since terraform
 * never puts a `.` inside the bracket.
 */
export function splitAddress(address: string): { modules: string[]; leaf: string } {
  const tokens = address.split(".");
  const modules: string[] = [];
  let i = 0;
  while (i + 1 < tokens.length - 1 && tokens[i] === "module") {
    modules.push(tokens[i + 1]);
    i += 2;
  }
  return { modules, leaf: tokens.slice(i).join(".") };
}

/**
 * Strip the synthetic `module.state_<hex>.` wrapper that stategraph adds when
 * it composes per-state HCL into a single tofu run. This module exists only
 * in the actuator's tmpdir and would be confusing noise to surface.
 */
export function stripStateWrapper(address: string): string {
  return address.replace(/^module\.state_[0-9a-f]+\./, "");
}

interface BuildOptions {
  /** Defaults to true. */
  stripStateWrapper?: boolean;
}

/**
 * Build the root of a plan tree from a flat operation list. The returned root
 * has no label of its own; render its children at the top level.
 */
export function buildPlanTree(
  ops: readonly TxPlanOperation[],
  opts: BuildOptions = {},
): PlanTreeNode {
  const strip = opts.stripStateWrapper ?? true;
  const root: PlanTreeNode = {
    id: "",
    label: "",
    kind: "module",
    children: [],
    counts: { ...zeroCounts },
  };
  // Walk each op, materialising any missing intermediate module nodes. We
  // keep an index map for O(depth) insertion rather than rescanning children.
  const indexByPath = new Map<string, PlanTreeNode>();
  indexByPath.set("", root);

  for (const op of ops) {
    const address = strip ? stripStateWrapper(op.address) : op.address;
    const { modules, leaf } = splitAddress(address);

    let parentPath = "";
    let parent = root;
    for (const mod of modules) {
      const path = parentPath === "" ? `module.${mod}` : `${parentPath}.module.${mod}`;
      let node = indexByPath.get(path);
      if (!node) {
        node = {
          id: path,
          label: `module.${mod}`,
          kind: "module",
          children: [],
          counts: { ...zeroCounts },
        };
        parent.children.push(node);
        indexByPath.set(path, node);
      }
      parent = node;
      parentPath = path;
    }

    const leafPath = parentPath === "" ? leaf : `${parentPath}.${leaf}`;
    const leafNode: PlanTreeNode = {
      id: leafPath,
      label: leaf,
      kind: "resource",
      operation: op.operation,
      children: [],
      counts: countsForOp(op.operation),
    };
    parent.children.push(leafNode);
  }

  // Second pass: bubble leaf counts up to every ancestor module. Done after
  // construction so callers can rely on `counts` being the final aggregate.
  function aggregate(node: PlanTreeNode): OpCounts {
    if (node.kind === "resource") return node.counts;
    let acc = { ...zeroCounts };
    for (const child of node.children) acc = addCounts(acc, aggregate(child));
    node.counts = acc;
    return acc;
  }
  aggregate(root);

  // Stable sort: modules above resources, then alphabetical by label. This
  // keeps the visual hierarchy obvious even when terraform emits ops in some
  // dependency-driven order.
  function sort(node: PlanTreeNode): void {
    node.children.sort((a, b) => {
      if (a.kind !== b.kind) return a.kind === "module" ? -1 : 1;
      return a.label.localeCompare(b.label);
    });
    for (const child of node.children) sort(child);
  }
  sort(root);

  return root;
}

/**
 * Whether a node should be visible given a (lowercased) address-substring
 * filter. A node passes if its own id matches, or any descendant resource
 * matches. We bias toward keeping module nodes visible so the path to a
 * match is preserved.
 */
export function nodeMatches(node: PlanTreeNode, needle: string): boolean {
  if (!needle) return true;
  if (node.id.toLowerCase().includes(needle)) return true;
  return node.children.some((c) => nodeMatches(c, needle));
}

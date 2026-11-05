"use client";

import {
  useEffect,
  useMemo,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";
import { ChevronDown, ChevronRight, Folder, Box, X } from "lucide-react";
import { useUrlSyncedNullable } from "@/hooks/useUrlSyncedParam";
import {
  buildPlanTree,
  type OpCounts,
  type Operation,
  type PlanTreeNode,
  nodeMatches,
} from "@/lib/plan/tree";
import { parsePlanStdoutByAddress } from "@/lib/plan/snippets";
import { OP_CLASS, OP_GLYPH, OP_LABEL } from "@/lib/plan/op-meta";
import { PlanOutput } from "./PlanOutput";
import type { TxPlanOperation } from "@/lib/api/client";

interface PlanTreeViewProps {
  planOperations: TxPlanOperation[];
  /** tofu's plan text, when captured; without it the side panel has no snippet. */
  planStdout?: string | null;
}

function OpCountChip({ counts }: { counts: OpCounts }) {
  // Match terraform's own counting: a replace counts as both add and destroy.
  const adds = counts.create + counts.replace;
  const destroys = counts.destroy + counts.replace;
  const parts = [
    adds > 0 ? (
      <span key="+" className={OP_CLASS.create}>
        +{adds}
      </span>
    ) : null,
    counts.update > 0 ? (
      <span key="~" className={OP_CLASS.update}>
        ~{counts.update}
      </span>
    ) : null,
    destroys > 0 ? (
      <span key="-" className={OP_CLASS.destroy}>
        -{destroys}
      </span>
    ) : null,
  ].filter(Boolean);
  if (parts.length === 0) return null;
  return (
    <span className="font-mono text-xs flex items-center gap-2">
      {parts}
    </span>
  );
}

// Enter/Space activate a div that behaves as a button, matching native
// button keyboard semantics for the clickable tree rows.
const onRowKeyDown =
  (action: () => void) => (e: ReactKeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      action();
    }
  };

// URL param that deep-links the open resource side panel, so a Tree view is
// shareable/bookmarkable per hermes deep-linking convention.
const RESOURCE_PARAM = "resource";

interface RowProps {
  node: PlanTreeNode;
  depth: number;
  expanded: Set<string>;
  toggle: (id: string) => void;
  filter: string;
  selectedId: string | null;
  onSelect: (node: PlanTreeNode) => void;
}

function TreeRow({
  node,
  depth,
  expanded,
  toggle,
  filter,
  selectedId,
  onSelect,
}: RowProps) {
  const visible = nodeMatches(node, filter);
  if (!visible) return null;
  const isOpen = expanded.has(node.id);

  const pad = `${depth * 1}rem`;

  if (node.kind === "module") {
    return (
      <>
        <div
          className="flex items-center gap-2 px-2 py-1 hover:bg-[var(--sg-bg-2)] cursor-pointer text-sm select-none"
          role="button"
          tabIndex={0}
          aria-expanded={isOpen}
          onClick={() => toggle(node.id)}
          onKeyDown={onRowKeyDown(() => toggle(node.id))}
          style={{ paddingLeft: pad }}
        >
          <span className="w-4 h-4 flex items-center justify-center text-[var(--sg-text-muted)]">
            {isOpen ? (
              <ChevronDown className="w-3.5 h-3.5" />
            ) : (
              <ChevronRight className="w-3.5 h-3.5" />
            )}
          </span>
          <Folder className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
          <span className="text-[var(--sg-text)] font-medium">{node.label}</span>
          <span className="ml-auto pr-2">
            <OpCountChip counts={node.counts} />
          </span>
        </div>
        {isOpen &&
          node.children.map((child) => (
            <TreeRow
              key={child.id}
              node={child}
              depth={depth + 1}
              expanded={expanded}
              toggle={toggle}
              filter={filter}
              selectedId={selectedId}
              onSelect={onSelect}
            />
          ))}
      </>
    );
  }

  const op = node.operation ?? "no-op";

  const isSelected = selectedId === node.id;
  return (
    <div
      className={`flex items-center gap-2 px-2 py-1 cursor-pointer text-sm select-none ${
        isSelected
          ? "bg-[var(--sg-accent-bg)]"
          : "hover:bg-[var(--sg-bg-2)]"
      }`}
      style={{ paddingLeft: pad }}
      title={node.id}
      role="button"
      tabIndex={0}
      aria-pressed={isSelected}
      onClick={() => onSelect(node)}
      onKeyDown={onRowKeyDown(() => onSelect(node))}
    >
      {/* spacer to align with the module chevron */}
      <span className="w-4 h-4" />
      <Box className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
      <span
        className={`font-mono ${OP_CLASS[op]} w-4 inline-block text-center`}
        title={OP_LABEL[op]}
      >
        {OP_GLYPH[op]}
      </span>
      <span className="text-[var(--sg-text)] font-mono text-xs">{node.label}</span>
    </div>
  );
}

interface SnippetPanelProps {
  address: string;
  operation: Operation | undefined;
  snippet: string | undefined;
  onClose: () => void;
}

function SnippetPanel({ address, operation, snippet, onClose }: SnippetPanelProps) {
  const op = operation ?? "no-op";
  return (
    <aside className="w-1/2 max-w-2xl min-w-[24rem] border-l border-[var(--sg-border)] flex flex-col overflow-hidden">
      <header className="flex items-center gap-3 px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)]">
        <span
          className={`font-mono ${OP_CLASS[op]} font-bold`}
          title={OP_LABEL[op]}
        >
          {OP_GLYPH[op]}
        </span>
        <span
          className="font-mono text-xs text-[var(--sg-text)] truncate"
          title={address}
        >
          {address}
        </span>
        <button
          type="button"
          onClick={onClose}
          className="ml-auto p-1 rounded hover:bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
          aria-label="Close panel"
          title="Close (Esc)"
        >
          <X className="w-3.5 h-3.5" />
        </button>
      </header>
      <div className="flex-1 overflow-auto">
        {snippet ? (
          <PlanOutput text={snippet} />
        ) : (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">
            No plan output captured for this resource.
          </div>
        )}
      </div>
    </aside>
  );
}

export function PlanTreeView({ planOperations, planStdout }: PlanTreeViewProps) {
  const tree = useMemo(
    () => buildPlanTree(planOperations),
    [planOperations],
  );

  // Expanded module ids. Default: every module is open if the plan has 50
  // or fewer leaves, otherwise only the top-level modules expand and the
  // user can drill from there. Larger plans need the room more than they
  // need the immediate detail.
  const [expanded, setExpanded] = useState<Set<string>>(() => {
    const ids = new Set<string>();
    const totalLeaves =
      tree.counts.create +
      tree.counts.update +
      tree.counts.replace +
      tree.counts.destroy;
    const everything = totalLeaves <= 50;
    function visit(node: PlanTreeNode, isTopLevel: boolean) {
      if (node.kind !== "module") return;
      if (everything || isTopLevel) ids.add(node.id);
      for (const c of node.children) visit(c, false);
    }
    for (const c of tree.children) visit(c, true);
    return ids;
  });

  const toggle = (id: string) =>
    setExpanded((cur) => {
      const next = new Set(cur);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const [filter, setFilterRaw] = useState("");
  const lowerFilter = filter.trim().toLowerCase();

  // When the user types a filter, auto-expand every ancestor of a match so
  // the path to the match is visible without manual drilling. Cleared when
  // the filter empties.
  useEffect(() => {
    if (!lowerFilter) return;
    setExpanded((cur) => {
      const next = new Set(cur);
      function visit(node: PlanTreeNode) {
        if (node.kind !== "module") return;
        if (nodeMatches(node, lowerFilter)) {
          next.add(node.id);
          for (const c of node.children) visit(c);
        }
      }
      for (const c of tree.children) visit(c);
      return next;
    });
  }, [lowerFilter, tree]);

  const expandAll = () => {
    const ids = new Set<string>();
    function visit(node: PlanTreeNode) {
      if (node.kind === "module") ids.add(node.id);
      for (const c of node.children) visit(c);
    }
    for (const c of tree.children) visit(c);
    setExpanded(ids);
  };

  const collapseAll = () => setExpanded(new Set());

  // Total module nodes in the tree. When zero, expand-all / collapse-all
  // have no work to do, so we render them disabled instead of leaving the
  // user wondering if they're broken.
  const moduleCount = useMemo(() => {
    let n = 0;
    function visit(node: PlanTreeNode) {
      if (node.kind === "module") n++;
      for (const c of node.children) visit(c);
    }
    for (const c of tree.children) visit(c);
    return n;
  }, [tree]);

  // Parse the verbatim terraform plan output once per detail, so clicking a
  // resource row can show its block in the side panel without re-scanning.
  const snippets = useMemo(
    () => parsePlanStdoutByAddress(planStdout),
    [planStdout],
  );

  // Side-panel selection. Selecting a module is a no-op (modules don't have
  // a tofu snippet of their own); selecting a resource opens the panel.
  // Re-selecting the same resource toggles it closed. The selection is
  // mirrored to the URL (?resource=) so the view is deep-linkable; on mount
  // we restore it, but only if it names a real resource in this plan.
  const [selectedParam, setSelectedId] = useUrlSyncedNullable(RESOURCE_PARAM);
  const selectedId =
    selectedParam && planOperations.some((o) => o.address === selectedParam)
      ? selectedParam
      : null;

  const onSelect = (node: PlanTreeNode) => {
    if (node.kind !== "resource") return;
    setSelectedId(selectedId === node.id ? null : node.id);
  };

  // selectedOp is derived from the operation map so we don't keep it in
  // state — the operation can't change underneath a selected id.
  const operationByAddress = useMemo(() => {
    const map = new Map<string, Operation>();
    for (const op of planOperations) {
      map.set(op.address, op.operation);
    }
    return map;
  }, [planOperations]);
  const selectedOp = selectedId
    ? operationByAddress.get(selectedId)
    : undefined;

  // Esc closes the panel — keyboard shortcut callers expect from any modal-
  // ish surface.
  useEffect(() => {
    if (!selectedId) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setSelectedId(null);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [selectedId, setSelectedId]);

  const totalLeaves =
    tree.counts.create +
    tree.counts.update +
    tree.counts.replace +
    tree.counts.destroy +
    tree.counts.noop;

  if (totalLeaves === 0) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        No resource changes in this plan.
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-3 px-6 py-2 border-b border-[var(--sg-border)] text-xs">
        <input
          value={filter}
          onChange={(e) => setFilterRaw(e.target.value)}
          placeholder="Filter by address…"
          aria-label="Filter resources by address"
          className="px-2 py-1 text-xs bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded text-[var(--sg-text)] placeholder:text-[var(--sg-text-muted)] flex-1 max-w-sm"
        />
        <button
          type="button"
          onClick={expandAll}
          disabled={moduleCount === 0}
          title={
            moduleCount === 0 ? "No modules in this plan" : "Expand every module"
          }
          className="cursor-pointer text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Expand all
        </button>
        <button
          type="button"
          onClick={collapseAll}
          disabled={moduleCount === 0}
          title={
            moduleCount === 0 ? "No modules in this plan" : "Collapse every module"
          }
          className="cursor-pointer text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Collapse all
        </button>
        <span className="ml-auto">
          <OpCountChip counts={tree.counts} />
        </span>
      </div>
      <div className="flex-1 flex overflow-hidden">
        <div className="flex-1 overflow-auto py-1 min-w-0">
          {tree.children.map((child) => (
            <TreeRow
              key={child.id}
              node={child}
              depth={0}
              expanded={expanded}
              toggle={toggle}
              filter={lowerFilter}
              selectedId={selectedId}
              onSelect={onSelect}
            />
          ))}
        </div>
        {selectedId && (
          <SnippetPanel
            address={selectedId}
            operation={selectedOp}
            snippet={snippets.get(selectedId)}
            onClose={() => setSelectedId(null)}
          />
        )}
      </div>
    </div>
  );
}

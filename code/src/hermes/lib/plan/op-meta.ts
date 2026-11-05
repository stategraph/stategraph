import type { TxPlanOperation, TxDetailResponse } from "@/lib/api/client";
import type { Operation } from "./tree";

/** Operation as rendered: the API's four ops plus the "no-op" placeholder used
 *  for nodes without an operation (module rows, unselected panels). The API
 *  enum itself has no no-op — the backend only persists real changes. */
export type DisplayOp = Operation | "no-op";

export const OP_GLYPH: Record<DisplayOp, string> = {
  create: "+",
  update: "~",
  replace: "±",
  destroy: "-",
  "no-op": " ",
};

export const OP_LABEL: Record<DisplayOp, string> = {
  create: "create",
  update: "update",
  replace: "replace",
  destroy: "destroy",
  "no-op": "no-op",
};

export const OP_CLASS: Record<DisplayOp, string> = {
  create: "text-[var(--sg-op-create)]",
  update: "text-[var(--sg-op-update)]",
  replace: "text-[var(--sg-op-replace)]",
  destroy: "text-[var(--sg-op-destroy)]",
  "no-op": "text-[var(--sg-text-dim)]",
};

export function opGlyphLabel(op: DisplayOp): string {
  return `${OP_GLYPH[op]} ${OP_LABEL[op]}`;
}

// Prefer terraform's own instance-level tally (parsed server-side from the plan
// output and served as tx.plan_summary). Runs without a captured summary (bulk
// apply / import) fall back to rolling up the per-instance plan_operations the
// detail already carries — terraform's counting rule, where a replace shows up
// under both add and destroy.
export function effectiveCounts(
  detail: TxDetailResponse,
  planOperations: TxPlanOperation[]
): {
  adds: number;
  changes: number;
  destroys: number;
  source: "stdout" | "ops";
} {
  const summary = detail.tx.plan_summary;
  if (summary)
    return {
      adds: summary.add,
      changes: summary.change,
      destroys: summary.destroy,
      source: "stdout",
    };
  let adds = 0;
  let changes = 0;
  let destroys = 0;
  for (const op of planOperations) {
    switch (op.operation) {
      case "create":
        adds += 1;
        break;
      case "replace":
        adds += 1;
        destroys += 1;
        break;
      case "update":
        changes += 1;
        break;
      case "destroy":
        destroys += 1;
        break;
    }
  }
  return { adds, changes, destroys, source: "ops" };
}

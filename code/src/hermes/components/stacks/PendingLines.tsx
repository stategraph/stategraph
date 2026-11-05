import type { PendingReasons } from "@/app/(console)/stacks/mqlQueries";

/** The pending explainer's "Pending plan of" / "Pending apply of" lines for one
 *  stack; with no blockers, the note saying why nothing is waiting. */
export function PendingLines({
  reasons,
  className,
}: {
  reasons?: PendingReasons;
  className?: string;
}) {
  if (!reasons) return null;
  const blocked = reasons.plan.length > 0 || reasons.apply.length > 0;
  if (!blocked && !reasons.note) return null;
  return (
    <div className={className}>
      {reasons.plan.length > 0 ? (
        <div className="min-w-0 text-xs text-[var(--sg-text-muted)] [overflow-wrap:anywhere]">
          Pending plan of: <span className="font-mono">{reasons.plan.join(", ")}</span>
        </div>
      ) : null}
      {reasons.apply.length > 0 ? (
        <div className="min-w-0 text-xs text-[var(--sg-text-muted)] [overflow-wrap:anywhere]">
          Pending apply of: <span className="font-mono">{reasons.apply.join(", ")}</span>
        </div>
      ) : null}
      {!blocked && reasons.note ? (
        <div className="min-w-0 text-xs text-[var(--sg-text-dim)] [overflow-wrap:anywhere]">{reasons.note}</div>
      ) : null}
    </div>
  );
}

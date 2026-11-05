"use client";

import { ChevronDown, ChevronRight } from "lucide-react";
import { DeepLink } from "@/components/navigation";
import {
  outerPendingReasons,
  type PendingReasons,
  type PrScope,
  type StackOuter,
} from "@/app/(console)/stacks/mqlQueries";
import type { VcsProvider } from "@/lib/vcs/links";
import { InnerStackRows } from "./InnerStackRows";
import { PendingLines } from "./PendingLines";
import { StackStateChip } from "./StackStateChip";

/**
 * One outer stack of a pull request: a row that expands to its inner stacks.
 * With `href` the stack name links to the stack page; with `reasons` the
 * pending explanations show (the outer summary while collapsed, per inner
 * stack once expanded).
 */
export function OuterStackRow({
  outer,
  index,
  expanded,
  onToggle,
  href,
  reasons,
  plans,
}: {
  outer: StackOuter;
  /** Position in plan order, shown 1-based. */
  index: number;
  expanded: boolean;
  onToggle: () => void;
  href?: string;
  reasons?: Map<string, PendingReasons>;
  /** The pull request whose plan runs the dirspace rows open. */
  plans?: { provider: VcsProvider; pr: PrScope };
}) {
  const dirspaces = outer.stacks.reduce((sum, i) => sum + i.dirspaces.length, 0);
  return (
    <div>
      {/* The whole row toggles through a button laid behind its content; a
          linked stack name is stacked above that button. */}
      <div className="relative flex items-center gap-2 px-4 py-2.5 hover:bg-[var(--sg-bg-2)]">
        <button
          type="button"
          onClick={onToggle}
          aria-expanded={expanded}
          aria-label={`${expanded ? "Collapse" : "Expand"} stack ${outer.name}`}
          className="absolute inset-0 cursor-pointer"
        />
        {expanded ? (
          <ChevronDown className="h-4 w-4 text-[var(--sg-text-muted)]" />
        ) : (
          <ChevronRight className="h-4 w-4 text-[var(--sg-text-muted)]" />
        )}
        <span className="text-xs tabular-nums text-[var(--sg-text-dim)]">{index + 1}.</span>
        {href ? (
          <DeepLink
            href={href}
            className="relative z-10 text-sm font-medium text-[var(--sg-text)] hover:text-[var(--sg-accent)] hover:underline"
          >
            {outer.name}
          </DeepLink>
        ) : (
          <span className="text-sm font-medium text-[var(--sg-text)]">{outer.name}</span>
        )}
        <StackStateChip state={outer.state} />
        <span className="ml-auto text-xs text-[var(--sg-text-muted)]">{dirspaces} dirspaces</span>
      </div>
      {reasons && !expanded ? (
        <PendingLines className="px-4 pb-2 -mt-1 space-y-0.5" reasons={outerPendingReasons(outer, reasons)} />
      ) : null}
      {expanded ? (
        <div className="border-t border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
          <InnerStackRows outer={outer} reasons={reasons} plans={plans} />
        </div>
      ) : null}
    </div>
  );
}

import { Layers } from "lucide-react";
import type { PendingReasons, PrScope, StackOuter } from "@/app/(console)/stacks/mqlQueries";
import type { VcsProvider } from "@/lib/vcs/links";
import { DirspacePlanRow } from "./DirspacePlanRow";
import { PendingLines } from "./PendingLines";
import { StackStateChip } from "./StackStateChip";

export function InnerStackRows({
  outer,
  reasons,
  showStates = true,
  plans,
}: {
  outer: StackOuter;
  /** Per-leaf pending reasons; lines render only for stacks present here. */
  reasons?: Map<string, PendingReasons>;
  /** False when the states behind this shape are not loaded, so no chip claims one. */
  showStates?: boolean;
  /** The pull request whose plan runs the dirspace rows open. */
  plans?: { provider: VcsProvider; pr: PrScope };
}) {
  return (
    <div className="divide-y divide-[var(--sg-border)]">
      {outer.stacks.map((inner, idx) => (
        <div key={`${idx}-${inner.name}`} className="px-4 py-2">
          <div className="flex items-center gap-2">
            <Layers className="h-3.5 w-3.5 text-[var(--sg-text-muted)]" />
            <span className="text-sm text-[var(--sg-text)]">{inner.name}</span>
            {showStates ? <StackStateChip state={inner.state} /> : null}
          </div>
          <PendingLines className="pl-6 mt-1 space-y-1" reasons={reasons?.get(inner.name)} />
          <div className="mt-1.5 space-y-1">
            {inner.dirspaces.map((d) => {
              const className = "flex items-center gap-2 pl-6 text-xs text-[var(--sg-text-muted)]";
              const body = (
                <>
                  {/* A deep path wraps the row at phone width, so truncate and
                      keep the full value on hover, as the tables do. */}
                  <span className="font-mono truncate" title={d.dir}>
                    {d.dir}
                  </span>
                  {d.workspace !== "default" ? (
                    <span className="font-mono shrink-0 text-[var(--sg-text-dim)]">
                      :{d.workspace}
                    </span>
                  ) : null}
                  {showStates ? <StackStateChip state={d.state} /> : null}
                </>
              );
              return plans ? (
                <DirspacePlanRow
                  key={`${d.dir}:${d.workspace}`}
                  provider={plans.provider}
                  pr={plans.pr}
                  dir={d.dir}
                  workspace={d.workspace}
                  className={className}
                >
                  {body}
                </DirspacePlanRow>
              ) : (
                <div key={`${d.dir}:${d.workspace}`} className={className}>
                  {body}
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

"use client";

import { useCallback, useRef, useState } from "react";
import { Layers } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useInitialLoad } from "@/hooks";
import { orchestrationUnavailable } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";
import {
  buildStateMap,
  dirspaceStatesQuery,
  mapDirspaceFactRow,
  mapPrStacksRow,
  overlayStacks,
  sortStacksDefaultLast,
  stacksQuery,
  type StackOuter,
} from "@/app/(console)/stacks/mqlQueries";
import { OuterStackRow } from "./OuterStackRow";

/**
 * Compact stacks panel for the PR detail page: the PR's stacks in plan order,
 * default stack last, with live states, self-loading, rendering nothing when the PR has no stored
 * stacks (or the server has no orchestration/stacks surface).
 */
export function PrStacksPanel({
  provider,
  repoId,
  pullNumber,
}: {
  provider: VcsProvider;
  repoId: number;
  pullNumber: number;
}) {
  const [stacks, setStacks] = useState<StackOuter[] | null>(null);
  const [open, setOpen] = useState<Record<string, boolean>>({});

  // This component stays mounted across ?pr= navigation and `load` re-runs on
  // every prop change, so an older in-flight pair must not overwrite a newer
  // one's tree: only the newest request is allowed to commit.
  const request = useRef(0);

  const load = useCallback(async () => {
    const mine = ++request.current;
    const pr = { repoId, pullNumber };
    // Reset first, so PR A's tree does not linger while PR B loads.
    setStacks(null);
    setOpen({});
    try {
      const [stacksRes, factsRes] = await Promise.all([
        executeMQL(stacksQuery(provider, pr)),
        executeMQL(dirspaceStatesQuery(provider, pr)),
      ]);
      if (mine !== request.current || stacksRes.data.length === 0) return;
      const row = mapPrStacksRow(provider, stacksRes.data[0]);
      const states = buildStateMap(factsRes.data.map((raw) => mapDirspaceFactRow(provider, raw)));
      setStacks(sortStacksDefaultLast(overlayStacks(row, states)));
    } catch (e: unknown) {
      // A server without the stacks surface is expected: hide, say nothing.
      // Anything else -- malformed stacks jsonb reaching JSON.parse, a
      // timeout, catalog drift -- is not, and silently hiding it made the
      // panel indistinguishable from a PR that genuinely has no stacks.
      if (!orchestrationUnavailable(e)) {
        console.warn("Stacks panel failed to load", e);
      }
    }
  }, [provider, repoId, pullNumber]);

  useInitialLoad(load);

  if (!stacks || stacks.length === 0) return null;

  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
      <div className="flex items-center gap-2 px-4 py-3 border-b border-[var(--sg-border)]">
        <Layers className="h-4 w-4 text-[var(--sg-text-muted)]" />
        <span className="text-sm font-medium text-[var(--sg-text)]">Stacks</span>
        <span className="text-xs text-[var(--sg-text-muted)]">in plan order, default stack last</span>
      </div>
      <div className="divide-y divide-[var(--sg-border)]">
        {stacks.map((outer, idx) => {
          // Position and name: outer names can repeat, and a new or reordered
          // stack must not inherit another stack's expanded state.
          const key = `${idx}-${outer.name}`;
          return (
            <OuterStackRow
              key={key}
              outer={outer}
              index={idx}
              expanded={!!open[key]}
              onToggle={() => setOpen((o) => ({ ...o, [key]: !o[key] }))}
              plans={{ provider, pr: { repoId, pullNumber } }}
            />
          );
        })}
      </div>
    </div>
  );
}

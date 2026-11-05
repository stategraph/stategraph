"use client";

import { useCallback, useMemo, useState } from "react";
import { GitPullRequest, Layers, RefreshCw } from "lucide-react";
import { useDeepLinkRouter, useInitialLoad } from "@/hooks";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { executeWithRetry, orchestrationUnavailable, runAcrossProviders } from "@/lib/mql/providers";
import { executeMQL } from "@/lib/api/client";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import { AsyncSection, PageHeader } from "@/components/page";
import { Checkbox } from "@/components/ui/checkbox";
import type { VcsProvider } from "@/lib/vcs/links";
import { prSigil } from "@/lib/vcs/links";
import { OuterStackRow } from "@/components/stacks";
import { ListToolbar } from "@/components/list";
import { matchesOwner, ownerFacetOptions } from "@/lib/vcs/ownerFacet";
import { matchesSearch } from "@/lib/ui/search";
import {
  DIRSPACE_FACTS_CAP,
  STACKS_PR_CAP,
  buildStateMap,
  dirspaceStatesQuery,
  explainerAvailable,
  mapDirspaceFactRow,
  mapPrStacksRow,
  overlayStacks,
  mapStacksConfigRow,
  sortStacksDefaultLast,
  stackDetailHref,
  pendingReasons,
  prStacksKey,
  stacksConfigQuery,
  stacksQuery,
  type PendingReasons,
  type PrStacksRow,
  type StackOuter,
  type StacksConfig,
} from "./mqlQueries";

interface PrEntry extends PrStacksRow {
  key: string;
  /** Stacks with live states overlaid and rolled up. */
  liveStacks: StackOuter[];
  /** The derived config's stacks section, when its repo_configs row exists. */
  config: StacksConfig | null;
  /** Per-leaf pending blockers, when the derived config row was available. */
  reasons: Map<string, PendingReasons>;
}

function PrStacksCard({ entry, showWhy }: { entry: PrEntry; showWhy: boolean }) {
  const router = useDeepLinkRouter();
  // Every card starts collapsed so the list reads as a compact index.
  const [open, setOpen] = useState<Record<string, boolean>>({});

  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
      <button
        {...router.nav(`/pull-requests/detail?provider=${entry.provider}&owner=${encodeURIComponent(entry.owner)}&repo=${encodeURIComponent(entry.repoName)}&pr=${encodeURIComponent(entry.pullNumber)}`)}
        className="w-full flex cursor-pointer items-center gap-3 px-4 py-3 text-left hover:bg-[var(--sg-bg-2)] border-b border-[var(--sg-border)]"
      >
        <GitPullRequest className="h-4 w-4 text-[var(--sg-text-muted)]" />
        <span className="font-mono text-xs text-[var(--sg-text-muted)]">
          {entry.owner}/{entry.repoName}
        </span>
        <span className="text-xs text-[var(--sg-text-dim)]">
          {prSigil(entry.provider)}
          {entry.pullNumber}
        </span>
        <span className="truncate text-sm text-[var(--sg-text)]">{entry.title}</span>
      </button>

      {/* Outer stacks in stored array order — the frozen PLAN order (the
          engine's toposort consumes plan_after edges only; apply_after
          ordering is enforced at apply time, which is exactly what the
          pending-explainer surfaces) — except the built-in default stack,
          which sortStacksDefaultLast moves to the end so it never reads as
          the headline. Keys pair position and name: outer names are not
          guaranteed unique (grouping is by successive first path element),
          and after a Refresh a new or reordered stack must not inherit
          another stack's expanded state. */}
      <div className="divide-y divide-[var(--sg-border)]">
        {entry.liveStacks.map((outer, idx) => {
          const key = `${idx}-${outer.name}`;
          return (
            <OuterStackRow
              key={key}
              outer={outer}
              index={idx}
              expanded={!!open[key]}
              onToggle={() => setOpen((o) => ({ ...o, [key]: !o[key] }))}
              href={stackDetailHref(entry.provider, entry.owner, entry.repoName, outer.name)}
              reasons={showWhy ? entry.reasons : undefined}
              plans={{ provider: entry.provider, pr: { repoId: entry.repository, pullNumber: Number(entry.pullNumber) } }}
            />
          );
        })}
      </div>
    </div>
  );
}

/**
 * Stacks tab (minimal tree v1, ported from iris): each open pull request's
 * stacks — outer stacks in plan order, default stack last, inner stacks, dirspaces — with live
 * states derived exactly like the engine derives them (latest completed work
 * manifest per dirspace at the PR's shas, unlock-aware) and rolled up with the
 * canonical severity ladder.
 */
export function StacksContent() {
  const [entries, setEntries] = useState<PrEntry[] | null>(null);
  // In the URL as ?why=1, so a shared link opens with the explanations on.
  const [why, setWhy] = useUrlSyncedParam("why", "");
  const showWhy = why === "1";
  const [query, setQuery] = useUrlSyncedParam("q", "");
  const [owner, setOwner] = useUrlSyncedParam("owner", "");
  const [failed, setFailed] = useState<VcsProvider[]>([]);
  // Two different truncations with two different symptoms, so they are two
  // flags: a capped stacks query drops whole pull requests from the list, a
  // capped facts query leaves dirspaces of the PRs that ARE listed without a
  // live state, so they render as the overlay's `no_changes` default.
  const [cappedPrs, setCappedPrs] = useState(false);
  const [cappedFacts, setCappedFacts] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      // The stacks and facts queries run inside ONE runAcrossProviders body, which is
      // all-or-nothing per provider. Issuing them as two independent loads
      // would let a provider's stacks succeed while its facts fail: every one
      // of that provider's dirspaces would then miss the state map and fall
      // back to the overlay's `no_changes` default, rendering a full tree of
      // grey "No changes" chips that looks authoritative and is uniformly
      // wrong. Dropping the provider entirely is the honest answer.
      const { results, failed: failedProviders } = await runAcrossProviders(async (p) => {
        const [stacksRows, factsRows, configs] = await Promise.all([
          executeWithRetry(stacksQuery(p)),
          executeWithRetry(dirspaceStatesQuery(p)),
          // Only the explainer reads the config, so its failure must not
          // reject this body: the tree loads without it.
          executeMQL(stacksConfigQuery(p)).then(
            (r) => r.data.map((raw) => mapStacksConfigRow(p, raw)),
            (e: unknown) => {
              console.warn("Stacks explainer config failed to load", e);
              return [];
            },
          ),
        ]);
        return {
          stacks: stacksRows.map((raw) => mapPrStacksRow(p, raw)),
          facts: factsRows.map((raw) => mapDirspaceFactRow(p, raw)),
          configs,
        };
      });
      const states = buildStateMap(results.flatMap((r) => r.value.facts));
      const configs = new Map<string, StacksConfig | null>();
      for (const c of results.flatMap((r) => r.value.configs)) {
        if (!configs.has(c.key)) configs.set(c.key, c.config);
      }
      setEntries(
        results.flatMap((r) =>
          r.value.stacks.map((row) => {
            const liveStacks = sortStacksDefaultLast(overlayStacks(row, states));
            const key = prStacksKey(row.provider, row.repository, row.pullNumber);
            const config = configs.get(key) ?? null;
            return { ...row, key, liveStacks, config, reasons: pendingReasons(liveStacks, config) };
          }),
        ),
      );
      setFailed(failedProviders);
      setCappedPrs(results.some((r) => r.value.stacks.length >= STACKS_PR_CAP));
      setCappedFacts(results.some((r) => r.value.facts.length >= DIRSPACE_FACTS_CAP));
    } catch (e: unknown) {
      if (orchestrationUnavailable(e)) {
        setUnavailable(true);
      } else {
        setError(e instanceof Error ? e.message : "Failed to load stacks");
      }
    }
  }, []);

  useInitialLoad(load);

  const sorted = useMemo(
    () => (entries ? [...entries].sort((a, b) => Number(b.pullNumber) - Number(a.pullNumber)) : null),
    [entries],
  );

  const explainer = sorted !== null && explainerAvailable(sorted, cappedFacts);
  // Nothing loaded AND a provider query failed (after its transient retry):
  // a load failure, not an empty tenant, so never "No stacks yet".
  const loadFailed = sorted !== null && sorted.length === 0 && failed.length > 0;
  const owners = useMemo(() => ownerFacetOptions(entries ?? []), [entries]);
  const filtered = useMemo(() => {
    if (sorted === null) return null;
    return sorted.filter((e) => {
      if (!matchesOwner(owner, e.provider, e.owner)) return false;
      if (
        !matchesSearch(
          query,
          `${e.owner}/${e.repoName} ${e.pullNumber} ${e.title} ${e.liveStacks.map((o) => o.name).join(" ")}`,
        )
      )
        return false;
      return true;
    });
  }, [sorted, query, owner]);

  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Stacks"
        subtitle="Each open pull request's stacks in plan order, default stack last, with live plan/apply state per dirspace"
      >
        <button
          onClick={() => void load()}
          className="p-1 rounded hover:bg-[var(--sg-bg-2)]"
          aria-label="Refresh"
        >
          <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
        </button>
      </PageHeader>

      <div className="flex-1 overflow-auto px-4 sm:px-6 py-4">
        {sorted !== null && sorted.length > 0 && (
          <ListToolbar
            search={query}
            onSearch={setQuery}
            placeholder="Search by repo, PR, title, stack…"
            filters={
              owners.length > 1 || owner
                ? [{ label: "Owners", value: owner, onChange: setOwner, options: owners }]
                : undefined
            }
          />
        )}
        {explainer ? (
          <div className="mb-3 flex items-center gap-2 w-fit">
            <Checkbox
              id="stacks-why"
              checked={showWhy}
              onCheckedChange={(v) => setWhy(v === true ? "1" : "")}
            />
            <label htmlFor="stacks-why" className="text-xs text-[var(--sg-text-muted)] cursor-pointer">
              Explain stack ordering (what each stack is waiting on, or why it is not waiting)
            </label>
          </div>
        ) : null}
        {failed.length > 0 && !loadFailed && (
          <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
            Could not load {failed.join(", ")} stacks — showing the rest.
          </div>
        )}
        {cappedPrs && (
          <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
            Showing the {STACKS_PR_CAP} most recent open pull requests — older ones are not listed.
          </div>
        )}
        {cappedFacts && (
          <div className="mb-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
            Too many dirspaces to state them all — some below display as “No changes” without being
            checked. Open a pull request for its exact stacks.
          </div>
        )}
        <AsyncSection
          loading={sorted === null && !error}
          error={error ?? (loadFailed ? `Could not load stacks (${failed.join(", ")} failed).` : null)}
          empty={sorted?.length === 0}
          emptyState={
            <OrchestrationEmptyState centered>
              <div className="flex flex-col items-center justify-center py-16 text-center">
                <Layers className="h-8 w-8 mb-3 text-[var(--sg-text-muted)]" />
                <div className="text-sm font-medium text-[var(--sg-text)]">No stacks yet</div>
                <div className="mt-1 max-w-md text-xs text-[var(--sg-text-muted)]">
                  Stacks appear here once an open pull request has been planned. Define them in{" "}
                  <span className="font-mono">.stategraph/config.yml</span> under{" "}
                  <span className="font-mono">stacks</span>; without one, every change lands in the
                  built-in default stack.
                </div>
              </div>
            </OrchestrationEmptyState>
          }
          onRetry={() => void load()}
        >
          {(filtered ?? []).length === 0 ? (
            <div className="p-8 text-sm text-[var(--sg-text-muted)]">No stacks match these filters.</div>
          ) : (
            <div className="space-y-4">
              {(filtered ?? []).map((entry) => (
                <PrStacksCard key={entry.key} entry={entry} showWhy={showWhy && explainer} />
              ))}
            </div>
          )}
        </AsyncSection>
      </div>
    </div>
  );
}

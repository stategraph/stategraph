"use client";

import { Suspense, useCallback, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowLeft, GitPullRequest, RefreshCw } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter, useInitialLoad } from "@/hooks";
import { AuthGuard } from "@/components/auth";
import { Breadcrumbs } from "@/components/list/Breadcrumbs";
import { DeepLink } from "@/components/navigation";
import { AsyncSection, PageHeader } from "@/components/page";
import { StatusPill } from "@/components/status/StatusPill";
import { PR_STATE_TONE, toneOf } from "@/components/status/tones";
import { Button } from "@/components/ui/button";
import { InnerStackRows, StackStateChip } from "@/components/stacks";
import { OutcomeChip } from "@/components/wm";
import { runListOutcome, runKindLabel } from "@/lib/wm/decode";
import { orchestrationUnavailable } from "@/lib/mql/providers";
import { withFailCounts } from "@/lib/wm/failCounts";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import { prSigil, type VcsProvider } from "@/lib/vcs/links";
import {
  DIRSPACE_FACTS_CAP,
  STACKS_PR_CAP,
  STACK_RUNS_CAP,
  buildStateMap,
  dirspaceStatesQuery,
  filterRunsToStack,
  lastKnownStacksQuery,
  mapDirspaceFactRow,
  mapPrStacksRow,
  mapStackRunRow,
  stackLeafDirspaces,
  stackRunsQuery,
  stackVersions,
  stackStateOf,
  stacksQuery,
  type StackOuter,
  type StackRunRow,
  type StackState,
} from "../mqlQueries";

const enc = encodeURIComponent;

interface PrRef {
  pullNumber: string;
  title: string;
  state: StackState;
}

/** Where the rendered shape came from: an open PR, or the last-known fallback
 *  (newest PR in any state whose stored stacks carry this stack). */
interface ShapeSource {
  kind: "open" | "last-known";
  pullNumber: string;
  prState?: string;
}

/**
 * The full-stack view (#1737 item 5): one stack, on its own page, independent
 * of any single pull request — current rolled-up state, the stack's shape
 * (inner stacks and dirspaces), every open PR that carries the stack, and the
 * plan/apply history of the stack's dirspaces. The shape prefers the newest
 * open PR's frozen config and falls back to the newest PR in ANY state, so the
 * lens survives PR-less periods (#1769). Deep-linkable:
 * /stacks/detail?provider=&owner=&repo=&stack=.
 */
function StackDetailContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const provider: VcsProvider = searchParams.get("provider") === "gitlab" ? "gitlab" : "github";
  const owner = searchParams.get("owner") ?? "";
  const repo = searchParams.get("repo") ?? "";
  const stackName = searchParams.get("stack") ?? "";

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [shape, setShape] = useState<StackOuter | null>(null);
  const [shapeSource, setShapeSource] = useState<ShapeSource | null>(null);
  const [prs, setPrs] = useState<PrRef[]>([]);
  const [runs, setRuns] = useState<StackRunRow[]>([]);
  // Each query's cap, surfaced like the Stacks tab's banners: a capped result
  // drops pull requests, leaves dirspaces unstated, or hides older runs.
  const [cappedPrs, setCappedPrs] = useState(false);
  const [cappedFacts, setCappedFacts] = useState(false);
  const [cappedRuns, setCappedRuns] = useState(false);

  const load = useCallback(async () => {
    if (!owner || !repo || !stackName) return;
    setLoading(true);
    setError(null);
    try {
      const [stacksRes, factsRes] = await Promise.all([
        executeMQL(stacksQuery(provider, { owner, repoName: repo })),
        executeMQL(dirspaceStatesQuery(provider, { owner, repoName: repo })),
      ]);
      const states = buildStateMap(
        factsRes.data.map((raw) => mapDirspaceFactRow(provider, raw)),
      );
      // Every open PR in this repo whose stored stacks include this one.
      const versions = stackVersions(
        stacksRes.data.map((raw) => mapPrStacksRow(provider, raw)),
        states,
        stackName,
      );
      let newest = versions[0]?.outer ?? null;
      let source: ShapeSource | null = newest
        ? { kind: "open", pullNumber: versions[0].pullNumber }
        : null;
      if (!newest) {
        // No open PR carries the stack: fall back to the newest PR in any
        // state whose stored stacks name it — the last-known shape. Its states
        // are not loaded (the live overlay covers open PRs only), so it gets
        // an empty state map and renders without state chips.
        const lastRes = await executeMQL(
          lastKnownStacksQuery(provider, { owner, repoName: repo }, stackName),
        );
        const last = stackVersions(
          lastRes.data.map((raw) => mapPrStacksRow(provider, raw)),
          new Map(),
          stackName,
        )[0];
        if (last) {
          newest = last.outer;
          source = { kind: "last-known", pullNumber: last.pullNumber, prState: last.prState };
        }
      }
      // History is asked for the stack's own directories only, so the row cap
      // is not spent on runs over the rest of the repository.
      const dirs = newest
        ? [...new Set(newest.stacks.flatMap((i) => i.dirspaces.map((d) => d.dir)))]
        : [];
      const runsRes =
        dirs.length > 0 ? await executeMQL(stackRunsQuery(provider, owner, repo, dirs)) : null;
      const runRows = runsRes ? await withFailCounts(runsRes.data) : [];
      setShape(newest);
      setShapeSource(source);
      setCappedPrs(stacksRes.data.length >= STACKS_PR_CAP);
      // The facts only feed an open pull request's shape; a last-known shape
      // shows no states, so their cap says nothing about it.
      setCappedFacts(source?.kind === "open" && factsRes.data.length >= DIRSPACE_FACTS_CAP);
      setCappedRuns((runsRes?.data.length ?? 0) >= STACK_RUNS_CAP);
      setPrs(versions.map((v) => ({ pullNumber: v.pullNumber, title: v.title, state: v.outer.state })));
      setRuns(
        newest && runsRes
          ? filterRunsToStack(runRows.map(mapStackRunRow), stackLeafDirspaces(newest))
          : [],
      );
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load stack");
    } finally {
      setLoading(false);
    }
  }, [provider, owner, repo, stackName]);

  useInitialLoad(load);

  if (!owner || !repo || !stackName) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        Missing stack reference.{" "}
        <button
          {...router.nav("/stacks")}
          className="text-[var(--sg-accent)] hover:underline"
        >
          Back to stacks
        </button>
      </div>
    );
  }
  if (unavailable) return <OrchestrationUnavailable />;

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-2 px-4 sm:px-6 pt-4">
        <button
          {...router.nav("/stacks")}
          aria-label="Back to stacks"
          className="p-1 rounded text-[var(--sg-text-muted)] hover:bg-[var(--sg-bg-2)] hover:text-[var(--sg-text)]"
        >
          <ArrowLeft className="w-4 h-4" />
        </button>
        <Breadcrumbs
          items={[
            { label: "Stacks", href: "/stacks" },
            { label: stackName },
          ]}
        />
      </div>
      <PageHeader title={stackName} subtitle={`${owner}/${repo}`}>
        <div className="flex items-center gap-3">
          {prs.length > 0 ? <StackStateChip state={stackStateOf(prs.map((p) => p.state))} /> : null}
          <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
            <RefreshCw className={`w-4 h-4 mr-2 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>
      </PageHeader>

      <div className="flex-1 overflow-auto px-4 sm:px-6 py-4">
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
          loading={loading && shape === null}
          error={error}
          empty={shape === null}
          emptyState={
            <div className="py-8 text-sm text-[var(--sg-text-muted)]">
              No pull request of {owner}/{repo} has stored stacks that include this stack.
            </div>
          }
          onRetry={() => void load()}
        >
          {shape && (
            <div className="space-y-4">
              {/* Shape: inner stacks + dirspaces, live states when an open PR backs them */}
              <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                <div className="px-4 py-2.5 border-b border-[var(--sg-border)] text-sm font-medium text-[var(--sg-text)]">
                  {shapeSource?.kind === "last-known" ? "Last known shape" : "Current shape"}
                  <span className="ml-2 inline-flex items-center gap-1.5 text-xs font-normal text-[var(--sg-text-muted)]">
                    {shapeSource?.kind === "last-known" ? (
                      <>
                        from
                        <DeepLink
                          href={`/pull-requests/detail?provider=${provider}&owner=${enc(owner)}&repo=${enc(repo)}&pr=${enc(shapeSource.pullNumber)}`}
                          className="text-[var(--sg-accent)] hover:underline"
                        >
                          {prSigil(provider)}
                          {shapeSource.pullNumber}
                        </DeepLink>
                        {shapeSource.prState ? (
                          <StatusPill
                            tone={toneOf(PR_STATE_TONE, shapeSource.prState)}
                            label={shapeSource.prState}
                            ariaPrefix="Pull request state"
                          />
                        ) : null}
                      </>
                    ) : (
                      "from the newest open pull request"
                    )}
                  </span>
                </div>
                <InnerStackRows outer={shape} showStates={shapeSource?.kind !== "last-known"} />
              </div>

              {/* Open PRs carrying this stack */}
              <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                <div className="px-4 py-2.5 border-b border-[var(--sg-border)] text-sm font-medium text-[var(--sg-text)]">
                  Open pull requests
                </div>
                {prs.length === 0 ? (
                  <div className="px-4 py-6 text-sm text-[var(--sg-text-muted)]">
                    No open pull requests carry this stack.
                  </div>
                ) : (
                  <div className="divide-y divide-[var(--sg-border)]">
                    {prs.map((pr) => (
                      <button
                        key={pr.pullNumber}
                        {...router.nav(`/pull-requests/detail?provider=${provider}&owner=${enc(owner)}&repo=${enc(repo)}&pr=${enc(pr.pullNumber)}`)}
                        className="w-full flex items-center gap-3 px-4 py-2 text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                      >
                        <GitPullRequest className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
                        <span className="text-xs text-[var(--sg-text-dim)]">
                          {prSigil(provider)}
                          {pr.pullNumber}
                        </span>
                        <span className="truncate text-sm text-[var(--sg-text)]">{pr.title}</span>
                        <span className="ml-auto">
                          <StackStateChip state={pr.state} />
                        </span>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Plan/apply history over the stack's dirspaces */}
              <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                <div className="px-4 py-2.5 border-b border-[var(--sg-border)] text-sm font-medium text-[var(--sg-text)]">
                  Plan / apply history
                  <span className="ml-2 text-xs font-normal text-[var(--sg-text-muted)]">
                    runs that touched this stack&apos;s dirspaces
                  </span>
                </div>
                {cappedRuns && (
                  <div className="m-3 p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
                    Showing runs from the newest {STACK_RUNS_CAP} run rows — older runs are not listed.
                  </div>
                )}
                {runs.length === 0 ? (
                  <div className="px-4 py-6 text-sm text-[var(--sg-text-muted)]">No runs yet.</div>
                ) : (
                  <div className="divide-y divide-[var(--sg-border)]">
                    {runs.map((r) => (
                      <button
                        key={r.id}
                        {...router.nav(`/runs/wm?id=${r.id}`)}
                        className="w-full flex items-center gap-3 px-4 py-2 text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                      >
                        <OutcomeChip outcome={runListOutcome(r.state, r.failCount)} rawState={r.state} />
                        <span className="text-xs text-[var(--sg-text-muted)]">
                          {r.runType}
                          {r.runKind ? (
                            <span className="text-[var(--sg-text-dim)]"> · {runKindLabel(r.runKind)}</span>
                          ) : null}
                        </span>
                        {r.pullNumber ? (
                          <span className="text-xs text-[var(--sg-text-dim)]">
                            {prSigil(provider)}
                            {r.pullNumber}
                          </span>
                        ) : null}
                        {r.username ? (
                          <span className="text-xs text-[var(--sg-text-muted)]">{r.username}</span>
                        ) : null}
                        <span
                          className="ml-auto text-xs text-[var(--sg-text-muted)]"
                          title={formatAbsoluteTime(r.createdAt)}
                        >
                          {formatRelativeTime(r.createdAt)}
                        </span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </AsyncSection>
      </div>
    </div>
  );
}

export default function StackDetailPage() {
  return (
    <Suspense
      fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}
    >
      <AuthGuard>
        <StackDetailContent />
      </AuthGuard>
    </Suspense>
  );
}

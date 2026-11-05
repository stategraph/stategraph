"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowLeft, ExternalLink, GitMerge, RefreshCw } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { Breadcrumbs } from "@/components/list/Breadcrumbs";
import { OutcomeChip, WmGatePanel, type ApprovalRow, type GateRow } from "@/components/wm";
import { PrStacksPanel } from "@/components/stacks";
import { prSigil, providerName, pullRequestUrl, type VcsProvider } from "@/lib/vcs/links";
import { VCS_PROVIDERS, asNumber, asText, orchestrationUnavailable } from "@/lib/mql/providers";
import { sqlLiteral } from "@/lib/mql/escape";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import { PR_STATE_TONE, TONE_CLASS, toneOf } from "@/components/status/tones";
import { runListOutcome } from "@/lib/wm/decode";
import { withFailCounts } from "@/lib/wm/failCounts";


interface Meta { title: string; branch: string; baseBranch: string; state: string; username: string; mergedAt: string; }
interface RunRow { id: string; state: string; failCount: number; runType: string; runKind: string; createdAt: string; }
/** A repository that has a pull request with the number a comment link named. */
interface Candidate { provider: VcsProvider; owner: string; name: string; }

// Pull numbers are per repository, so an installation can hold several
// repositories with the same number; this bounds the chooser, not the lookup.
const RESOLVE_CAP = 50;

function canonicalPrUrl(c: Candidate, pr: string): string {
  return `/pull-requests/detail?provider=${c.provider}&owner=${encodeURIComponent(c.owner)}&repo=${encodeURIComponent(c.name)}&pr=${encodeURIComponent(pr)}`;
}

function PullRequestDetailContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const rawProvider = searchParams.get("provider") ?? "";
  const provider: VcsProvider = rawProvider === "gitlab" ? "gitlab" : "github";
  const owner = searchParams.get("owner") ?? "";
  const repo = searchParams.get("repo") ?? "";
  // ?pr= is canonical; ?mr= accepted for symmetry with older GitLab-shaped links.
  const mr = searchParams.get("pr") ?? searchParams.get("mr") ?? "";

  const [meta, setMeta] = useState<Meta | null>(null);
  const [runs, setRuns] = useState<RunRow[]>([]);
  const [gates, setGates] = useState<GateRow[]>([]);
  const [approvals, setApprovals] = useState<ApprovalRow[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  // Set only when a comment link is ambiguous (several repositories match).
  const [candidates, setCandidates] = useState<Candidate[] | null>(null);
  // The repository the pull request belongs to; gates the stacks panel.
  const [repoId, setRepoId] = useState(0);

  // iris-compat: the nginx front door rewrites /i/{installation}/runs/pr/{repo}/{n}
  // and /i/{installation}/runs/pr/{n} comment links to ?installation=&repo=&pr=
  // and ?installation=&pr= — no owner, no provider. Resolve them here
  // (per-provider lookup; the tenant-scoped MQL surface is the security
  // boundary) and replace the URL with the canonical shape. Pull numbers are
  // per repository, so without a repository every repository of the
  // installation that has this number is a candidate: one match redirects,
  // several offer a chooser rather than silently picking one.
  const installation = searchParams.get("installation") ?? "";
  const needsResolve = !owner && !!installation && !!mr;
  const missing = (!owner || !repo || !mr) && !needsResolve;

  useEffect(() => {
    if (!needsResolve) return;
    let cancelled = false;
    const t = window.setTimeout(() => {
      void (async () => {
        const inst = asNumber(installation);
        const num = asNumber(mr);
        if (!Number.isInteger(inst) || !Number.isInteger(num)) {
          setError("Malformed pull request link.");
          return;
        }
        const byRepo = repo ? ` and r.name = ${sqlLiteral(repo)}` : "";
        const settled = await Promise.allSettled(
          VCS_PROVIDERS.map(async (p): Promise<Candidate[]> => {
            const res = await executeMQL(
              `select r.owner as owner, r.name as name from ${p}_pull_requests as pr inner join ${p}_installation_repositories as r on r.id = pr.repository where r.installation_id = ${inst} and pr.pull_number = ${num}${byRepo} order by r.owner, r.name limit ${RESOLVE_CAP}`,
            );
            return res.data.map((row) => {
              const x = row as Record<string, unknown>;
              return { provider: p, owner: asText(x.owner), name: asText(x.name) };
            });
          }),
        );
        if (cancelled) return;
        const found = settled.flatMap((r) => (r.status === "fulfilled" ? r.value : []));
        if (found.length === 1) {
          router.replace(canonicalPrUrl(found[0], mr));
        } else if (found.length > 1) {
          setCandidates(found);
        } else if (settled.every((r) => r.status === "rejected") && orchestrationUnavailable(settled[0].reason)) {
          setUnavailable(true);
        } else {
          // Also the outcome when the installation belongs to another tenant:
          // MQL only sees the current tenant's tables.
          setError("No pull request found for this link in the current tenant.");
        }
      })();
    }, 0);
    return () => {
      cancelled = true;
      window.clearTimeout(t);
    };
  }, [needsResolve, installation, repo, mr, router]);

  const load = useCallback(async () => {
    if (missing || needsResolve) return;
    try {
      const o = sqlLiteral(owner), r = sqlLiteral(repo), num = asNumber(mr);
      // The number is interpolated unquoted; a malformed ?pr= is an error, not a "0" lookup.
      if (!Number.isInteger(num) || num <= 0) {
        setError(`Invalid pull request number "${mr}".`);
        return;
      }
      const [metaRes, runsRes] = await Promise.all([
        executeMQL(`select gpr.title as title, gpr.branch as branch, gpr.base_branch as base_branch, gpr.state as state, gpr.username as username, gpr.merged_at as merged_at, gir.id as repo_id from ${provider}_pull_requests as gpr inner join ${provider}_installation_repositories as gir on gir.id = gpr.repository where gir.owner = ${o} and gir.name = ${r} and gpr.pull_number = ${num} limit 1`),
        executeMQL(`select wm.id as id, wm.state as state, wm.run_type as run_type, wm.run_kind as run_kind, wm.created_at as created_at from ${provider}_work_manifests as wm where wm.repo_owner = ${o} and wm.repo_name = ${r} and wm.pull_number = ${num} order by wm.created_at desc limit 100`).then((res) => withFailCounts(res.data)),
      ]);
      const m0 = metaRes.data[0] as Record<string, unknown> | undefined;
      setMeta(m0 ? {
        title: asText(m0.title), branch: asText(m0.branch), baseBranch: asText(m0.base_branch),
        state: asText(m0.state), username: asText(m0.username), mergedAt: asText(m0.merged_at),
      } : null);
      setRuns(runsRes.map((x) => {
        const w = x as Record<string, unknown>;
        return { id: asText(w.id), state: asText(w.state), failCount: asNumber(w.fail_count), runType: asText(w.run_type), runKind: asText(w.run_kind), createdAt: asText(w.created_at) };
      }));

      const repoId = asNumber(m0?.repo_id);
      setRepoId(repoId);
      if (repoId) {
        const [gr, ar] = await Promise.all([
          executeMQL(`select g.name as name, g.dir as dir, g.workspace as workspace, g.token as token, g.gate as gate from gates as g inner join ${provider}_pull_requests_map as pm on pm.core_id = g.pull_request where pm.repository_id = ${repoId} and pm.pull_number = ${num} limit 50`).catch(() => ({ data: [] as unknown[] })),
          executeMQL(`select ga.approver as approver, ga.token as token, ga.created_at as created_at from gate_approvals as ga inner join gates as g on g.token = ga.token inner join ${provider}_pull_requests_map as pm on pm.core_id = g.pull_request where pm.repository_id = ${repoId} and pm.pull_number = ${num} limit 100`).catch(() => ({ data: [] as unknown[] })),
        ]);
        setGates(gr.data.map((x) => {
          const w = x as Record<string, unknown>;
          return { name: asText(w.name), dir: asText(w.dir), workspace: asText(w.workspace), token: asText(w.token), gate: (w.gate ?? null) as Record<string, unknown> | null };
        }));
        setApprovals(ar.data.map((x) => {
          const w = x as Record<string, unknown>;
          return { approver: asText(w.approver), token: asText(w.token), created_at: asText(w.created_at) };
        }));
      } else {
        setGates([]);
        setApprovals([]);
      }
      setLoaded(true);
      setError(null);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load pull request");
    }
  }, [missing, needsResolve, provider, owner, repo, mr]);
  useInitialLoad(load);

  if (unavailable) return <OrchestrationUnavailable />;
  const shownError = error ?? (missing ? "Missing pull request parameters." : null);
  const mrUrl = pullRequestUrl(provider, owner, repo, mr);
  const sigil = prSigil(provider);

  return (
    <div className="flex flex-col h-full">
      <header className="px-6 pt-6 pb-3 border-b border-[var(--sg-border)]">
        <Breadcrumbs items={[{ label: "Pull Requests", href: "/pull-requests" }, { label: owner && repo ? `${owner}/${repo} ${sigil}${mr}` : `${sigil}${mr}` }]} />
        <div className="flex items-center gap-3 mt-2">
          <button {...router.nav("/pull-requests")} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Back to pull requests">
            <ArrowLeft className="w-4 h-4 text-[var(--sg-text-muted)]" />
          </button>
          <h1 className="text-lg font-semibold text-[var(--sg-text)] truncate">
            {sigil}{mr} {meta?.title}
          </h1>
          <button onClick={() => void load()} className="ml-auto p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
            <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-5">
        {shownError ? (
          <div className="p-3 rounded-lg bg-[var(--sg-error-bg)] border border-[var(--sg-error)]/30 text-sm text-[var(--sg-error)]">{shownError}</div>
        ) : candidates ? (
          <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4">
            <div className="text-sm text-[var(--sg-text)] mb-3">
              Several repositories in this installation have a pull request numbered {mr}. Pick one:
            </div>
            <div className="rounded-md border border-[var(--sg-border)] overflow-hidden divide-y divide-[var(--sg-border)]">
              {candidates.map((c) => (
                <button
                  key={`${c.provider}/${c.owner}/${c.name}`}
                  onClick={() => router.replace(canonicalPrUrl(c, mr))}
                  className="w-full flex items-center gap-3 px-4 py-2 text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                >
                  <span className="font-mono text-sm text-[var(--sg-text)]">{c.owner}/{c.name}</span>
                  <span className="text-xs text-[var(--sg-text-muted)]">{prSigil(c.provider)}{mr} · {c.provider}</span>
                </button>
              ))}
            </div>
          </div>
        ) : !loaded ? (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>
        ) : meta === null ? (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">Pull request not found.</div>
        ) : (
          <>
            <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4">
              <div className="flex items-center gap-2 flex-wrap text-sm">
                <span className="font-mono text-[var(--sg-text)]">{owner}/{repo}</span>
                <span
                  className={`inline-flex items-center rounded-md border px-2 py-0.5 text-xs ${TONE_CLASS[toneOf(PR_STATE_TONE, meta.state)]}`}
                >
                  {meta.state}
                </span>
                {mrUrl && (
                  <a href={mrUrl} target="_blank" rel="noopener noreferrer" className="ml-auto inline-flex items-center gap-1 text-xs text-[var(--sg-accent)] hover:underline">
                    View on {providerName(provider)} <ExternalLink className="w-3 h-3" />
                  </a>
                )}
              </div>
              <div className="mt-2 text-xs text-[var(--sg-text-muted)] flex flex-wrap gap-x-4 gap-y-1">
                <span className="font-mono inline-flex items-center gap-1"><GitMerge className="w-3 h-3" /> {meta.branch} → {meta.baseBranch}</span>
                {meta.username && <span>by {meta.username}</span>}
                {meta.mergedAt && <span title={formatAbsoluteTime(meta.mergedAt)}>merged {formatRelativeTime(meta.mergedAt)}</span>}
              </div>
            </div>

            {gates.length > 0 && <WmGatePanel gates={gates} approvals={approvals} />}

            {repoId > 0 && <PrStacksPanel provider={provider} repoId={repoId} pullNumber={asNumber(mr)} />}

            <div>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2">Runs on this pull request</div>
              {runs.length === 0 ? (
                <div className="p-6 text-sm text-[var(--sg-text-muted)]">No runs recorded for this pull request.</div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden divide-y divide-[var(--sg-border)]">
                  {runs.map((r) => (
                    <button
                      key={r.id}
                      {...router.nav(`/runs/wm?id=${r.id}`)}
                      className="w-full flex items-center gap-3 px-4 py-2 text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                    >
                      <OutcomeChip outcome={runListOutcome(r.state, r.failCount)} rawState={r.state} />
                      <span className="text-xs text-[var(--sg-text-muted)]">{r.runType}<span className="text-[var(--sg-text-dim)]"> · {r.runKind}</span></span>
                      <span className="ml-auto text-xs text-[var(--sg-text-muted)]">{formatRelativeTime(r.createdAt)}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default function PullRequestDetailPage() {
  return (
    <Suspense fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}>
      <PullRequestDetailContent />
    </Suspense>
  );
}

"use client";

import { useCallback, useMemo, useRef, useState } from "react";
import {
  CalendarClock,
  Download,
  GitCompare,
  RefreshCw,
  ShieldCheck,
  Siren,
} from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks";
import { VCS_PROVIDERS, asNumber, asText, executeWithRetry, orchestrationUnavailable, runAcrossProviders } from "@/lib/mql/providers";
import { OrchestrationEmptyState, OrchestrationUnavailable } from "@/components/orchestration";
import type { VcsProvider } from "@/lib/vcs/links";
import { ListToolbar, WorkflowEnvHeader } from "@/components/list";
import { AsyncSection, PageHeader, StatCard } from "@/components/page";
import { InfoTip } from "@/components/ui/info-tip";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { usePagination } from "@/hooks/usePagination";
import { PaginationControls } from "@/components/instances/PaginationControls";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { downloadFile, timestampedFilename, toCsv } from "@/lib/export";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import { countsFor, type Counts, type Json } from "@/lib/wm/decode";
import { computeDriftStates, driftRunKind, humanizeCron, type DriftRow, type DriftRunKind } from "@/lib/drift/state";
import { groupRepoOptions, matchesOwner, ownerFacetOptions, parseOwnerKey } from "@/lib/vcs/ownerFacet";
import { matchesSearch } from "@/lib/ui/search";
import {
  DRIFT_CAP,
  SCHEDULES_CAP,
  driftMetricQuery,
  driftPlanPayloadsQuery,
  driftScheduleCountQuery,
  driftSchedulesQuery,
  driftStepQuery,
  mapDriftRow,
  type ScheduleRow,
} from "./mqlQueries";

const enc = encodeURIComponent;
const PAGE_SIZE = 50;
/** Attention rows that get +/~/- counts: each costs a plan payload in the
 *  one follow-up query, so only the head of the list is decorated. */
const ATTENTION_COUNTS = 12;

const EXPORT_COLUMNS = ["checked_at", "repository", "directory", "workspace", "environment", "event", "result", "run_id"] as const;

/** Run-types filter labels, in the vocabulary of the export's `event` column. */
const RUN_KIND_LABEL: Record<Exclude<DriftRunKind, "other">, string> = {
  plan: "drift check",
  apply: "reconcile",
};

interface Metrics {
  checks30d: number;
  finds30d: number;
  reconciles30d: number;
  /** schedule counts by mode for the selected owner (a count query, not the listed rows) */
  schedulesAuto: number;
  schedulesAlert: number;
}

function ModeBadge({ reconcile }: { reconcile: boolean }) {
  return reconcile ? (
    <span title="This schedule applies the committed state automatically when drift is found (reconcile: true)" className="inline-flex items-center gap-1 rounded-md border border-[var(--sg-accent)]/30 px-2 py-0.5 text-xs text-[var(--sg-accent)]">
      <ShieldCheck className="h-3 w-3" /> Auto-reconcile
    </span>
  ) : (
    <span title="This schedule only reports drift; nothing is applied automatically (reconcile: false)" className="inline-flex items-center gap-1 rounded-md border border-[var(--sg-warning)]/30 px-2 py-0.5 text-xs text-[var(--sg-warning)]">
      <Siren className="h-3 w-3" /> Alert only
    </span>
  );
}

function StatusChip({ status }: { status: "drifted" | "reconciled" | "clean" | "reconcile-run" | "failed" }) {
  const cls =
    status === "drifted"
      ? "bg-[var(--sg-warning-bg)] text-[var(--sg-warning)] border-[var(--sg-warning)]"
      : status === "failed"
        ? "bg-[var(--sg-error-bg)] text-[var(--sg-error)] border-[var(--sg-error)]"
        : status === "reconciled" || status === "reconcile-run"
          ? "bg-[var(--sg-accent-bg)] text-[var(--sg-accent)] border-[var(--sg-accent)]"
          : "bg-[var(--sg-success-bg)] text-[var(--sg-success)] border-[var(--sg-success)]";
  const label =
    status === "drifted"
      ? "Drifted"
      : status === "failed"
        ? "Failed"
        : status === "reconciled"
          ? "Reconciled"
          : status === "reconcile-run"
            ? "Reconcile"
            : "Clean";
  return (
    <span className={`inline-block px-2 py-0.5 text-[10px] uppercase tracking-wide font-medium rounded border ${cls}`}>
      {label}
    </span>
  );
}

function CountsInline({ c }: { c: Counts | undefined }) {
  if (!c) return null;
  return (
    <span className="font-mono text-xs">
      <span className="text-[var(--sg-op-create)]">+{c.add}</span>{" "}
      <span className="text-[var(--sg-op-update)]">~{c.change}</span>{" "}
      <span className="text-[var(--sg-op-destroy)]">-{c.destroy}</span>
    </span>
  );
}

export function DriftContent() {
  const router = useDeepLinkRouter();
  // The cards' lists are on this page: a card scrolls to the section it counts.
  const attentionRef = useRef<HTMLDivElement>(null);
  const schedulesRef = useRef<HTMLDivElement>(null);
  const scrollTo = (ref: React.RefObject<HTMLDivElement | null>) =>
    ref.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  const [rows, setRows] = useState<DriftRow[] | null>(null);
  const [schedules, setSchedules] = useState<ScheduleRow[]>([]);
  const [metrics, setMetrics] = useState<Metrics | null>(null);
  const [counts, setCounts] = useState<Map<string, Counts>>(new Map());
  const [failed, setFailed] = useState<VcsProvider[]>([]);
  const [metricsFailed, setMetricsFailed] = useState<VcsProvider[]>([]);
  const [capped, setCapped] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [query, setQuery] = useUrlSyncedParam("q", "");
  const [ownerFilter, setOwnerFilter] = useUrlSyncedParam("owner", "");
  const [repoFilter, setRepoFilter] = useUrlSyncedParam("repo", "");
  const [envFilter, setEnvFilter] = useUrlSyncedParam("env", "");
  const [runTypeFilter, setRunTypeFilter] = useUrlSyncedParam("rtype", "");

  const load = useCallback(async () => {
    try {
      // Every provider failing is either orchestration being off or a real
      // error, which must never render as a green "nothing drifted" all-clear.
      const { results, failed: failedProviders } = await runAcrossProviders(async (p) => {
        const [checks, applies, sched] = await Promise.all([
          executeWithRetry(driftStepQuery(p, "plan")),
          executeWithRetry(driftStepQuery(p, "apply")),
          executeWithRetry(driftSchedulesQuery(p)),
        ]);
        return { checks, applies, sched };
      });

      const all: DriftRow[] = [];
      const scheds: ScheduleRow[] = [];
      for (const { provider, value: r } of results) {
        for (const x of r.checks) all.push(mapDriftRow(provider, x));
        for (const x of r.applies) all.push(mapDriftRow(provider, x));
        for (const x of r.sched) {
          const o = x as Record<string, unknown>;
          scheds.push({
            name: asText(o.name),
            cron: asText(o.schedule),
            reconcile: o.reconcile === true,
            tagQuery: asText(o.tag_query),
            lastTried: asText(o.last_tried_at),
            provider,
            owner: asText(o.owner),
            repoName: asText(o.repo_name),
          });
        }
      }
      setRows(all);
      // Counts are keyed by dirspace, so a stale map would decorate freshly
      // loaded rows with the previous load's numbers until the follow-up
      // query lands; clear it with the rows.
      setCounts(new Map());
      setSchedules(scheds);
      setFailed(failedProviders);
      setCapped(
        results.some(
          ({ value: r }) =>
            r.checks.length >= DRIFT_CAP || r.applies.length >= DRIFT_CAP || r.sched.length >= SCHEDULES_CAP,
        ),
      );
      setError(null);

      // Resource-level summaries for the dirspaces needing attention: the
      // latest check's plan payload per dirspace, one query for the whole
      // head of the list. Heavy payloads are only pulled here, never in the
      // lists, and they are decoration — the list stands without them.
      const attention = computeDriftStates(all)
        .filter((d) => d.status !== "clean")
        .slice(0, ATTENTION_COUNTS);
      const byKey = new Map<string, Counts>();
      if (attention.length > 0) {
        const keyOf = new Map(attention.map((d) => [`${d.checkRunId}|${d.dir}|${d.workspace}`, d.key]));
        const payloads = await executeMQL(driftPlanPayloadsQuery(attention)).catch(() => ({ data: [] as unknown[] }));
        for (const raw of payloads.data) {
          const o = raw as Record<string, unknown>;
          const key = keyOf.get(`${asText(o.work_manifest)}|${asText(o.dir)}|${asText(o.workspace)}`);
          const c = countsFor((o.payload ?? null) as Json | null);
          if (key !== undefined && c && !byKey.has(key)) byKey.set(key, c);
        }
      }
      setCounts(byKey);
    } catch (e) {
      if (orchestrationUnavailable(e)) setUnavailable(true);
      else setError(e instanceof Error ? e.message : "Failed to load drift");
    }
  }, []);

  useInitialLoad(load);

  // The 30-day and schedule counts are computed server-side, so the owner
  // facet has to reach their queries. They load apart from the lists: an owner
  // change rescopes these counts without refetching every step row, and only
  // the newest request's answer lands.
  const metricsRequest = useRef(0);
  const loadMetrics = useCallback(async () => {
    const mine = ++metricsRequest.current;
    // The since bound is computed once by the caller of executeMQL, not inside
    // MQL, so it is interpolated as a literal — a fixed ISO string, no user input.
    const since = new Date(Date.now() - 30 * 864e5).toISOString();
    // A selected owner leaves the other provider out of the counts. A value
    // naming no known provider matches no listed row, so it counts nothing
    // rather than falling back to tenant-wide numbers.
    const selected = parseOwnerKey(ownerFilter);
    const selOwner = selected?.owner;
    const providers = ownerFilter === "" ? VCS_PROVIDERS : selected ? [selected.provider] : [];
    if (providers.length === 0) {
      setMetrics({ checks30d: 0, finds30d: 0, reconciles30d: 0, schedulesAuto: 0, schedulesAlert: 0 });
      setMetricsFailed([]);
      return;
    }
    try {
      const { results, failed: failedProviders } = await runAcrossProviders(async (p) => {
        const [schedCounts, checks, finds, reconciles] = await Promise.all([
          executeWithRetry(driftScheduleCountQuery(p, selOwner)),
          executeWithRetry(driftMetricQuery(p, "checks", since, selOwner)),
          executeWithRetry(driftMetricQuery(p, "finds", since, selOwner)),
          executeWithRetry(driftMetricQuery(p, "reconciles", since, selOwner)),
        ]);
        return { schedCounts, checks, finds, reconciles };
      }, providers);
      if (mine !== metricsRequest.current) return;
      const c1 = (data: unknown[]) => asNumber((data[0] as Record<string, unknown> | undefined)?.c);
      const m: Metrics = { checks30d: 0, finds30d: 0, reconciles30d: 0, schedulesAuto: 0, schedulesAlert: 0 };
      for (const { value: r } of results) {
        for (const x of r.schedCounts) {
          const o = x as Record<string, unknown>;
          if (o.reconcile === true) m.schedulesAuto += asNumber(o.c);
          else m.schedulesAlert += asNumber(o.c);
        }
        m.checks30d += c1(r.checks);
        m.finds30d += c1(r.finds);
        m.reconciles30d += c1(r.reconciles);
      }
      setMetrics(m);
      setMetricsFailed(failedProviders);
    } catch (e) {
      if (mine !== metricsRequest.current) return;
      // The lists' load reports orchestration being off or down; the cards
      // just stay empty rather than keep a previous owner's numbers.
      if (!orchestrationUnavailable(e)) console.warn("Drift counts failed to load", e);
      setMetrics(null);
      setMetricsFailed(providers);
    }
  }, [ownerFilter]);

  // Re-runs whenever the owner changes loadMetrics' identity.
  useInitialLoad(loadMetrics);

  const refresh = () => {
    void load();
    void loadMetrics();
  };

  const modeByRepo = useMemo(() => {
    const m = new Map<string, boolean>();
    for (const sc of schedules) m.set(`${sc.owner}/${sc.repoName}`, sc.reconcile);
    return m;
  }, [schedules]);

  const owners = useMemo(
    () => ownerFacetOptions((rows ?? []).map((r) => ({ provider: r.provider, owner: r.repoOwner }))),
    [rows],
  );
  const repos = useMemo(() => [...new Set((rows ?? []).map((r) => `${r.repoOwner}/${r.repoName}`))].sort(), [rows]);
  const repoGroups = useMemo(
    () =>
      groupRepoOptions((rows ?? []).map((r) => ({ provider: r.provider, owner: r.repoOwner, name: r.repoName }))),
    [rows],
  );
  const filteredSchedules = useMemo(
    () => schedules.filter((sc) => matchesOwner(ownerFilter, sc.provider, sc.owner)),
    [schedules, ownerFilter],
  );
  const envs = useMemo(() => [...new Set((rows ?? []).map((r) => r.environment).filter(Boolean))].sort(), [rows]);
  // Classified once: the Result cell, the export and the Run-types filter all
  // read `kind`, never run_type itself (legacy aliases, see driftRunKind).
  const classified = useMemo(
    () =>
      (rows ?? [])
        .map((r) => ({ ...r, kind: driftRunKind(r.runType) }))
        .filter((r): r is DriftRow & { kind: Exclude<DriftRunKind, "other"> } => r.kind !== "other"),
    [rows],
  );
  const runKinds = useMemo(() => [...new Set(classified.map((r) => r.kind))].sort(), [classified]);
  const hasEnv = useMemo(() => (rows ?? []).some((r) => r.environment && r.environment !== "—"), [rows]);

  const matches = useCallback(
    (provider: VcsProvider, repoOwner: string, repoName: string, environment: string, dir: string) => {
      const repo = `${repoOwner}/${repoName}`;
      if (!matchesOwner(ownerFilter, provider, repoOwner)) return false;
      if (repoFilter && repo !== repoFilter) return false;
      if (envFilter && environment !== envFilter) return false;
      if (!matchesSearch(query, `${repo} ${dir}`)) return false;
      return true;
    },
    [ownerFilter, repoFilter, envFilter, query],
  );

  const states = useMemo(() => (rows ? computeDriftStates(rows) : []), [rows]);
  // The cards count what the lists beneath them show: search, owner,
  // repository and environment narrow the fold too, so "Drifted now" never
  // says seven above a one-row attention list. The 30-day cards are
  // server-side counts that follow the owner facet but not search, repository
  // or environment, and say so while one of those is active.
  const inView = useMemo(
    () => states.filter((d) => matches(d.provider, d.repoOwner, d.repoName, d.environment, d.dir)),
    [states, matches],
  );
  const attention = useMemo(() => inView.filter((d) => d.status !== "clean"), [inView]);
  const drifted = useMemo(() => attention.filter((d) => d.status === "drifted"), [attention]);
  const monitored = inView.length;
  const narrowedBelowOwner = Boolean(query.trim() || repoFilter || envFilter);
  const filtering = narrowedBelowOwner || Boolean(ownerFilter);
  const tenantWide = narrowedBelowOwner ? "all repositories" : undefined;

  const history = useMemo(
    () =>
      classified
        .filter((r) => matches(r.provider, r.repoOwner, r.repoName, r.environment, r.dir))
        .filter((r) => !runTypeFilter || r.kind === runTypeFilter)
        .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt)),
    [classified, matches, runTypeFilter],
  );
  const page = usePagination(history, PAGE_SIZE, `${query}|${ownerFilter}|${repoFilter}|${envFilter}|${runTypeFilter}`);

  const exportRows = useCallback(
    () =>
      history.map((r) => ({
        checked_at: r.createdAt,
        repository: `${r.repoOwner}/${r.repoName}`,
        directory: r.dir,
        workspace: r.workspace,
        environment: r.environment,
        event: r.kind === "apply" ? "reconcile_apply" : "drift_check",
        result: r.kind === "apply" ? (r.success ? "reconciled" : "failed") : r.hasChanges ? "drift_found" : "clean",
        run_id: r.id,
      })),
    [history],
  );
  // A drift report is exactly the artifact that gets forwarded, so a partial
  // file must say so in the file itself, not only on screen (the doctrine in
  // audit/content.tsx and lib/resource-types/export.ts). Partial means capped
  // rows OR a provider whose rows are missing entirely. The JSON carries a
  // self-describing envelope; CSV has nowhere to put one without breaking
  // parsers, so the partial state goes in the filename.
  const exportBase = capped || failed.length > 0 ? "drift-partial" : "drift";
  const exportCsv = useCallback(() => {
    const data = exportRows();
    downloadFile(
      toCsv([...EXPORT_COLUMNS], data.map((r) => EXPORT_COLUMNS.map((c) => r[c]))),
      timestampedFilename(exportBase, "csv"),
      "text/csv;charset=utf-8;",
    );
  }, [exportRows, exportBase]);
  const exportJson = useCallback(() => {
    const data = exportRows();
    downloadFile(
      JSON.stringify(
        {
          schema: "stategraph.drift.v1",
          exported_at: new Date().toISOString(),
          scope: capped ? "most-recent-per-provider" : "all",
          per_provider_cap: DRIFT_CAP,
          failed_providers: failed,
          row_count: data.length,
          rows: data,
        },
        null,
        2,
      ),
      timestampedFilename(exportBase, "json"),
      "application/json;charset=utf-8;",
    );
  }, [exportRows, exportBase, capped, failed]);

  if (unavailable) return <OrchestrationUnavailable />;
  const unloaded = [...new Set([...failed, ...metricsFailed])];

  return (
    <div className="flex flex-col h-full">
      <PageHeader
        title="Drift"
        subtitle="What has drifted, how, and the schedules that keep watch"
      >
        <div className="flex items-center gap-3">
          <button
            {...router.nav("/gap-analysis")}
            className="text-xs text-[var(--sg-accent)] hover:underline"
            title="Resources in your cloud that Terraform doesn't manage at all"
          >
            Unmanaged resources →
          </button>
          <button onClick={refresh} className="p-1 rounded hover:bg-[var(--sg-bg-2)]" aria-label="Refresh">
            <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
          </button>
        </div>
      </PageHeader>

      <div className="flex-1 overflow-y-auto px-6 py-4">
        <AsyncSection
          loading={rows === null && !error}
          error={error}
          empty={rows?.length === 0 && schedules.length === 0}
          emptyState={
            <OrchestrationEmptyState centered>
              <div className="p-8 text-center text-sm text-[var(--sg-text-muted)]">
                No drift activity yet. Checks appear here once a repository has a drift schedule.
              </div>
            </OrchestrationEmptyState>
          }
          onRetry={refresh}
        >
          <div className="space-y-5">
            {unloaded.length > 0 && (
              <div className="p-2 rounded-md border border-[var(--sg-warning)]/40 bg-[var(--sg-warning)]/10 text-xs text-[var(--sg-text-muted)]">
                Could not load {unloaded.join(", ")} drift data — showing the rest.
              </div>
            )}
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
              <StatCard
                label="Drifted now"
                value={String(drifted.length)}
                tone={drifted.length > 0 ? "text-[var(--sg-warning)]" : "text-[var(--sg-success)]"}
                sub={filtering ? "matching filters" : undefined}
                onClick={() => scrollTo(attentionRef)}
              />
              <StatCard
                label="Monitored"
                value={String(monitored)}
                sub={filtering ? "workspaces checked, matching filters" : "workspaces checked"}
              />
              <StatCard
                label="Schedules"
                value={String((metrics?.schedulesAuto ?? 0) + (metrics?.schedulesAlert ?? 0))}
                sub={`${metrics?.schedulesAuto ?? 0} auto · ${metrics?.schedulesAlert ?? 0} alert`}
                onClick={() => scrollTo(schedulesRef)}
              />
              <StatCard label="Checks (30d)" value={String(metrics?.checks30d ?? 0)} sub={tenantWide} />
              <StatCard label="Drift found (30d)" value={String(metrics?.finds30d ?? 0)} sub={tenantWide} />
              <StatCard label="Auto-reconciled (30d)" value={String(metrics?.reconciles30d ?? 0)} sub={tenantWide} />
            </div>

            <ListToolbar
              search={query}
              onSearch={setQuery}
              placeholder="Search by repository or directory…"
              filters={[
                ...(owners.length > 1 || ownerFilter ? [{ label: "Owners", value: ownerFilter, onChange: setOwnerFilter, options: owners }] : []),
                ...(repos.length > 1 || repoFilter ? [{ label: "Repositories", value: repoFilter, onChange: setRepoFilter, options: repos.map((r) => ({ label: r, value: r })), groups: repoGroups }] : []),
                ...(runKinds.length > 1 || runTypeFilter ? [{ label: "Run types", value: runTypeFilter, onChange: setRunTypeFilter, options: runKinds.map((k) => ({ label: RUN_KIND_LABEL[k], value: k })) }] : []),
                ...(hasEnv ? [{ label: "Environments", value: envFilter, onChange: setEnvFilter, options: envs.map((e) => ({ label: e, value: e })) }] : []),
              ]}
            >
              <button
                onClick={exportCsv}
                disabled={history.length === 0}
                className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-40 cursor-pointer"
              >
                <Download className="w-3 h-3" /> CSV
              </button>
              <button
                onClick={exportJson}
                disabled={history.length === 0}
                className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-40 cursor-pointer"
              >
                <Download className="w-3 h-3" /> JSON
              </button>
            </ListToolbar>

            <div ref={attentionRef}>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2 flex items-center gap-2">
                <GitCompare className="w-4 h-4 text-[var(--sg-text-muted)]" /> Needs attention
              </div>
              {attention.length === 0 ? (
                <div className="p-6 text-sm text-[var(--sg-text-muted)] rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
                  Nothing drifted — every monitored workspace matches its committed state.
                </div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden divide-y divide-[var(--sg-border)]">
                  {attention.map((d) => (
                    <button
                      key={d.key}
                      {...router.nav(`/runs/wm?id=${enc(d.checkRunId)}`)}
                      className="w-full px-4 py-3 flex items-center gap-3 flex-wrap text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                    >
                      <StatusChip status={d.status} />
                      <span className="font-mono text-sm text-[var(--sg-text)]">
                        {d.dir || "."} <span className="text-[var(--sg-text-muted)]">· {d.workspace}</span>
                      </span>
                      <span className="text-xs text-[var(--sg-text-muted)]">{d.repoOwner}/{d.repoName}</span>
                      {d.environment && <span className="text-xs text-[var(--sg-text-dim)]">{d.environment}</span>}
                      <CountsInline c={counts.get(d.key)} />
                      <ModeBadge reconcile={modeByRepo.get(`${d.repoOwner}/${d.repoName}`) ?? false} />
                      <span className="ml-auto text-xs text-[var(--sg-text-muted)]" title={formatAbsoluteTime(d.checkedAt)}>
                        {d.status === "reconciled" && d.reconciledAt
                          ? `reconciled ${formatRelativeTime(d.reconciledAt)}`
                          : `detected ${formatRelativeTime(d.checkedAt)}`}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div ref={schedulesRef}>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2 flex items-center gap-2">
                <CalendarClock className="w-4 h-4 text-[var(--sg-text-muted)]" /> Schedules
              </div>
              {filteredSchedules.length === 0 ? (
                <div className="p-6 text-sm text-[var(--sg-text-muted)] rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
                  {schedules.length === 0 ? "No drift schedules configured yet." : "No drift schedules for this owner."}
                </div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Schedule</TableHead>
                        <TableHead>Repository</TableHead>
                        <TableHead>Cadence</TableHead>
                        <TableHead>Scope</TableHead>
                        <TableHead>
                          <span className="inline-flex items-center gap-1">
                            Mode
                            <InfoTip>
                              From the repo&apos;s drift schedule config: with reconcile enabled,
                              Stategraph applies the committed state back automatically when drift
                              is found; otherwise it only reports the drift.
                            </InfoTip>
                          </span>
                        </TableHead>
                        <TableHead>Last check</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredSchedules.map((sc) => (
                        <TableRow key={`${sc.provider}|${sc.owner}/${sc.repoName}|${sc.name}`}>
                          <TableCell className="font-medium text-[var(--sg-text)]">{sc.name || "—"}</TableCell>
                          <TableCell>
                            <button
                              {...router.nav(`/repositories/detail?provider=${sc.provider}&owner=${enc(sc.owner)}&repo=${enc(sc.repoName)}`)}
                              className="font-mono text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] hover:underline"
                            >
                              {sc.owner}/{sc.repoName}
                            </button>
                          </TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]" title={sc.cron}>
                            {humanizeCron(sc.cron)}
                          </TableCell>
                          <TableCell className="font-mono text-xs text-[var(--sg-text-muted)]">{sc.tagQuery || "all dirspaces"}</TableCell>
                          <TableCell><ModeBadge reconcile={sc.reconcile} /></TableCell>
                          <TableCell className="text-[var(--sg-text-muted)]" title={sc.lastTried ? formatAbsoluteTime(sc.lastTried) : undefined}>
                            {sc.lastTried ? formatRelativeTime(sc.lastTried) : "—"}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </div>

            <div>
              <div className="text-sm font-medium text-[var(--sg-text)] mb-2">Check history</div>
              <div className="mb-2 text-xs text-[var(--sg-text-muted)]">
                {history.length.toLocaleString()} of {classified.length.toLocaleString()} drift steps
                {capped && (
                  <span className="text-[var(--sg-text-dim)]">
                    {" "}· showing the most recent {DRIFT_CAP} steps and {SCHEDULES_CAP} schedules per provider; status and the cards may undercount
                  </span>
                )}
              </div>
              {history.length === 0 ? (
                <div className="p-6 text-sm text-[var(--sg-text-muted)] rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
                  No drift activity matches these filters.
                </div>
              ) : (
                <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>When</TableHead>
                        <TableHead>Repository</TableHead>
                        <TableHead>Workspace</TableHead>
                        {hasEnv && (
                          <WorkflowEnvHeader />
                        )}
                        <TableHead>Result</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {page.pageItems.map((r) => (
                        <TableRow key={`${r.id}|${r.dir}|${r.workspace}`} className="cursor-pointer" {...router.nav(`/runs/wm?id=${enc(r.id)}`)}>
                          <TableCell className="text-[var(--sg-text-muted)]" title={formatAbsoluteTime(r.createdAt)}>
                            {formatRelativeTime(r.createdAt)}
                          </TableCell>
                          <TableCell className="font-mono text-[var(--sg-text-muted)]">{r.repoOwner}/{r.repoName}</TableCell>
                          <TableCell className="font-mono text-xs text-[var(--sg-text)]">
                            {r.dir || "."} <span className="text-[var(--sg-text-muted)]">· {r.workspace}</span>
                          </TableCell>
                          {hasEnv && <TableCell className="text-[var(--sg-text-muted)]">{r.environment || "—"}</TableCell>}
                          <TableCell>
                            {r.kind === "apply" ? (
                              <StatusChip status={r.success ? "reconcile-run" : "failed"} />
                            ) : r.hasChanges ? (
                              <StatusChip status="drifted" />
                            ) : (
                              <StatusChip status="clean" />
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                  {page.totalPages > 1 && (
                    <PaginationControls
                      currentPage={page.page}
                      totalPages={page.totalPages}
                      totalResults={page.total}
                      pageSize={PAGE_SIZE}
                      hasNext={page.hasNext}
                      hasPrevious={page.hasPrevious}
                      onNext={page.next}
                      onPrevious={page.previous}
                    />
                  )}
                </div>
              )}
            </div>
          </div>
        </AsyncSection>
      </div>
    </div>
  );
}

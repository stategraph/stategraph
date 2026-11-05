"use client";

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowLeft, ChevronLeft, ChevronRight, ExternalLink, GitPullRequest, RefreshCw } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import { useInitialLoad } from "@/hooks/useInitialLoad";
import { PlanOutput, classifyLine } from "@/components/plans";
import { parsePlanStdoutByAddress } from "@/lib/plan/snippets";
import {
  OutcomeChip,
  OutputModal,
  OutputSizeGuard,
  StepOutputView,
  WmCostPanel,
  WmGatePanel,
  WmSummaryPanel,
  ResourceTotalsLine,
  type ApprovalRow,
  type DownloadContext,
  type ExpandOutput,
  type GateRow,
  type SummaryTarget,
} from "@/components/wm";
import { ciRunUrl, prSigil, providerName, pullRequestUrl, type VcsProvider } from "@/lib/vcs/links";
import { VCS_PROVIDERS, asNumber, asText, orchestrationUnavailable } from "@/lib/mql/providers";
import { OrchestrationUnavailable } from "@/components/orchestration";
import { StatusPill } from "@/components/status/StatusPill";
import { STEP_STATUS_TONE } from "@/components/status/tones";
import { sqlLiteral } from "@/lib/mql/escape";
import { outputFilename } from "@/lib/wm/download";
import { formatAbsoluteTime, formatDuration, formatRelativeTime } from "@/lib/utils/time";
import {
  applyOutputs,
  countsFor,
  decodeCost,
  dirspaceAnchor,
  exitCode,
  groupByDirspace,
  groupSteps,
  hookSteps,
  isActualFailure,
  isStepVisible,
  planBody,
  planDiff,
  RESOURCE_SUMMARY_SLOTS,
  resourceSummaryFor,
  runHooks,
  runKindLabel,
  runOutcome,
  runSummary,
  stepCmd,
  stepError,
  stepLabel,
  stepStatus,
  stepText,
  totalCounts,
  type Counts,
  type DirspaceGroup,
  type Json,
  type Outcome,
  type RawStep,
  type ResourceSummary,
  type RunHooks,
  type SummaryRow,
  type StepStatus,
} from "@/lib/wm/decode";

const UUID_RE = /^[0-9a-fA-F-]{36}$/;
const POLL_MS = 5000;
// Recent runs fetched per provider on every detail open, purely to power the
// prev/next arrows; outside this window they just disable.
const NAV_WINDOW = 50;

interface Header {
  provider: VcsProvider;
  id: string;
  repo: string;
  owner: string;
  repoName: string;
  repository: number;
  state: string;
  runType: string;
  runKind: string;
  environment: string;
  branch: string;
  pullNumber: string;
  runId: string;
  createdAt: string;
  completedAt: string;
  username: string;
}

const TABS = ["summary", "changes", "tree", "apply", "cost", "steps", "raw"] as const;
type Tab = (typeof TABS)[number];
const TAB_LABEL: Record<Tab, string> = {
  summary: "Summary",
  changes: "Changes",
  tree: "Tree",
  apply: "Apply",
  cost: "Cost",
  steps: "Steps",
  raw: "Raw",
};

function CountsLine({ counts }: { counts: Counts }) {
  return (
    <span className="font-mono">
      <span className="text-[var(--sg-op-create)]">{counts.add} to add</span>,{" "}
      <span className="text-[var(--sg-op-update)]">{counts.change} to change</span>,{" "}
      <span className="text-[var(--sg-op-destroy)]">{counts.destroy} to destroy</span>
    </span>
  );
}

// An unreported count renders `-` and the counts are joined with `, ` (the
// backend count_str and describe conventions). The decoder already hid an
// all-null summary, so a non-null prop always renders the line.
function ResourceSummaryLine({ summary }: { summary: ResourceSummary }) {
  const line = RESOURCE_SUMMARY_SLOTS.map(([slot, label]) => `${summary[slot] ?? "-"} ${label}`).join(", ");
  return <span className="text-[11px] text-[var(--sg-text-muted)]">{line}</span>;
}

// Shared step header: label, command chip, status, index, timestamp.
function StepHeaderRow({ step, badge }: { step: RawStep; badge?: string }) {
  const cmd = stepCmd(step.payload).join(" ");
  const status = stepStatus(step);
  return (
    <div className="px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-sm flex items-center gap-2 flex-wrap">
      <span className="text-xs text-[var(--sg-text)]">{stepLabel(step.step)}</span>
      <span className="font-mono text-[10px] text-[var(--sg-text-dim)]">{step.step}</span>
      {cmd && (
        <span
          title={cmd}
          className="font-mono text-[10px] text-[var(--sg-text-muted)] bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded px-1.5 py-0.5 max-w-56 truncate"
        >
          {cmd}
        </span>
      )}
      {badge && <span className="text-[10px] text-[var(--sg-text-dim)]">{badge}</span>}
      <span className="ml-auto">
        <StatusPill tone={STEP_STATUS_TONE[status]} label={status} ariaPrefix="Step" />
      </span>
      <span className="text-[10px] text-[var(--sg-text-dim)]">idx {step.idx}</span>
      {step.createdAt && (
        <span className="text-[10px] text-[var(--sg-text-dim)]" title={formatAbsoluteTime(step.createdAt)}>
          {formatRelativeTime(step.createdAt)}
        </span>
      )}
    </div>
  );
}

/** Identity of one dirspace, shown inside the output container's toolbar so a
 *  reader always knows which directory and workspace produced the output. */
function DirspaceHeading({
  dir,
  workspace,
  extra,
}: {
  dir: string;
  workspace: string;
  extra?: React.ReactNode;
}) {
  return (
    <>
      <span className="font-mono text-xs font-semibold text-[var(--sg-text)] truncate">{dir || "."}</span>
      <span className="inline-flex items-center gap-1.5 rounded border border-[var(--sg-border)] px-1.5 py-0.5 whitespace-nowrap">
        <span className="text-[9px] font-medium uppercase tracking-wider text-[var(--sg-text-dim)]">
          Workspace
        </span>
        <span className="font-mono text-[11px] text-[var(--sg-text)]">{workspace}</span>
      </span>
      {extra}
    </>
  );
}

// ── Tab: Changes — diff-colored plan per dirspace ────────────────────────────
interface OutputTabProps {
  groups: DirspaceGroup[];
  downloadContext: DownloadContext;
  onExpand: ExpandOutput;
}

function ChangesTab({ groups, downloadContext, onExpand }: OutputTabProps) {
  const withPlan = groups.filter((g) => g.plan);
  if (withPlan.length === 0) {
    return <div className="p-8 text-sm text-[var(--sg-text-muted)]">No plan output for this run.</div>;
  }
  return (
    <div className="py-2">
      {withPlan.map((g) => {
        const payload = g.plan!.payload;
        // The runner sends both halves of a plan: the engine's diff in `plan`
        // and the plan command's stdout in `text`. Changes shows the diff; the
        // raw stdout lives in the Raw tab.
        const diff = planDiff(payload);
        const body = diff || planBody(payload);
        const counts = countsFor(payload);
        const scopeTitle = `Plan · ${g.dir || "."}:${g.workspace}`;
        const name = (suffix: string) =>
          outputFilename({ ...downloadContext, step: `tf_plan${suffix}` });
        const heading = (
          <DirspaceHeading
            dir={g.dir}
            workspace={g.workspace}
            extra={counts ? <span className="text-[11px] whitespace-nowrap"><CountsLine counts={counts} /></span> : null}
          />
        );
        return (
          <div key={`${g.dir}|${g.workspace}`} id={dirspaceAnchor(g.dir, g.workspace)} className="scroll-mt-2">
            {body ? (
              <div className="mx-4 my-3 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] shadow-sm overflow-hidden">
                <OutputSizeGuard
                  content={body}
                  title={scopeTitle}
                  downloadName={name("")}
                  onExpand={onExpand}
                  heading={heading}
                >
                  {(t) => <PlanOutput text={t} className="m-0 border-0 rounded-none shadow-none" copyable={false} />}
                </OutputSizeGuard>
              </div>
            ) : (
              <div className="px-6 pb-4 text-xs text-[var(--sg-text-dim)]">No plan text.</div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Tab: Tree — per-resource-address blocks parsed from the plan text ─────────
function TreeTab({ groups }: { groups: DirspaceGroup[] }) {
  const entries = useMemo(() => {
    const out: { dir: string; workspace: string; addresses: [string, string][] }[] = [];
    for (const g of groups) {
      if (!g.plan) continue;
      const map = parsePlanStdoutByAddress(planBody(g.plan.payload));
      if (map.size > 0) out.push({ dir: g.dir, workspace: g.workspace, addresses: [...map.entries()] });
    }
    return out;
  }, [groups]);

  const [open, setOpen] = useState<string | null>(null);
  if (entries.length === 0) {
    return (
      <div className="p-8 text-sm text-[var(--sg-text-muted)]">
        No per-resource changes could be parsed from this plan.
      </div>
    );
  }
  const opGlyph = (snippet: string) => {
    const first = snippet.split("\n").find((l) => classifyLine(l).kind && classifyLine(l).kind !== "comment");
    const kind = first ? classifyLine(first).kind : null;
    if (kind === "create") return { c: "text-[var(--sg-op-create)]", g: "+" };
    if (kind === "destroy") return { c: "text-[var(--sg-op-destroy)]", g: "-" };
    if (kind === "replace") return { c: "text-[var(--sg-op-destroy)]", g: "±" };
    return { c: "text-[var(--sg-op-update)]", g: "~" };
  };
  return (
    <div className="p-4 space-y-4">
      {entries.map((e) => (
        <div key={`${e.dir}|${e.workspace}`} className="rounded-lg border border-[var(--sg-border)] overflow-hidden">
          <div className="px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-sm font-mono text-[var(--sg-text)]">
            {e.dir || "."} <span className="text-[var(--sg-text-muted)]">· {e.workspace}</span>
          </div>
          <div className="divide-y divide-[var(--sg-border)]">
            {e.addresses.map(([addr, snippet], i) => {
              const key = `${e.dir}|${addr}|${i}`;
              const { c, g } = opGlyph(snippet);
              const isOpen = open === key;
              return (
                <div key={key}>
                  <button
                    type="button"
                    onClick={() => setOpen(isOpen ? null : key)}
                    className="w-full flex items-center gap-2 px-4 py-2 text-left hover:bg-[var(--sg-bg-2)] cursor-pointer"
                  >
                    <span className={`font-mono ${c}`}>{g}</span>
                    <span className="font-mono text-xs text-[var(--sg-text)] truncate">{addr}</span>
                  </button>
                  {isOpen && (
                    <pre className="text-xs font-mono whitespace-pre-wrap bg-[var(--sg-bg-2)] px-4 py-3 text-[var(--sg-text-muted)] overflow-x-auto">
                      {snippet}
                    </pre>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

// ── Tab: Apply — apply output + terraform outputs per dirspace ────────────────
function ApplyTab({ groups, downloadContext, onExpand }: OutputTabProps) {
  const withApply = groups.filter((g) => g.apply);
  if (withApply.length === 0) {
    return <div className="p-8 text-sm text-[var(--sg-text-muted)]">This run did not apply.</div>;
  }
  return (
    <div className="py-2">
      {withApply.map((g) => {
        const p = g.apply!.payload;
        const text = stepText(p);
        const err = stepError(p);
        const outs = applyOutputs(p);
        const ec = exitCode(p);
        return (
          <div key={`${g.dir}|${g.workspace}`} id={dirspaceAnchor(g.dir, g.workspace)} className="scroll-mt-2">
            {text ? (
              <div className="mx-4 my-3 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] shadow-sm overflow-hidden">
                <OutputSizeGuard
                  content={text}
                  title={`Apply · ${g.dir || "."}:${g.workspace}`}
                  downloadName={outputFilename({ ...downloadContext, step: "tf_apply" })}
                  onExpand={onExpand}
                  heading={
                    <DirspaceHeading
                      dir={g.dir}
                      workspace={g.workspace}
                      extra={
                        ec !== undefined ? (
                          <span className={`text-[11px] font-mono whitespace-nowrap ${ec === 0 ? "text-[var(--sg-success)]" : "text-[var(--sg-error)]"}`}>
                            exit {ec}
                          </span>
                        ) : null
                      }
                    />
                  }
                >
                  {(t) => <PlanOutput text={t} className="m-0 border-0 rounded-none shadow-none" copyable={false} />}
                </OutputSizeGuard>
              </div>
            ) : (
              <div className="px-6 pt-4 pb-2 text-xs text-[var(--sg-text-dim)]">
                <span className="font-mono text-[var(--sg-text)]">{g.dir || "."}</span> · no apply output.
              </div>
            )}
            {err && (
              <div className="mx-6 mb-3 p-3 rounded-md bg-[var(--sg-error-bg)] border border-[var(--sg-error)]/30 text-xs font-mono text-[var(--sg-error)]">
                {err}
              </div>
            )}
            {outs.length > 0 && (
              <div className="mx-6 mb-4 rounded-md border border-[var(--sg-border-light)] overflow-hidden">
                <div className="px-3 py-1.5 bg-[var(--sg-bg-2)] text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                  Outputs
                </div>
                {outs.map((o) => (
                  <div key={o.name} className="flex items-center justify-between gap-3 border-t border-[var(--sg-border-light)] px-3 py-1.5">
                    <span className="font-mono text-xs text-[var(--sg-text)]">{o.name}</span>
                    <span className={`font-mono text-xs ${o.sensitive ? "text-[var(--sg-text-dim)] italic" : "text-[var(--sg-text-muted)]"}`}>
                      {o.value}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Tab: Steps — grouped per dirspace + run hooks, visibility-filtered ────────
interface StepsTabProps {
  groups: DirspaceGroup[];
  hooks: RunHooks;
  downloadContext: DownloadContext;
  onExpand: ExpandOutput;
}

function StepsSection({
  anchor,
  title,
  subtitle,
  steps,
  resourceSummary,
  downloadContext,
  onExpand,
}: {
  /** DOM id of a dirspace section; run hooks have none. */
  anchor?: string;
  title: string;
  subtitle?: string;
  steps: RawStep[];
  /** Dirspace groups pass their plan step's summary; run-hook sections omit it. */
  resourceSummary?: ResourceSummary | null;
  downloadContext: DownloadContext;
  onExpand: ExpandOutput;
}) {
  const visible = steps.filter(isStepVisible);
  const hidden = steps.length - visible.length;
  const failed = steps.some(isActualFailure);
  const ignored = !failed && steps.some((st) => stepStatus(st) === "ignored");
  const sectionStatus: StepStatus = failed ? "failure" : ignored ? "ignored" : "success";
  return (
    <div id={anchor} className="rounded-lg border border-[var(--sg-border)] overflow-hidden scroll-mt-2">
      <div className="px-4 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-sm flex items-center gap-2">
        <StatusPill tone={STEP_STATUS_TONE[sectionStatus]} label={sectionStatus} ariaPrefix="Steps" />
        <span className="font-mono text-xs text-[var(--sg-text)]">{title}</span>
        {subtitle && <span className="text-xs text-[var(--sg-text-muted)]">· {subtitle}</span>}
        {resourceSummary && <ResourceSummaryLine summary={resourceSummary} />}
        <span className="text-[10px] text-[var(--sg-text-dim)] ml-auto">
          {steps.length} step{steps.length === 1 ? "" : "s"}
        </span>
      </div>
      {visible.length === 0 ? (
        <div className="p-3 text-xs text-[var(--sg-text-dim)]">
          {failed ? "A step failed." : "All steps completed."}
          {hidden > 0 && ` ${hidden} output${hidden === 1 ? "" : "s"} hidden by visibility rules — see the Raw tab.`}
        </div>
      ) : (
        <div className="divide-y divide-[var(--sg-border-light)]">
          {visible.map((st, i) => (
            <div key={`${st.idx}-${i}`} className="pb-3">
              <StepHeaderRow step={st} />
              <div className="px-3">
                <StepOutputView step={st} downloadContext={downloadContext} onExpand={onExpand} />
              </div>
            </div>
          ))}
          {hidden > 0 && (
            <div className="p-2 text-[10px] text-[var(--sg-text-dim)]">
              {hidden} output{hidden === 1 ? "" : "s"} hidden by visibility rules — see the Raw tab.
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function StepsTab({ groups, hooks, downloadContext, onExpand }: StepsTabProps) {
  const hookList = hookSteps(hooks);
  if (groups.length === 0 && hookList.length === 0) {
    return <div className="p-8 text-sm text-[var(--sg-text-muted)]">No step outputs recorded.</div>;
  }
  return (
    <div className="p-4 space-y-3">
      {groups.map((g) => (
        <StepsSection
          key={`${g.dir}|${g.workspace}`}
          anchor={dirspaceAnchor(g.dir, g.workspace)}
          title={g.dir || "."}
          subtitle={g.workspace}
          steps={groupSteps(g)}
          resourceSummary={resourceSummaryFor(g.plan?.payload ?? null)}
          downloadContext={downloadContext}
          onExpand={onExpand}
        />
      ))}
      {hookList.length > 0 && (
        <StepsSection
          title="Run hooks"
          steps={hookList}
          downloadContext={downloadContext}
          onExpand={onExpand}
        />
      )}
    </div>
  );
}

// ── Tab: Raw — every step, unfiltered, in execution order ────────────────────
function RawTab({
  steps,
  downloadContext,
  onExpand,
}: {
  steps: RawStep[];
  downloadContext: DownloadContext;
  onExpand: ExpandOutput;
}) {
  const ordered = [...steps].sort((a, b) => a.idx - b.idx);
  if (ordered.length === 0) {
    return <div className="p-8 text-sm text-[var(--sg-text-muted)]">No step outputs recorded.</div>;
  }
  return (
    <div className="p-4 space-y-3">
      {ordered.map((st, i) => {
        const dir = asText((st.scope as Json | null)?.dir);
        const visibleOn = asText(st.payload?.visible_on);
        return (
          <div key={`${st.idx}-${i}`} className="rounded-lg border border-[var(--sg-border)] overflow-hidden">
            <StepHeaderRow
              step={st}
              badge={`${dir ? `${dir} · ` : ""}visible_on: ${visibleOn || "none"}`}
            />
            <div className="px-3 pb-3">
              <StepOutputView step={st} downloadContext={downloadContext} onExpand={onExpand} />
            </div>
          </div>
        );
      })}
    </div>
  );
}

function isTab(v: string): v is Tab {
  return (TABS as readonly string[]).includes(v);
}

/** The tab that holds the output of one dirspace: its apply, else its plan,
 *  else its steps. Null when the run has no output for the dirspace. */
function dirspaceTab(groups: DirspaceGroup[], dir: string, workspace: string): Tab | null {
  const g = groups.find((x) => x.dir === dir && x.workspace === workspace);
  if (!g) return null;
  return g.apply ? "apply" : g.plan ? "changes" : "steps";
}

function WmRunDetailContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const id = searchParams.get("id") ?? "";
  const [header, setHeader] = useState<Header | null>(null);
  const [steps, setSteps] = useState<RawStep[] | null>(null);
  const [dirspaces, setDirspaces] = useState<Array<{ dir: string; workspace: string }>>([]);
  const [gates, setGates] = useState<GateRow[]>([]);
  const [approvals, setApprovals] = useState<ApprovalRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [siblings, setSiblings] = useState<string[]>([]);
  // The active tab lives in ?view=; absent, the run's default tab shows.
  const [viewParam, setActiveTab] = useUrlSyncedParam("view", "");
  const activeTab: Tab | null = isTab(viewParam) ? viewParam : null;
  // The dirspace a summary row opened, scrolled to once its tab renders.
  const focus = useRef<string | null>(null);
  // The dirspace ?dir=&workspace= names, scrolled to once the outputs render.
  const linkedFocus = useRef<string | null>(
    searchParams.has("dir") && searchParams.has("workspace")
      ? dirspaceAnchor(searchParams.get("dir") ?? "", searchParams.get("workspace") ?? "")
      : null,
  );
  const [modal, setModal] = useState<{ title: string; content: string; render: (text: string) => React.ReactNode } | null>(null);
  const onExpand = useCallback<ExpandOutput>((content, title, render) => setModal({ title, content, render }), []);

  const load = useCallback(async () => {
    // id is interpolated into MQL below; never run with a non-uuid.
    if (!UUID_RE.test(id)) return;
    try {
      const lit = sqlLiteral(id);
      const headerCols =
        "id, repository, pull_number, run_id, completed_at, state, run_type, run_kind, environment, branch, repo_owner, repo_name, username, created_at";
      // Per-provider tolerant: one provider's table being absent (or the whole
      // orchestration schema off) must not blank a run that lives in the other.
      let sawTableAccessErr = false;
      const [hdrs, outsRes, dirspacesRes] = await Promise.all([
        Promise.all(
          VCS_PROVIDERS.map((p) =>
            executeMQL(`select ${headerCols} from ${p}_work_manifests where id = ${lit} limit 1`)
              .then((r) => ({ provider: p, row: r.data[0] as Record<string, unknown> | undefined }))
              .catch((e) => {
                if (orchestrationUnavailable(e)) sawTableAccessErr = true;
                return { provider: p, row: undefined };
              }),
          ),
        ),
        executeMQL(
          `select idx, step, scope, payload, success, created_at, ignore_errors from workflow_step_outputs where work_manifest = ${lit} order by idx limit 500`,
        ).catch((e) => {
          if (orchestrationUnavailable(e)) sawTableAccessErr = true;
          return { data: [] as unknown[] };
        }),
        executeMQL(
          `select path, workspace from work_manifest_dirspaceflows where work_manifest = ${lit} limit 1000`,
        ).catch(() => ({ data: [] as unknown[] })),
      ]);
      const outs = outsRes;
      // Every provider table missing AND no row found → orchestration is off.
      if (sawTableAccessErr && hdrs.every((h) => h.row === undefined)) {
        setUnavailable(true);
        return;
      }
      // The id is a uuid, so it exists in exactly one provider's table.
      const hit = hdrs.find((h) => h.row !== undefined);
      const provider = hit?.provider ?? "github";
      const h0 = hit?.row;
      if (!h0) {
        setHeader(null);
        setSteps([]);
        setError(null);
        return;
      }
      const repository = asNumber(h0.repository);
      // Both ids are interpolated into MQL unquoted below: coerce to numbers
      // (asNumber() yields 0 for anything else) and only query on positive ones.
      const pull = asNumber(h0.pull_number);
      const pullNumber = pull > 0 ? String(pull) : "";
      setHeader({
        provider,
        id: asText(h0.id),
        repo: `${asText(h0.repo_owner)}/${asText(h0.repo_name)}`,
        owner: asText(h0.repo_owner),
        repoName: asText(h0.repo_name),
        repository,
        state: asText(h0.state),
        runType: asText(h0.run_type),
        runKind: asText(h0.run_kind),
        environment: asText(h0.environment),
        branch: asText(h0.branch),
        pullNumber,
        runId: asText(h0.run_id),
        createdAt: asText(h0.created_at),
        completedAt: asText(h0.completed_at),
        username: asText(h0.username),
      });
      setDirspaces(
        dirspacesRes.data.map((r) => {
          const o = r as Record<string, unknown>;
          return { dir: asText(o.path), workspace: asText(o.workspace) };
        }),
      );
      setSteps(
        outs.data.map((r) => {
          const o = r as Record<string, unknown>;
          return {
            idx: typeof o.idx === "number" ? o.idx : 0,
            step: asText(o.step),
            success: o.success === true,
            scope: (o.scope ?? null) as Json | null,
            payload: (o.payload ?? null) as Json | null,
            createdAt: asText(o.created_at),
            ignoreErrors: o.ignore_errors === true,
          };
        }),
      );
      setError(null);

      // Gates only exist when the run is tied to a merge request. Fetch them
      // (and their approvals) via the *_map join — best-effort, non-fatal.
      if (repository > 0 && pull > 0) {
        const gateQ = `select g.name as name, g.dir as dir, g.workspace as workspace, g.token as token, g.gate as gate from gates as g inner join ${provider}_pull_requests_map as m on m.core_id = g.pull_request where m.repository_id = ${repository} and m.pull_number = ${pull} limit 50`;
        const apprQ = `select ga.approver as approver, ga.token as token, ga.created_at as created_at from gate_approvals as ga inner join gates as g on g.token = ga.token inner join ${provider}_pull_requests_map as m on m.core_id = g.pull_request where m.repository_id = ${repository} and m.pull_number = ${pull} limit 100`;
        const [gr, ar] = await Promise.all([
          executeMQL(gateQ).catch(() => ({ data: [] as unknown[] })),
          executeMQL(apprQ).catch(() => ({ data: [] as unknown[] })),
        ]);
        setGates(
          gr.data.map((r) => {
            const o = r as Record<string, unknown>;
            return {
              name: asText(o.name),
              dir: asText(o.dir),
              workspace: asText(o.workspace),
              token: asText(o.token),
              gate: (o.gate ?? null) as Record<string, unknown> | null,
            };
          }),
        );
        setApprovals(
          ar.data.map((r) => {
            const o = r as Record<string, unknown>;
            return { approver: asText(o.approver), token: asText(o.token), created_at: asText(o.created_at) };
          }),
        );
      } else {
        setGates([]);
        setApprovals([]);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load run");
    }
  }, [id]);
  // `load` itself refuses a non-uuid id, so the initial fetch needs no guard.
  useInitialLoad(load);

  // Poll while the run is still in flight.
  const live = header !== null && (header.state === "queued" || header.state === "running");
  useEffect(() => {
    if (!live) return;
    const t = window.setInterval(() => void load(), POLL_MS);
    return () => window.clearInterval(t);
  }, [live, load]);

  // Recent-runs window for prev/next navigation (ids in created_at desc order).
  useEffect(() => {
    let cancelled = false;
    const t = window.setTimeout(() => {
      void Promise.all(
        VCS_PROVIDERS.map((p) =>
          executeMQL(`select id, created_at from ${p}_work_manifests order by created_at desc limit ${NAV_WINDOW}`)
            .then((r) => r.data as Record<string, unknown>[])
            .catch(() => [] as Record<string, unknown>[]),
        ),
      )
        .then((results) => {
          if (cancelled) return;
          const merged = results
            .flat()
            .sort((a, b) => asText(b.created_at).localeCompare(asText(a.created_at)))
            .map((x) => asText(x.id));
          setSiblings(merged);
        })
        .catch(() => undefined);
    }, 0);
    return () => { cancelled = true; window.clearTimeout(t); };
  }, []);

  const { olderId, newerId } = useMemo(() => {
    const i = siblings.indexOf(id);
    if (i < 0) return { olderId: null as string | null, newerId: null as string | null };
    return {
      olderId: i < siblings.length - 1 ? siblings[i + 1] : null,
      newerId: i > 0 ? siblings[i - 1] : null,
    };
  }, [siblings, id]);
  const goToRun = useCallback(
    (rid: string) => {
      const view = activeTab ? `&view=${activeTab}` : "";
      router.push(`/runs/wm?id=${rid}${view}`);
    },
    [router, activeTab],
  );

  const groups = useMemo(() => (steps ? groupByDirspace(steps) : []), [steps]);
  const hooks = useMemo(() => (steps ? runHooks(steps) : { others: [] }), [steps]);
  const counts = useMemo(() => totalCounts(groups), [groups]);
  const summary = useMemo(() => runSummary(groups, dirspaces), [groups, dirspaces]);
  const outcome = useMemo<Outcome>(
    () => (header ? runOutcome(header.state, steps ?? []) : "queued"),
    [header, steps],
  );
  const cost = useMemo(() => decodeCost(hooks.cost?.payload ?? null), [hooks]);

  const downloadContext = useMemo<DownloadContext>(
    () => ({
      repo: header?.repo ?? "",
      pullNumber: header?.pullNumber || undefined,
      runType: header?.runType || undefined,
    }),
    [header],
  );

  const availableTabs = useMemo<Tab[]>(() => {
    const out: Tab[] = [];
    if (summary.rows.length > 0) out.push("summary");
    if (groups.some((g) => g.plan)) out.push("changes");
    if (groups.some((g) => g.plan && parsePlanStdoutByAddress(planBody(g.plan.payload)).size > 0)) out.push("tree");
    if (groups.some((g) => g.apply)) out.push("apply");
    if (cost) out.push("cost");
    out.push("steps");
    out.push("raw");
    return out;
  }, [groups, cost, summary]);

  // Without ?view=, a link to one dirspace opens on the tab that holds its
  // output, a run of several dirspaces on Summary, and a run of one on its
  // first output tab. A tab the data does not offer falls back the same way.
  const linkedTab =
    searchParams.has("dir") && searchParams.has("workspace")
      ? dirspaceTab(groups, searchParams.get("dir") ?? "", searchParams.get("workspace") ?? "")
      : null;
  const defaultTab: Tab =
    linkedTab && availableTabs.includes(linkedTab)
      ? linkedTab
      : summary.rows.length > 1
        ? "summary"
        : (availableTabs.find((t) => t !== "summary") ?? availableTabs[0]);
  const effectiveTab: Tab = activeTab && availableTabs.includes(activeTab) ? activeTab : defaultTab;

  const openFromSummary = useCallback(
    (tab: SummaryTarget, row: SummaryRow) => {
      focus.current = dirspaceAnchor(row.dir, row.workspace);
      setActiveTab(tab);
    },
    [setActiveTab],
  );
  useEffect(() => {
    if (!focus.current) return;
    document.getElementById(focus.current)?.scrollIntoView({ block: "start" });
    focus.current = null;
  }, [effectiveTab]);
  useEffect(() => {
    if (!linkedFocus.current || steps === null) return;
    document.getElementById(linkedFocus.current)?.scrollIntoView({ block: "start" });
    linkedFocus.current = null;
  }, [steps, effectiveTab]);

  const invalidId = id !== "" && !UUID_RE.test(id);
  // No id at all: nothing to load, so surface a message instead of a forever
  // spinner (the effects only run for a valid uuid).
  const shownError = error ?? (id === "" ? "No run selected." : invalidId ? "Invalid run id." : null);

  if (unavailable) {
    return <OrchestrationUnavailable />;
  }

  return (
    <div className="flex flex-col h-full">
      <header className="px-6 pt-6 pb-3 border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-3">
          <button
            {...router.nav("/runs")}
            className="p-1 rounded hover:bg-[var(--sg-bg-2)]"
            aria-label="Back to runs"
          >
            <ArrowLeft className="w-4 h-4 text-[var(--sg-text-muted)]" />
          </button>
          <h1 className="text-lg font-semibold text-[var(--sg-text)]">Run detail</h1>
          {header && <OutcomeChip outcome={outcome} />}
          {live && <span className="text-xs text-[var(--sg-accent)]">live</span>}
          <div className="ml-auto flex items-center gap-1">
            <button
              onClick={() => olderId && goToRun(olderId)}
              disabled={!olderId}
              title="Older run"
              aria-label="Older run"
              className="p-1 rounded hover:bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-30 disabled:cursor-not-allowed"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              onClick={() => newerId && goToRun(newerId)}
              disabled={!newerId}
              title="Newer run"
              aria-label="Newer run"
              className="p-1 rounded hover:bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-30 disabled:cursor-not-allowed"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
            <button
              onClick={() => void load()}
              className="p-1 rounded hover:bg-[var(--sg-bg-2)]"
              aria-label="Refresh"
            >
              <RefreshCw className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />
            </button>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        {shownError ? (
          <div className="m-6 p-3 rounded-lg bg-[var(--sg-error-bg)] border border-[var(--sg-error)]/30 text-sm text-[var(--sg-error)]">
            {shownError}
          </div>
        ) : header === null && steps === null ? (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>
        ) : header === null ? (
          <div className="p-8 text-sm text-[var(--sg-text-muted)]">Run not found.</div>
        ) : (
          <>
            <div className="px-6 py-4 space-y-3 border-b border-[var(--sg-border)]">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="font-mono text-[var(--sg-text)]">{header.repo}</span>
                <span className="text-xs text-[var(--sg-text-muted)]">{header.runType || "run"}</span>
                {header.runKind && <span className="text-xs text-[var(--sg-text-dim)]">· {runKindLabel(header.runKind)}</span>}
                {header.pullNumber && (
                  <button
                    {...router.nav(`/pull-requests/detail?provider=${header.provider}&owner=${encodeURIComponent(header.owner)}&repo=${encodeURIComponent(header.repoName)}&pr=${encodeURIComponent(header.pullNumber)}`)}
                    className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] hover:underline"
                  >
                    <GitPullRequest className="w-3 h-3" /> {prSigil(header.provider)}{header.pullNumber}
                  </button>
                )}
                {header.pullNumber && pullRequestUrl(header.provider, header.owner, header.repoName, header.pullNumber) && (
                  <a
                    href={pullRequestUrl(header.provider, header.owner, header.repoName, header.pullNumber)!}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-xs text-[var(--sg-accent)] hover:underline"
                  >
                    View on {providerName(header.provider)} <ExternalLink className="w-3 h-3" />
                  </a>
                )}
              </div>
              {groups.some((g) => g.plan) && (
                <div className="text-sm">
                  Plan: {summary.totals ? <ResourceTotalsLine totals={summary.totals} /> : <CountsLine counts={counts} />}
                </div>
              )}
              <div className="text-xs text-[var(--sg-text-muted)] flex flex-wrap gap-x-4 gap-y-1">
                {header.branch && <span className="font-mono">{header.branch}</span>}
                {header.environment && <span>env {header.environment}</span>}
                {header.username && <span>by {header.username}</span>}
                <span title={formatAbsoluteTime(header.createdAt)}>{formatRelativeTime(header.createdAt)}</span>
                {header.completedAt && header.createdAt && (
                  <span>took {formatDuration(header.createdAt, header.completedAt)}</span>
                )}
                {header.runId &&
                  (ciRunUrl(header.provider, header.owner, header.repoName, header.runId) ? (
                    <a
                      href={ciRunUrl(header.provider, header.owner, header.repoName, header.runId)!}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-[var(--sg-accent)] hover:underline"
                    >
                      View run <span className="font-mono">{header.runId}</span> on {providerName(header.provider)}{" "}
                      <ExternalLink className="w-3 h-3" />
                    </a>
                  ) : (
                    // No CI run URL for this provider: name the run without a link icon.
                    <span>
                      Run <span className="font-mono">{header.runId}</span>
                    </span>
                  ))}
              </div>
            </div>

            {gates.length > 0 && (
              <div className="px-6 py-4 border-b border-[var(--sg-border)]">
                <WmGatePanel gates={gates} approvals={approvals} />
              </div>
            )}

            <div className="px-6 pt-2">
              <div role="tablist" className="flex items-center gap-1 border-b border-[var(--sg-border)]">
                {availableTabs.map((t) => {
                  const selected = effectiveTab === t;
                  return (
                    <button
                      key={t}
                      role="tab"
                      aria-selected={selected}
                      onClick={() => setActiveTab(t)}
                      className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
                        selected
                          ? "border-[var(--sg-accent)] text-[var(--sg-text)]"
                          : "border-transparent text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
                      }`}
                    >
                      {TAB_LABEL[t]}
                    </button>
                  );
                })}
              </div>
            </div>

            <div>
              {effectiveTab === "summary" && (
                <WmSummaryPanel
                  summary={summary}
                  isApply={header.runType === "apply"}
                  live={live}
                  onOpen={openFromSummary}
                />
              )}
              {effectiveTab === "changes" && (
                <ChangesTab groups={groups} downloadContext={downloadContext} onExpand={onExpand} />
              )}
              {effectiveTab === "tree" && <TreeTab groups={groups} />}
              {effectiveTab === "apply" && (
                <ApplyTab groups={groups} downloadContext={downloadContext} onExpand={onExpand} />
              )}
              {effectiveTab === "cost" && <WmCostPanel cost={cost} />}
              {effectiveTab === "steps" && (
                <StepsTab groups={groups} hooks={hooks} downloadContext={downloadContext} onExpand={onExpand} />
              )}
              {effectiveTab === "raw" && steps && (
                <RawTab steps={steps} downloadContext={downloadContext} onExpand={onExpand} />
              )}
            </div>
          </>
        )}
      </div>
      <OutputModal
        open={modal !== null}
        onOpenChange={(o) => { if (!o) setModal(null); }}
        title={modal?.title ?? ""}
        content={modal?.content ?? ""}
        render={modal?.render}
      />
    </div>
  );
}

export default function WmRunDetailPage() {
  return (
    <Suspense fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}>
      <WmRunDetailContent />
    </Suspense>
  );
}

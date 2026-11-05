/**
 * Decoders for Terrateam `workflow_step_outputs` rows.
 *
 * Terrateam's runner writes each workflow step verbatim into
 * `workflow_step_outputs` as a free-form `payload` jsonb plus a `scope`. The
 * canonical shapes are defined by the runner and Terrateam's own UI decoders:
 *
 *   scope (dirspace): { type: "dirspace", dir, workspace }
 *   scope (run hook): { type: "run", flow: "hooks", subflow: "pre" | "post" }
 *   tf/plan payload:  { cmd: string[], text, plan, has_changes, exit_code, error? }
 *   tf/apply payload: { cmd: string[], text, exit_code, outputs?, error? }
 *   tf/cost-estimation: { summary:{prev_monthly_cost,total_monthly_cost,diff_monthly_cost},
 *                         currency, dirspaces:[{dir,workspace,prev_..,total_..,diff_..}] }
 *   checkout/env/tf/init: { cmd, text?, exit_code?, visible_on? }
 *
 * Older demo / lite-mode rows omit fields and used legacy scope types
 * ("pr"/"drift") and a made-up `summary:{add,change,destroy}` on tf/plan. Every
 * reader here tolerates BOTH the canonical and legacy shapes and never assumes
 * a key is present — a payload/scope from an unknown Terrateam version must
 * degrade, not throw.
 */

export type Json = Record<string, unknown>;

export interface RawStep {
  idx: number;
  step: string;
  success: boolean;
  scope: Json | null;
  payload: Json | null;
  /** Row insert time; absent on rows fetched before the column was selected. */
  createdAt?: string;
  /** A failed step marked ignore_errors does not fail the run. */
  ignoreErrors?: boolean;
}

const str = (v: unknown): string =>
  typeof v === "string" ? v : v == null ? "" : String(v);
const num = (v: unknown): number | undefined => {
  if (typeof v === "number") return Number.isFinite(v) ? v : undefined;
  if (typeof v === "string" && v.trim() !== "" && Number.isFinite(Number(v))) return Number(v);
  return undefined;
};
const numOrNull = (v: unknown): number | null => {
  const n = num(v);
  return n === undefined ? null : n;
};
const asObj = (v: unknown): Json | null =>
  v && typeof v === "object" && !Array.isArray(v) ? (v as Json) : null;
const asArr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);

// --- scope ------------------------------------------------------------------
export function scopeType(s: Json | null): string { return str(s?.type); }
export function scopeDir(s: Json | null): string { return str(s?.dir); }
export function scopeWorkspace(s: Json | null): string { return str(s?.workspace); }
export function isRunScope(s: Json | null): boolean { return scopeType(s) === "run"; }
/** Canonical "dirspace"; legacy "pr"/"drift" also carry dir/workspace. Run-scope
 *  hook steps have no dir, so they never match. */
export function isDirspaceScope(s: Json | null): boolean {
  if (isRunScope(s)) return false;
  const t = scopeType(s);
  return t === "dirspace" || t === "pr" || t === "drift" || str(s?.dir) !== "";
}

// --- generic payload readers ------------------------------------------------
export function stepCmd(p: Json | null): string[] {
  return asArr(p?.cmd).map(str).filter((x) => x !== "");
}
export function stepText(p: Json | null): string {
  return str(p?.text) || str(p?.plan_text);
}
/** Diff-syntax body for colored rendering: prefer the dedicated `plan` field,
 *  fall back to raw stdout `text`, then the legacy `plan_text`. */
export function planBody(p: Json | null): string {
  return str(p?.plan) || str(p?.text) || str(p?.plan_text);
}
/** The engine's diff output alone (`payload.plan`), with no stdout fallback —
 *  a plan step carries both halves and the UI shows them as separate blocks. */
export function planDiff(p: Json | null): string {
  return str(p?.plan);
}
/** ignore_errors is a row column; older payloads carried it inline too. */
export function stepIgnoresErrors(st: RawStep): boolean {
  return st.ignoreErrors === true || st.payload?.ignore_errors === true;
}
export function hasChanges(p: Json | null): boolean | undefined {
  return typeof p?.has_changes === "boolean" ? (p.has_changes as boolean) : undefined;
}
export function exitCode(p: Json | null): number | undefined { return num(p?.exit_code); }
export function stepError(p: Json | null): string { return str(p?.error); }

// --- terraform outputs (tf/apply) -------------------------------------------
export interface TfOutput { name: string; value: string; sensitive: boolean; }
function scalar(v: unknown): string {
  if (v == null) return "";
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  try { return JSON.stringify(v); } catch { return String(v); }
}
export function applyOutputs(p: Json | null): TfOutput[] {
  const o = asObj(p?.outputs);
  if (!o) return [];
  return Object.entries(o).map(([name, v]) => {
    const ov = asObj(v);
    const sensitive = ov?.sensitive === true;
    const raw = ov && "value" in ov ? ov.value : v;
    // Presentation only, NOT a security boundary: the plaintext value is in
    // the MQL response this payload came from (visible in devtools). Keeping
    // sensitive values out of the response is the server's job.
    return { name, sensitive, value: sensitive ? "(sensitive)" : scalar(raw) };
  });
}

// --- plan add/change/destroy counts -----------------------------------------
export interface Counts { add: number; change: number; destroy: number; }
const COUNTS_RE = /Plan:\s+(\d+) to add,\s+(\d+) to change,\s+(\d+) to destroy/;
export function parseCounts(text: string): Counts | null {
  const m = COUNTS_RE.exec(text || "");
  if (!m) return null;
  return { add: +m[1], change: +m[2], destroy: +m[3] };
}
/** Prefer counts parsed from the plan body (matches the terraform CLI); fall
 *  back to the legacy `summary:{add,change,destroy}` shape. */
export function countsFor(p: Json | null): Counts | null {
  const parsed = parseCounts(planBody(p));
  if (parsed) return parsed;
  const sm = asObj(p?.summary);
  if (sm && (num(sm.add) !== undefined || num(sm.change) !== undefined || num(sm.destroy) !== undefined)) {
    return { add: num(sm.add) ?? 0, change: num(sm.change) ?? 0, destroy: num(sm.destroy) ?? 0 };
  }
  return null;
}
export function addCounts(a: Counts, b: Counts): Counts {
  return { add: a.add + b.add, change: a.change + b.change, destroy: a.destroy + b.destroy };
}

// --- plan resource summary (imported/created/updated/replaced/deleted) ------
/** `imported` counts resources the plan imports, whatever their action, so an
 *  import that also updates counts in `imported` and `updated`. */
export interface ResourceSummary {
  imported: number | null;
  created: number | null;
  updated: number | null;
  replaced: number | null;
  deleted: number | null;
}
/** The plan step's `resource_summary` payload field (the runner's
 *  `Resource_summary`): five count slots. Absent key (legacy runners,
 *  no-change plans) and all-null read as null so the caller hides the line —
 *  null means "not reported", never zero. A partial payload keeps every slot,
 *  unreported ones null (rendered as `-`, the backend `count_str`
 *  convention). A non-object value reads as absent; never throws. */
export function resourceSummaryFor(p: Json | null): ResourceSummary | null {
  const rs = asObj(p?.resource_summary);
  if (!rs) return null;
  const summary: ResourceSummary = {
    imported: numOrNull(rs.imported),
    created: numOrNull(rs.created),
    updated: numOrNull(rs.updated),
    replaced: numOrNull(rs.replaced),
    deleted: numOrNull(rs.deleted),
  };
  const reported = (Object.values(summary) as (number | null)[]).some((v) => v !== null);
  return reported ? summary : null;
}

// --- cost estimation --------------------------------------------------------
export interface CostDirspace {
  dir: string; workspace: string;
  prev: number | null; total: number | null; diff: number | null;
}
export interface CostEstimation {
  currency: string;
  prev: number | null; total: number | null; diff: number | null;
  dirspaces: CostDirspace[];
  /** Set when the cost step ran but failed (payload was `{text}` not a summary). */
  failed?: string;
}
export function decodeCost(p: Json | null): CostEstimation | null {
  if (!p) return null;
  const summary = asObj(p.summary);
  if (!summary) {
    const t = str(p.text);
    return t ? { currency: "USD", prev: null, total: null, diff: null, dirspaces: [], failed: t } : null;
  }
  const dirspaces = asArr(p.dirspaces)
    .map(asObj)
    .filter((x): x is Json => x !== null)
    .map((d) => ({
      dir: str(d.dir),
      workspace: str(d.workspace),
      prev: numOrNull(d.prev_monthly_cost),
      total: numOrNull(d.total_monthly_cost),
      diff: numOrNull(d.diff_monthly_cost),
    }));
  return {
    currency: str(p.currency) || "USD",
    prev: numOrNull(summary.prev_monthly_cost),
    total: numOrNull(summary.total_monthly_cost),
    diff: numOrNull(summary.diff_monthly_cost),
    dirspaces,
  };
}

// --- grouping ---------------------------------------------------------------
export interface DirspaceGroup {
  dir: string; workspace: string;
  init?: RawStep; plan?: RawStep; apply?: RawStep; others: RawStep[];
}
/** Engines whose steps are named `<engine>/<op>`; mirrors `plan_steps` in
 *  terrat_vcs_provider2.ml, so a pulumi or custom run structures like tf. */
const ENGINES = ["tf", "pulumi", "custom", "fly", "stategraph"];
const engineStep = (op: string) => (step: string): boolean =>
  ENGINES.some((engine) => step === `${engine}/${op}`);
export const isInitStep = engineStep("init");
export const isPlanStep = engineStep("plan");
export const isApplyStep = engineStep("apply");

/** Split dirspace-scoped steps into per-(dir,workspace) groups, pulling the
 *  well-known init/plan/apply steps out for structured rendering. */
export function groupByDirspace(steps: RawStep[]): DirspaceGroup[] {
  const map = new Map<string, DirspaceGroup>();
  for (const st of steps) {
    if (!isDirspaceScope(st.scope)) continue;
    const dir = scopeDir(st.scope);
    const workspace = scopeWorkspace(st.scope);
    const key = `${dir}|${workspace}`;
    let g = map.get(key);
    if (!g) { g = { dir, workspace, others: [] }; map.set(key, g); }
    if (isPlanStep(st.step)) g.plan = st;
    else if (isApplyStep(st.step)) g.apply = st;
    else if (isInitStep(st.step)) g.init = st;
    else g.others.push(st);
  }
  return [...map.values()];
}

export interface RunHooks { checkout?: RawStep; env?: RawStep; cost?: RawStep; others: RawStep[]; }
export function runHooks(steps: RawStep[]): RunHooks {
  const h: RunHooks = { others: [] };
  for (const st of steps) {
    if (!isRunScope(st.scope)) continue;
    if (st.step === "checkout") h.checkout = st;
    else if (st.step === "env") h.env = st;
    else if (st.step === "tf/cost-estimation") h.cost = st;
    else h.others.push(st);
  }
  return h;
}

// --- step status and visibility ----------------------------------------------
export type StepStatus = "success" | "failure" | "ignored";
/** A failed step with ignore_errors renders as "ignored" and never fails the run. */
export function isActualFailure(st: RawStep): boolean {
  return st.success === false && !stepIgnoresErrors(st);
}
export function stepStatus(st: RawStep): StepStatus {
  if (st.success !== false) return "success";
  return stepIgnoresErrors(st) ? "ignored" : "failure";
}

/** Workflow authors control per-step output visibility with `visible_on`
 *  (always | failure | success; legacy "error" = failure). A step with no
 *  setting shows its output only on failure — matching the PR comment and the
 *  iris console. Unknown values fail open. */
export function isStepVisible(st: RawStep): boolean {
  const v = str(st.payload?.visible_on);
  switch (v) {
    case "always":
      return true;
    case "failure":
    case "error":
    case "":
      return isActualFailure(st);
    case "success":
      return st.success === true || stepIgnoresErrors(st);
    default:
      return true;
  }
}

/** A dirspace group's steps in execution order: init, plan, apply, then the rest. */
export function groupSteps(g: DirspaceGroup): RawStep[] {
  return [g.init, g.plan, g.apply, ...g.others]
    .filter((s): s is RawStep => s !== undefined)
    .sort((a, b) => a.idx - b.idx);
}
/** Run-hook steps in execution order; cost estimation has its own tab. */
export function hookSteps(h: RunHooks): RawStep[] {
  return [h.checkout, h.env, ...h.others]
    .filter((s): s is RawStep => s !== undefined)
    .sort((a, b) => a.idx - b.idx);
}

// --- step labels --------------------------------------------------------------
const STEP_LABELS: Record<string, string> = {
  "tf/init": "Initialize",
  "tf/plan": "Plan",
  "tf/apply": "Apply",
  "tf/cost-estimation": "Cost estimation",
  "auth/update-terrateam-github-token": "Authenticate",
  "auth/oidc": "OIDC authenticate",
  checkout: "Checkout",
  env: "Environment",
  run: "Run",
};
const cap = (s: string): string => (s ? s[0].toUpperCase() + s.slice(1) : s);
/** Human label for a step name; `<engine>/<op>` generalizes so non-Terraform
 *  engines (custom/plan, pulumi/apply, ...) get readable labels too. */
/** Display label for a work manifest's run kind: the engine's `pr` reads as
 *  PR; other kinds (drift, ...) show as stored. */
export function runKindLabel(kind: string): string {
  return kind === "pr" ? "PR" : kind;
}

export function stepLabel(step: string): string {
  const known = STEP_LABELS[step];
  if (known) return known;
  const m = /^([^/]+)\/(init|plan|apply)$/.exec(step);
  if (m) return `${cap(m[1])} ${cap(m[2])}`;
  return step;
}

// --- run outcome (header chip) ----------------------------------------------
export type Outcome = "succeeded" | "failed" | "running" | "queued" | "aborted" | "unknown";
/** Terrateam work_manifests only carry a lifecycle `state`
 *  (queued/running/completed/aborted); success/failure lives on the step rows.
 *  Fold the two into a single user-facing outcome. */
export function runOutcome(wmState: string, steps: RawStep[]): Outcome {
  if (wmState === "queued") return "queued";
  if (wmState === "running") return "running";
  if (wmState === "aborted") return "aborted";
  // A step that actually failed (not one marked ignore_errors) is a failure
  // whatever the lifecycle state says.
  if (steps.some(isActualFailure)) return "failed";
  if (wmState === "completed") return "succeeded";
  // A null column or a future engine value must not render a green chip.
  return "unknown";
}

/** Same folding as {@link runOutcome} for callers that hold the aggregated
 *  work_manifest_results.success of one dirspace instead of the step rows
 *  (null when no result row exists). The rule is the same: only an explicit
 *  failure or a completed lifecycle state decides; anything else is unknown. */
export function runOutcomeFromSuccess(wmState: string, success: boolean | null): Outcome {
  if (wmState === "queued") return "queued";
  if (wmState === "running") return "running";
  if (wmState === "aborted") return "aborted";
  if (success === false) return "failed";
  if (wmState === "completed") return "succeeded";
  return "unknown";
}

/** List-query variant of {@link runOutcome}: a run list fetches the failure
 *  count of each run (lib/wm/failCounts.ts) instead of the step rows, so the
 *  fold takes the failure count directly. The rule is that of
 *  {@link runOutcomeFromSuccess}: a failure decides, otherwise only a
 *  completed lifecycle state reads as success; anything else is unknown. */
export function runListOutcome(wmState: string, failCount: number): Outcome {
  return runOutcomeFromSuccess(wmState, failCount > 0 ? false : null);
}

/** Aggregate add/change/destroy across every dirspace plan in the run. */
export function totalCounts(groups: DirspaceGroup[]): Counts {
  return groups.reduce<Counts>(
    (acc, g) => (g.plan ? addCounts(acc, countsFor(g.plan.payload) ?? { add: 0, change: 0, destroy: 0 }) : acc),
    { add: 0, change: 0, destroy: 0 },
  );
}

// --- run summary (the PR comment's summary table) ---------------------------
/** The resource summary slots in the PR comment table's column order, each
 *  with the present-tense word it renders as (the data keys stay past tense:
 *  payload contract). */
export const RESOURCE_SUMMARY_SLOTS: ReadonlyArray<readonly [keyof ResourceSummary, string]> = [
  ["imported", "import"],
  ["created", "create"],
  ["updated", "update"],
  ["replaced", "replace"],
  ["deleted", "delete"],
];

export interface SummaryRow {
  dir: string;
  workspace: string;
  /** Null while the dirspace has no step output. */
  success: boolean | null;
  /** The engine operation the dirspace ran: apply wins over plan. */
  op: "plan" | "apply" | "other";
  hasChanges: boolean;
  resources: ResourceSummary | null;
}
export interface RunSummary {
  rows: SummaryRow[];
  /** Null when no dirspace reported a resource summary. */
  totals: ResourceSummary | null;
}

/** Failed rows first and rows without output last. */
const resultRank = (r: SummaryRow): number => (r.success === false ? 0 : r.success === null ? 2 : 1);

/** One row per dirspace of the run: every dirspace in `dirspaces` (the work
 *  manifest's list) and every dirspace with step output. Rows follow the PR
 *  comment summary table: failed first, then dirspaces with changes, then by
 *  dir and workspace; dirspaces without output come last. Totals follow the
 *  backend `Resource_summary.total`: an unreported slot adds 0, and every slot
 *  is null when no dirspace reported anything. */
export function runSummary(
  groups: DirspaceGroup[],
  dirspaces: ReadonlyArray<{ dir: string; workspace: string }> = [],
): RunSummary {
  const byKey = new Map<string, SummaryRow>();
  for (const d of dirspaces) {
    byKey.set(`${d.dir}|${d.workspace}`, {
      dir: d.dir,
      workspace: d.workspace,
      success: null,
      op: "other",
      hasChanges: false,
      resources: null,
    });
  }
  for (const g of groups) {
    byKey.set(`${g.dir}|${g.workspace}`, {
      dir: g.dir,
      workspace: g.workspace,
      success: !groupSteps(g).some(isActualFailure),
      op: g.apply ? "apply" : g.plan ? "plan" : "other",
      hasChanges: hasChanges(g.plan?.payload ?? null) ?? false,
      resources: resourceSummaryFor(g.plan?.payload ?? null),
    });
  }
  const rows = [...byKey.values()].sort(
    (a, b) =>
      resultRank(a) - resultRank(b) ||
      Number(b.hasChanges) - Number(a.hasChanges) ||
      a.dir.localeCompare(b.dir) ||
      a.workspace.localeCompare(b.workspace),
  );
  const reported = rows.map((r) => r.resources).filter((r): r is ResourceSummary => r !== null);
  const totals =
    reported.length === 0
      ? null
      : reported.reduce<ResourceSummary>(
          (acc, r) => ({
            imported: (acc.imported ?? 0) + (r.imported ?? 0),
            created: (acc.created ?? 0) + (r.created ?? 0),
            updated: (acc.updated ?? 0) + (r.updated ?? 0),
            replaced: (acc.replaced ?? 0) + (r.replaced ?? 0),
            deleted: (acc.deleted ?? 0) + (r.deleted ?? 0),
          }),
          { imported: 0, created: 0, updated: 0, replaced: 0, deleted: 0 },
        );
  return { rows, totals };
}

export type SummaryResult = "failed" | "pending" | "not run" | "applied" | "changes" | "no changes" | "success";

/** A row's result label. A dirspace without output is pending while the run
 *  is live and was not run otherwise. */
export function summaryResult(row: SummaryRow, live: boolean): SummaryResult {
  if (row.success === false) return "failed";
  if (row.success === null) return live ? "pending" : "not run";
  if (row.op === "apply") return "applied";
  if (row.op === "plan") return row.hasChanges ? "changes" : "no changes";
  return "success";
}

/** The counts line above the table, worded as in the PR comment:
 *  "N dirspaces · N with changes · N no changes · N failed" for a plan and
 *  "N dirspaces · N applied · N failed" for an apply. Dirspaces without output
 *  add "· N pending" (live) or "· N not run". */
export function summaryCountsLine({ rows }: RunSummary, isApply: boolean, live: boolean): string {
  const results = rows.map((r) => summaryResult(r, live));
  const count = (...rs: SummaryResult[]) => results.filter((r) => rs.includes(r)).length;
  const parts = [`${rows.length} dirspace${rows.length === 1 ? "" : "s"}`];
  if (isApply) parts.push(`${count("applied", "success")} applied`);
  else parts.push(`${count("changes")} with changes`, `${count("no changes", "success", "applied")} no changes`);
  parts.push(`${count("failed")} failed`);
  const waiting = count("pending", "not run");
  if (waiting > 0) parts.push(`${waiting} ${live ? "pending" : "not run"}`);
  return parts.join(" · ");
}

/** DOM id of a dirspace's section on the Changes, Apply and Steps tabs, so the
 *  summary table can scroll to it. */
export function dirspaceAnchor(dir: string, workspace: string): string {
  return `dirspace-${encodeURIComponent(dir)}:${encodeURIComponent(workspace)}`;
}

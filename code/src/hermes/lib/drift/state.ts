/**
 * Drift-state derivation shared by the Drift page, State Health, and the home
 * orchestration band — so "currently drifted" is ONE number everywhere.
 *
 * Input rows are per-dirspace drift steps (tf/plan checks and tf/apply
 * reconciles) read via MQL. A dirspace's current state comes from its LATEST
 * check: clean if it found no changes; if it found changes, a successful
 * reconcile apply AFTER that check means Terrateam already forced the cloud
 * back to the committed state ("reconciled" — pending the next check's
 * verification); otherwise the dirspace is drifted and awaiting action.
 */

import type { VcsProvider } from "@/lib/vcs/links";

export interface DriftRow {
  /** work manifest id of the run this step belongs to */
  id: string;
  provider: VcsProvider;
  repoOwner: string;
  repoName: string;
  environment: string;
  /** 'plan' = drift check, 'apply' = reconcile (legacy aliases 'autoplan',
   *  'autoapply' and 'unsafe-apply' are normalized) */
  runType: string;
  dir: string;
  workspace: string;
  /** tf/plan payload has_changes; irrelevant for applies */
  hasChanges: boolean;
  /** step success (applies: whether the reconcile succeeded) */
  success: boolean;
  createdAt: string; // ISO timestamp
}

export type DriftStatus = "clean" | "drifted" | "reconciled";

export interface DirspaceDrift {
  key: string; // owner/repo|dir|workspace
  provider: VcsProvider;
  repoOwner: string;
  repoName: string;
  environment: string;
  dir: string;
  workspace: string;
  status: DriftStatus;
  /** the latest check's run id (deep-link to its diff) */
  checkRunId: string;
  /** when the latest check ran */
  checkedAt: string;
  /** when drift was reconciled (only for status = reconciled) */
  reconciledAt?: string;
}

const ts = (iso: string): number => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : 0;
};

export function driftKey(r: { repoOwner: string; repoName: string; dir: string; workspace: string }): string {
  return `${r.repoOwner}/${r.repoName}|${r.dir}|${r.workspace}`;
}

/** run_type values that are drift checks / reconciles, including the legacy
 *  aliases the engine still stores (Terrat_work_manifest3.Step.of_string:
 *  autoplan is a plan; autoapply and unsafe-apply are applies). */
export const DRIFT_PLAN_RUN_TYPES: readonly string[] = ["plan", "autoplan"];
export const DRIFT_APPLY_RUN_TYPES: readonly string[] = ["apply", "autoapply", "unsafe-apply"];

export type DriftRunKind = "plan" | "apply" | "other";

/** Normalize a row's run_type to what it means for drift. Beyond the alias
 *  lists, explicit run types only: run_type has more values (index, build-*)
 *  and treating "not apply" as a check would silently misread them if a query
 *  ever widens — every reader must classify through this, never by comparing
 *  run_type to "apply" itself. */
export function driftRunKind(runType: string): DriftRunKind {
  if (DRIFT_APPLY_RUN_TYPES.includes(runType)) return "apply";
  if (DRIFT_PLAN_RUN_TYPES.includes(runType)) return "plan";
  return "other";
}

/** Fold raw drift rows (any order) into the per-dirspace current state. */
export function computeDriftStates(rows: DriftRow[]): DirspaceDrift[] {
  const latestCheck = new Map<string, DriftRow>();
  const latestReconcile = new Map<string, DriftRow>();
  for (const r of rows) {
    if (!r.dir) continue;
    const key = driftKey(r);
    const kind = driftRunKind(r.runType);
    if (kind === "apply") {
      const prev = latestReconcile.get(key);
      if (r.success && (!prev || ts(r.createdAt) > ts(prev.createdAt))) {
        latestReconcile.set(key, r);
      }
    } else if (kind === "plan") {
      const prev = latestCheck.get(key);
      if (!prev || ts(r.createdAt) > ts(prev.createdAt)) {
        latestCheck.set(key, r);
      }
    }
  }
  const out: DirspaceDrift[] = [];
  for (const [key, check] of latestCheck) {
    const recon = latestReconcile.get(key);
    let status: DriftStatus = "clean";
    let reconciledAt: string | undefined;
    if (check.hasChanges) {
      if (recon && ts(recon.createdAt) > ts(check.createdAt)) {
        status = "reconciled";
        reconciledAt = recon.createdAt;
      } else {
        status = "drifted";
      }
    }
    out.push({
      key,
      provider: check.provider,
      repoOwner: check.repoOwner,
      repoName: check.repoName,
      environment: check.environment,
      dir: check.dir,
      workspace: check.workspace,
      status,
      checkRunId: check.id,
      checkedAt: check.createdAt,
      reconciledAt,
    });
  }
  // Drifted first (most urgent), then reconciled, then clean; newest first within.
  const rank: Record<DriftStatus, number> = { drifted: 0, reconciled: 1, clean: 2 };
  out.sort((a, b) => rank[a.status] - rank[b.status] || ts(b.checkedAt) - ts(a.checkedAt));
  return out;
}

/** Render the small cron subset Terrateam schedules use as a human phrase.
 *  Falls back to the raw expression for anything fancier. Schedules are
 *  evaluated in UTC server-side, so the phrase says so — a bare "04:00"
 *  would be read as local time. */
const DOW = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
export function humanizeCron(cron: string): string {
  const parts = cron.trim().split(/\s+/);
  if (parts.length !== 5) return cron;
  const [min, hour, dom, month, dow] = parts;
  const two = (v: string) => v.padStart(2, "0");
  if (!/^\d+$/.test(min) || !/^\d+$/.test(hour)) return cron;
  const at = `${two(hour)}:${two(min)} UTC`;
  if (dom === "*" && month === "*" && dow === "*") return `Daily at ${at}`;
  if (dom === "*" && month === "*" && /^\d+$/.test(dow)) {
    const day = DOW[Number(dow) % 7];
    return `Weekly on ${day} at ${at}`;
  }
  return cron;
}

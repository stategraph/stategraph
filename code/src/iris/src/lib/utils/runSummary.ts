import type { OutputItem, ResourceSummary } from '../types/stepOutput';

export interface SummaryRow {
  dir: string;
  workspace: string;
  /** Undefined while the dirspace has no result yet. */
  success: boolean | undefined;
  hasChanges: boolean;
  resources: ResourceSummary | null;
}

export interface RunSummary {
  rows: SummaryRow[];
  /** Null when no dirspace reported a resource summary. */
  totals: ResourceSummary | null;
}

/** The resource summary slots in the PR comment table's column order, each
 *  with the column label it renders under. `imported` counts resources the
 *  plan imports, whatever their action. */
export const RESOURCE_SUMMARY_SLOTS: ReadonlyArray<readonly [keyof ResourceSummary, string]> = [
  ['imported', 'Import'],
  ['created', 'Create'],
  ['updated', 'Update'],
  ['replaced', 'Replace'],
  ['deleted', 'Delete'],
];

function reported(rs: ResourceSummary | null | undefined): rs is ResourceSummary {
  return rs != null && RESOURCE_SUMMARY_SLOTS.some(([slot]) => rs[slot] != null);
}

/** Failed rows first and rows without a result last. */
const resultRank = (r: SummaryRow): number => (r.success === false ? 0 : r.success === undefined ? 2 : 1);

/** One row per dirspace in the order of the PR comment summary table: failed
 *  first, then dirspaces with changes, then by dir and workspace; dirspaces
 *  without a result come last. Counts and `has_changes` come from the
 *  dirspace's plan step. Totals follow the backend `Resource_summary.total`:
 *  an unreported slot adds 0, and every slot is null when no dirspace
 *  reported anything. */
export function runSummary(
  dirspaces: Array<{ dir: string; workspace: string; success?: boolean }>,
  outputs: OutputItem[]
): RunSummary {
  const rows = dirspaces.map<SummaryRow>((d) => {
    const plan = outputs.find(
      (o) =>
        o?.scope?.dir === d.dir &&
        o?.scope?.workspace === d.workspace &&
        (o.step?.endsWith('/plan') ?? false)
    );
    const rs = plan?.payload?.resource_summary;
    return {
      dir: d.dir,
      workspace: d.workspace,
      success: d.success,
      hasChanges: plan?.payload?.has_changes === true,
      resources: reported(rs) ? rs : null,
    };
  });
  rows.sort(
    (a, b) =>
      resultRank(a) - resultRank(b) ||
      Number(b.hasChanges) - Number(a.hasChanges) ||
      a.dir.localeCompare(b.dir) ||
      a.workspace.localeCompare(b.workspace)
  );
  const withCounts = rows.map((r) => r.resources).filter(reported);
  const totals =
    withCounts.length === 0
      ? null
      : withCounts.reduce<ResourceSummary>(
          (acc, rs) => ({
            imported: (acc.imported ?? 0) + (rs.imported ?? 0),
            created: (acc.created ?? 0) + (rs.created ?? 0),
            updated: (acc.updated ?? 0) + (rs.updated ?? 0),
            replaced: (acc.replaced ?? 0) + (rs.replaced ?? 0),
            deleted: (acc.deleted ?? 0) + (rs.deleted ?? 0),
          }),
          { imported: 0, created: 0, updated: 0, replaced: 0, deleted: 0 }
        );
  return { rows, totals };
}

export type SummaryResult = 'Failed' | 'Pending' | 'Not run' | 'Applied' | 'Changes' | 'No changes';

/** A row's result label. A dirspace without a result is pending while the run
 *  is live and was not run otherwise. */
export function summaryResult(row: SummaryRow, isApply: boolean, live: boolean): SummaryResult {
  if (row.success === false) return 'Failed';
  if (row.success === undefined) return live ? 'Pending' : 'Not run';
  if (isApply) return 'Applied';
  return row.hasChanges ? 'Changes' : 'No changes';
}

/** The counts line above the table, worded as in the PR comment:
 *  "N dirspaces · N with changes · N no changes · N failed" for a plan and
 *  "N dirspaces · N applied · N failed" for an apply. Dirspaces without a
 *  result add "· N pending" (live) or "· N not run". */
export function summaryCountsLine({ rows }: RunSummary, isApply: boolean, live: boolean): string {
  const results = rows.map((r) => summaryResult(r, isApply, live));
  const count = (...rs: SummaryResult[]) => results.filter((r) => rs.includes(r)).length;
  const parts = [`${rows.length} dirspace${rows.length === 1 ? '' : 's'}`];
  if (isApply) parts.push(`${count('Applied')} applied`);
  else parts.push(`${count('Changes')} with changes`, `${count('No changes')} no changes`);
  parts.push(`${count('Failed')} failed`);
  const waiting = count('Pending', 'Not run');
  if (waiting > 0) parts.push(`${waiting} ${live ? 'pending' : 'not run'}`);
  return parts.join(' · ');
}

/** DOM id of a dirspace's section on the All Steps tab, so the summary table
 *  can scroll to it. */
export function dirspaceAnchor(dir: string, workspace: string): string {
  return `dirspace-${encodeURIComponent(dir)}:${encodeURIComponent(workspace)}`;
}

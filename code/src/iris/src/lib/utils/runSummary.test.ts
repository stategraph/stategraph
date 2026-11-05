import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { OutputItem } from '../types/stepOutput';
import { dirspaceAnchor, runSummary, summaryCountsLine, summaryResult } from './runSummary.ts';

const plan = (dir: string, payload: object): OutputItem =>
  ({ step: 'tf/plan', scope: { dir, workspace: 'default' }, payload }) as OutputItem;
const ds = (dir: string, success?: boolean) => ({ dir, workspace: 'default', success });

test('runSummary: failed first, then changes, then dirspace, no result last; totals over reported rows', () => {
  const { rows, totals } = runSummary(
    [ds('0'), ds('c', true), ds('b', true), ds('a', false)],
    [
      plan('b', { has_changes: true, resource_summary: { created: 2, updated: null } }),
      plan('c', { has_changes: false, resource_summary: {} }),
    ]
  );
  assert.deepEqual(rows.map((r) => r.dir), ['a', 'b', 'c', '0']);
  assert.deepEqual(rows[1].resources, { created: 2, updated: null });
  assert.equal(rows[2].resources, null);
  assert.deepEqual(totals, { imported: 0, created: 2, updated: 0, replaced: 0, deleted: 0 });
});

test('runSummary: an import count alone is a reported summary and totals with the rest', () => {
  const { rows, totals } = runSummary(
    [ds('a', true), ds('b', true)],
    [
      plan('a', { has_changes: true, resource_summary: { imported: 2 } }),
      plan('b', { has_changes: true, resource_summary: { imported: 1, updated: 1 } }),
    ]
  );
  assert.deepEqual(rows[0].resources, { imported: 2 });
  assert.deepEqual(totals, { imported: 3, created: 0, updated: 1, replaced: 0, deleted: 0 });
});

test('runSummary: totals are null when no dirspace reported a summary', () => {
  assert.deepEqual(runSummary([], []), { rows: [], totals: null });
});

test('summaryResult: labels per row, run type and liveness', () => {
  const row = { dir: 'a', workspace: 'default', success: true, hasChanges: false, resources: null };
  assert.equal(summaryResult({ ...row, success: false }, false, false), 'Failed');
  assert.equal(summaryResult({ ...row, success: undefined }, false, true), 'Pending');
  assert.equal(summaryResult({ ...row, success: undefined }, false, false), 'Not run');
  assert.equal(summaryResult(row, true, false), 'Applied');
  assert.equal(summaryResult({ ...row, hasChanges: true }, false, false), 'Changes');
  assert.equal(summaryResult(row, false, false), 'No changes');
});

test('summaryCountsLine: PR comment wording, waiting dirspaces appended', () => {
  const summary = runSummary(
    [ds('a', true), ds('b', true), ds('c', false), ds('d')],
    [plan('a', { has_changes: true }), plan('b', { has_changes: false })]
  );
  assert.equal(summaryCountsLine(summary, false, true), '4 dirspaces · 1 with changes · 1 no changes · 1 failed · 1 pending');
  assert.equal(summaryCountsLine(summary, false, false), '4 dirspaces · 1 with changes · 1 no changes · 1 failed · 1 not run');
  assert.equal(summaryCountsLine(runSummary([ds('a', true)], []), true, false), '1 dirspace · 1 applied · 0 failed');
});

test('dirspaceAnchor: distinct ids for distinct dirspaces', () => {
  assert.notEqual(dirspaceAnchor('a:b', 'c'), dirspaceAnchor('a', 'b:c'));
});

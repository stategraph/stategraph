<script lang="ts">
  import type { ResourceSummary } from '../../types/stepOutput';
  import {
    RESOURCE_SUMMARY_SLOTS,
    summaryCountsLine,
    summaryResult,
    type RunSummary,
    type SummaryResult,
    type SummaryRow,
  } from '../../utils/runSummary';

  // The run's summary table, as in the PR comment: a counts line, then one row
  // per dirspace. An apply run shows the result column only.

  export let summary: RunSummary;
  export let isApply: boolean;
  export let live: boolean;
  export let onOpen: (row: SummaryRow) => void;

  const resultClass: Record<SummaryResult, string> = {
    Failed: 'text-[var(--sg-error)] bg-[var(--sg-error-bg)]',
    Pending: 'text-[var(--sg-text-dim)] bg-[var(--sg-bg-2)]',
    'Not run': 'text-[var(--sg-text-dim)] bg-[var(--sg-bg-2)]',
    Applied: 'text-[var(--sg-success)] bg-[var(--sg-success-bg)]',
    Changes: 'text-[var(--sg-accent)] bg-[var(--sg-accent-bg)]',
    'No changes': 'text-[var(--sg-text-muted)] bg-[var(--sg-bg-2)]',
  };

  const slotClass: Record<keyof ResourceSummary, string> = {
    imported: 'text-[var(--sg-accent)]',
    created: 'text-[var(--sg-op-create)]',
    updated: 'text-[var(--sg-op-update)]',
    replaced: 'text-[var(--sg-op-update)]',
    deleted: 'text-[var(--sg-op-destroy)]',
  };
</script>

{#if summary.rows.length === 0}
  <div class="text-center py-8 text-[var(--sg-text-dim)]">No dirspaces in this run.</div>
{:else}
  <div class="space-y-3">
    <div class="text-sm font-semibold text-[var(--sg-text)]">{summaryCountsLine(summary, isApply, live)}</div>
    <div class="border border-[var(--sg-border)] rounded-lg overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-[var(--sg-bg-2)] text-xs text-[var(--sg-text-dim)]">
          <tr class="border-b border-[var(--sg-border)]">
            <th class="px-3 py-2 text-left font-medium">Directory</th>
            <th class="px-3 py-2 text-left font-medium">Workspace</th>
            <th class="px-3 py-2 text-left font-medium">Result</th>
            {#if !isApply}
              {#each RESOURCE_SUMMARY_SLOTS as [slot, label] (slot)}
                <th class="px-3 py-2 text-right font-medium">{label}</th>
              {/each}
            {/if}
          </tr>
        </thead>
        <tbody class="divide-y divide-[var(--sg-border)]">
          {#each summary.rows as row (`${row.dir}|${row.workspace}`)}
            {@const result = summaryResult(row, isApply, live)}
            <tr>
              <td class="px-3 py-2 font-mono text-xs text-[var(--sg-text)]">
                {#if row.success === undefined}
                  {row.dir}
                {:else}
                  <button
                    on:click={() => onOpen(row)}
                    class="text-left hover:text-[var(--sg-accent)] hover:underline"
                  >
                    {row.dir}
                  </button>
                {/if}
              </td>
              <td class="px-3 py-2 font-mono text-xs text-[var(--sg-text)]">{row.workspace}</td>
              <td class="px-3 py-2">
                <span class="inline-block px-2 py-0.5 rounded text-xs font-medium whitespace-nowrap {resultClass[result]}">{result}</span>
              </td>
              {#if !isApply}
                {#each RESOURCE_SUMMARY_SLOTS as [slot] (slot)}
                  {@const n = row.resources?.[slot] ?? null}
                  <td class="px-3 py-2 text-right font-mono {n ? slotClass[slot] : 'text-[var(--sg-text-dim)]'}">{n ?? '-'}</td>
                {/each}
              {/if}
            </tr>
          {/each}
        </tbody>
        {#if !isApply}
          <tfoot class="border-t border-[var(--sg-border)] bg-[var(--sg-bg-2)]">
            <tr>
              <td colspan="3" class="px-3 py-2 text-xs font-semibold text-[var(--sg-text)]">Total</td>
              {#each RESOURCE_SUMMARY_SLOTS as [slot] (slot)}
                {@const n = summary.totals?.[slot] ?? null}
                <td class="px-3 py-2 text-right font-mono font-semibold {n ? slotClass[slot] : 'text-[var(--sg-text-dim)]'}">{n ?? '-'}</td>
              {/each}
            </tr>
          </tfoot>
        {/if}
      </table>
    </div>
  </div>
{/if}

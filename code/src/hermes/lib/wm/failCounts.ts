import { sqlLiteral } from "@/lib/mql/escape";
import { asNumber, asText, executeWithRetry } from "@/lib/mql/providers";

/** Ids per fail-count query. executeMQL sends the query in the URL of a GET,
 *  and 100 quoted uuids keep that URL near 5 KB, well inside the 16 KiB a Node
 *  HTTP server accepts for the request line and headers. */
export const FAIL_COUNT_IDS_PER_QUERY = 100;

/** The failure count of each of `ids` (non-empty, at most
 *  {@link FAIL_COUNT_IDS_PER_QUERY}), one row per work manifest with a failure:
 *  `wm_id`, `fail_count`. It counts failed workflow_step_outputs rows -- the
 *  rows runOutcome (lib/wm/decode.ts) folds on the run page -- not work_manifest_results,
 *  which the engine writes for dirspace steps only: a failed checkout, env or
 *  run-scope hook leaves no failed result row, so a list reading that table
 *  would call a failed run succeeded. A failed step marked ignore_errors is not
 *  counted, as in isActualFailure.
 *
 *  A run list asks for its runs first and for their counts after, with the ids
 *  of the runs it got (#2287). A count joined into the list query aggregates
 *  the tenant's whole step history before the join, so the list's ORDER BY
 *  and LIMIT cannot reach the remote scan and every list reads every step row. */
export function failCountsQuery(ids: readonly string[]): string {
  return (
    "select wso.work_manifest as wm_id, count(*) as fail_count " +
    "from workflow_step_outputs as wso where wso.success = false and wso.ignore_errors = false " +
    `and wso.work_manifest in (${ids.map(sqlLiteral).join(", ")}) ` +
    `group by wso.work_manifest limit ${ids.length}`
  );
}

/** Failure count per work manifest id, for every distinct non-empty id in
 *  `ids`; a manifest with no failed step maps to 0. One query per
 *  {@link FAIL_COUNT_IDS_PER_QUERY} ids, all in parallel. `exec` is
 *  overridable for tests. */
export async function fetchFailCounts(
  ids: readonly string[],
  exec: (q: string) => Promise<unknown[]> = executeWithRetry,
): Promise<Map<string, number>> {
  const unique = [...new Set(ids.filter((id) => id !== ""))];
  const chunks: string[][] = [];
  for (let i = 0; i < unique.length; i += FAIL_COUNT_IDS_PER_QUERY) {
    chunks.push(unique.slice(i, i + FAIL_COUNT_IDS_PER_QUERY));
  }
  const results = await Promise.all(chunks.map((c) => exec(failCountsQuery(c))));
  const counts = new Map<string, number>(unique.map((id) => [id, 0]));
  for (const raw of results.flat()) {
    const o = raw as Record<string, unknown>;
    counts.set(asText(o.wm_id), asNumber(o.fail_count));
  }
  return counts;
}

/** `rows` (raw MQL rows carrying the work manifest in `id`) with `fail_count`
 *  set from {@link fetchFailCounts}, for the row mappers that read it. */
export async function withFailCounts(
  rows: readonly unknown[],
  exec: (q: string) => Promise<unknown[]> = executeWithRetry,
): Promise<unknown[]> {
  const id = (r: unknown) => asText((r as Record<string, unknown>).id);
  const counts = await fetchFailCounts(rows.map(id), exec);
  return rows.map((r) => ({ ...(r as Record<string, unknown>), fail_count: counts.get(id(r)) ?? 0 }));
}

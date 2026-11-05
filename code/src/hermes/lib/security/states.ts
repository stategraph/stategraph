/**
 * Which states currently have security findings.
 *
 * Like the per-state cost summary (see lib/cost/states.ts), this isn't scoped
 * onto the core state record -- the Findings page fetches just the signal it
 * needs via MQL: the set of states whose latest scan still reports findings.
 */

import { executeMQL } from "@/lib/api/client";

interface FindingStateRow {
  state_id?: unknown;
}

/**
 * State ids with at least one open security finding. A finding's
 * `resolved_scan_id` is set once a later scan stops reporting it, so
 * `resolved_scan_id is null` selects exactly the findings still present in a
 * state's current scan -- i.e. the states that will actually show findings
 * when picked. Returns a set keyed by `state_id`; states with none are absent.
 *
 * MQL requires an aggregate to accompany `group by`, hence the `count(*)`
 * (the count itself is unused -- we only need the grouped state ids).
 *
 * Explicit `limit 100` overrides MQL's default page size of 20: this fetches a
 * single page (we don't follow the Link-header pagination), so the limit must
 * cover every state that could have findings. 100 comfortably exceeds any
 * realistic tenant's state count while staying one round-trip.
 */
export async function fetchStateIdsWithFindings(): Promise<Set<string>> {
  const query = `select state_id, count(*) as n
    from security_scan_findings
    where resolved_scan_id is null
    group by state_id
    limit 100`;
  const result = await executeMQL(query);
  const out = new Set<string>();
  for (const raw of result.data as FindingStateRow[]) {
    if (typeof raw.state_id === "string") out.add(raw.state_id);
  }
  return out;
}

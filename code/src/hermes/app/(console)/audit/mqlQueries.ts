import { asNumber, asText, MQL_MAX_LIMIT } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";
import { runListOutcome, type Outcome } from "@/lib/wm/decode";

/** Per-provider cap (as many rows as the server will return in one query);
 *  the merged stream is at most 2x this. */
export const AUDIT_CAP = Math.min(1000, MQL_MAX_LIMIT);

const COLUMNS =
  "wm.id as id, wm.repo_owner as repo_owner, wm.repo_name as repo_name, wm.run_type as run_type, " +
  "wm.run_kind as run_kind, wm.state as state, wm.username as username, wm.branch as branch, " +
  "wm.pull_number as pull_number, wm.created_at as created_at, wm.completed_at as completed_at";

/** The catalog exposes identical-column github_/gitlab_ twins; the console
 *  queries both and merges client-side (MQL has no cross-table union).
 *  work_manifests only carry a lifecycle state, so the caller adds each row's
 *  `fail_count` from the run's step outputs (lib/wm/failCounts.ts) before
 *  {@link mapAuditRow}. */
export function auditQuery(provider: VcsProvider): string {
  return (
    `select ${COLUMNS} from ${provider}_work_manifests as wm ` +
    `order by wm.created_at desc limit ${AUDIT_CAP}`
  );
}

export interface AuditRow {
  provider: VcsProvider;
  id: string;
  /** Kept as separate fields (not a pre-joined "owner/name"): links and
   *  owner-level facets need them apart; display joins at the render site. */
  repoOwner: string;
  repoName: string;
  runType: string;
  runKind: string;
  state: string;
  failCount: number;
  /** What the run did, folded from state + failCount: the State column shows
   *  it, and the filter and exports use it so they agree with the column. */
  outcome: Outcome;
  username: string;
  branch: string;
  pullNumber: string;
  createdAt: string;
  completedAt: string;
}

export function mapAuditRow(provider: VcsProvider, raw: unknown): AuditRow {
  const o = raw as Record<string, unknown>;
  const state = asText(o.state);
  const failCount = asNumber(o.fail_count);
  return {
    provider,
    id: asText(o.id),
    repoOwner: asText(o.repo_owner),
    repoName: asText(o.repo_name),
    runType: asText(o.run_type),
    runKind: asText(o.run_kind),
    state,
    failCount,
    outcome: runListOutcome(state, failCount),
    username: asText(o.username),
    branch: asText(o.branch),
    pullNumber: asText(o.pull_number),
    createdAt: asText(o.created_at),
    completedAt: asText(o.completed_at),
  };
}

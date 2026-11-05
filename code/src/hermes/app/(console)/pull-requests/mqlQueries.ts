import { asText, MQL_MAX_LIMIT } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";

export const PRS_CAP = Math.min(500, MQL_MAX_LIMIT);

/** GitHub carries created_at, so it is projected (for client-side ordering)
 *  and orders the cap to mean "most recent"; gitlab_pull_requests has no such
 *  column and falls back to pull_number desc. */
export function pullRequestsQuery(provider: VcsProvider): string {
  const createdAt = provider === "github" ? "pr.created_at, " : "";
  const order = provider === "github" ? "pr.created_at desc" : "pr.pull_number desc";
  return (
    `select ${createdAt}pr.pull_number, pr.title, pr.branch, pr.base_branch, pr.state, pr.username, r.id as repo_id, r.owner, r.name ` +
    `from ${provider}_pull_requests as pr ` +
    `inner join ${provider}_installation_repositories as r on r.id = pr.repository ` +
    `order by ${order} limit ${PRS_CAP}`
  );
}

export interface PrRow {
  provider: VcsProvider;
  repoId: string;
  /** ISO timestamp; "" on GitLab, whose table has no created_at column. */
  createdAt: string;
  pullNumber: string;
  title: string;
  branch: string;
  baseBranch: string;
  state: string;
  username: string;
  owner: string;
  name: string;
}

export function mapPrRow(provider: VcsProvider, raw: unknown): PrRow {
  const o = raw as Record<string, unknown>;
  return {
    provider,
    repoId: asText(o.repo_id),
    createdAt: asText(o.created_at),
    pullNumber: asText(o.pull_number),
    title: asText(o.title),
    branch: asText(o.branch),
    baseBranch: asText(o.base_branch),
    state: asText(o.state),
    username: asText(o.username),
    owner: asText(o.owner),
    name: asText(o.name),
  };
}

/**
 * The Pull Requests tab defaults to open PRs. The URL param keeps three
 * shapes: absent/"" → the default (open); "all" → no state filter (explicit,
 * so it survives the URL round-trip — the param hook deletes empty values);
 * anything else → filter on that state verbatim.
 */
export function effectiveStatusFilter(param: string): string {
  if (param === "all") return "";
  return param || "open";
}

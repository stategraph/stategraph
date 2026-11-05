/**
 * Provider-discriminated VCS deep-link + Stategraph command helpers for the
 * read-only orchestration surface.
 *
 * The engine has no confirm/cancel API — plans, applies and unlocks are driven
 * by comments on the pull/merge request. The console stays read-only: it
 * surfaces run state, tells the user the exact comment to post, and links out
 * to the PR/MR where they post it. Nothing here writes to the VCS.
 *
 * Every URL builder takes the provider and threads an optional web base, so
 * GitHub Enterprise and self-managed GitLab work by passing the deployment's
 * base — no host is ever hardcoded at a call site. (The iris UI hardcoded
 * github.com/gitlab.com and GitHub-shaped paths in several screens; those bugs
 * stop here.)
 */

export type VcsProvider = "github" | "gitlab";

export const DEFAULT_VCS_BASES: Record<VcsProvider, string> = {
  github: "https://github.com",
  gitlab: "https://gitlab.com",
};

function trimSlash(s: string): string {
  return s.replace(/\/+$/, "");
}

/** Percent-encode a path, segment by segment, so `/` separators survive
 *  (subgroup owners, nested dirs, slash-branches). */
function encPath(s: string): string {
  return s.split("/").map(encodeURIComponent).join("/");
}

/** Web URL of a repository/project (owner may contain subgroups: `group/sub`).
 *  Returns null when owner or repo is missing — every builder below inherits
 *  this guard, so a row with incomplete VCS metadata yields "no link", never a
 *  malformed URL. */
export function projectUrl(
  provider: VcsProvider,
  owner: string,
  repo: string,
  base?: string,
): string | null {
  if (!owner || !repo) return null;
  return `${trimSlash(base ?? DEFAULT_VCS_BASES[provider])}/${encPath(owner)}/${encPath(repo)}`;
}

/** Web URL of a pull/merge request. Returns null when the number is missing. */
export function pullRequestUrl(
  provider: VcsProvider,
  owner: string,
  repo: string,
  pullNumber: string | number | null | undefined,
  base?: string,
): string | null {
  const pn = typeof pullNumber === "number" ? String(pullNumber) : (pullNumber ?? "").trim();
  const root = projectUrl(provider, owner, repo, base);
  if (!root || !pn) return null;
  return provider === "github" ? `${root}/pull/${pn}` : `${root}/-/merge_requests/${pn}`;
}

/** Web URL of a directory at a branch. */
export function treeUrl(
  provider: VcsProvider,
  owner: string,
  repo: string,
  branch: string,
  dir?: string,
  base?: string,
): string | null {
  const root = projectUrl(provider, owner, repo, base);
  if (!root || !branch) return null;
  const path = dir ? `/${encPath(dir)}` : "";
  return provider === "github"
    ? `${root}/tree/${encPath(branch)}${path}`
    : `${root}/-/tree/${encPath(branch)}${path}`;
}

/** Web URL of the CI run executing a work manifest, when the provider has a
 *  stable shape for it. GitHub: the Actions run. GitLab: null — the pipeline id
 *  is not the run_id the engine records, so there is no reliable deep link. */
export function ciRunUrl(
  provider: VcsProvider,
  owner: string,
  repo: string,
  runId: string | null | undefined,
  base?: string,
): string | null {
  const root = projectUrl(provider, owner, repo, base);
  if (provider !== "github" || !root || !runId) return null;
  return `${root}/actions/runs/${runId}`;
}

/** The provider's PR-number sigil: GitHub `#42`, GitLab `!42`. */
export function prSigil(provider: VcsProvider): string {
  return provider === "github" ? "#" : "!";
}

/** The provider's noun for a change request. */
export function prNoun(provider: VcsProvider): string {
  return provider === "github" ? "Pull Request" : "Merge Request";
}

/** The provider's display name. */
export function providerName(provider: VcsProvider): string {
  return provider === "github" ? "GitHub" : "GitLab";
}

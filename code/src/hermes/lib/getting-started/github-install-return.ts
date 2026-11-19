/* Where the console sends a browser that comes back from installing the GitHub App.

   GitHub returns to the App's callback only when an install completes, and the
   callback sends the browser to the GitHub wizard. A user who leaves GitHub any
   other way comes back to the console on their own, usually at the root: the
   pending marker set before leaving resumes the wizard for them. A callback
   without the install link's state signs the user in and lands on the console
   root with installation_id. */

const PENDING_KEY = "stategraph-github-install-pending";

/** How long after leaving for GitHub a return still counts as the same install. */
export const GITHUB_INSTALL_PENDING_TTL_MS = 30 * 60 * 1000;

/** The wizard path every install return resolves to. */
export const GITHUB_WIZARD_PATH = "/getting-started/";

export interface StoreLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

interface SearchParamsLike {
  get(name: string): string | null;
}

export interface GithubInstallPending {
  tenantId: string;
  startedAt: number;
}

function localStore(): StoreLike | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

/** Record that this browser is leaving for GitHub to install the App for [tenantId]. */
export function markGithubInstallPending(
  tenantId: string,
  now: number = Date.now(),
  store: StoreLike | null = localStore(),
): void {
  if (!store) return;
  try {
    store.setItem(PENDING_KEY, JSON.stringify({ tenantId, startedAt: now }));
  } catch {
    // Storage can be disabled or full. The callback's own redirect still works.
  }
}

/** The pending install, or null when there is none or it is older than the TTL. */
export function readGithubInstallPending(
  now: number = Date.now(),
  store: StoreLike | null = localStore(),
): GithubInstallPending | null {
  if (!store) return null;
  try {
    const raw = store.getItem(PENDING_KEY);
    if (!raw) return null;
    const value = JSON.parse(raw) as Partial<GithubInstallPending>;
    if (typeof value.tenantId !== "string" || typeof value.startedAt !== "number") return null;
    const age = now - value.startedAt;
    if (age < 0 || age > GITHUB_INSTALL_PENDING_TTL_MS) return null;
    return { tenantId: value.tenantId, startedAt: value.startedAt };
  } catch {
    return null;
  }
}

export function clearGithubInstallPending(store: StoreLike | null = localStore()): void {
  if (!store) return;
  try {
    store.removeItem(PENDING_KEY);
  } catch {
    // Storage can be disabled. Nothing to clear then.
  }
}

/** A GitHub installation id as GitHub sends it: a positive decimal integer. */
export function parseInstallationId(raw: string | null): string | null {
  return raw !== null && /^[1-9][0-9]{0,19}$/.test(raw) ? raw : null;
}

/**
 * The wizard URL for an install return, or null when [search] is not one and no
 * install is pending.
 *
 * - `installation_id` on the URL: the callback's sign-in redirect, so `installed`.
 * - No `installation_id`, a pending install: the user came back without GitHub
 *   reporting an install, so `returned`.
 */
export function githubInstallReturnHref(args: {
  search: SearchParamsLike;
  pending: GithubInstallPending | null;
}): string | null {
  const installationId = parseInstallationId(args.search.get("installation_id"));
  let result: "installed" | "returned";
  if (installationId !== null) {
    result = "installed";
  } else if (args.pending !== null) {
    result = "returned";
  } else {
    return null;
  }
  const params = new URLSearchParams({ path: "github", github_claim: result });
  if (installationId !== null) params.set("installation_id", installationId);
  const tenantId = args.pending?.tenantId;
  if (tenantId) params.set("tenant", tenantId);
  return `${GITHUB_WIZARD_PATH}?${params.toString()}`;
}

/* The create step of the GitHub connect wizard: whether the server offers it,
   where the wizard opens, and what the App creation callback appended to the
   return path. Pure, so the rules are testable without the page. */

export type GithubConnectStep = "create" | "install" | "link" | "done";

export const GITHUB_CONNECT_STEP_LABELS: Readonly<Record<GithubConnectStep, string>> = {
  create: "Create",
  install: "Install",
  link: "Link",
  done: "Done",
};

/**
 * The steps this server offers. A server that cannot create an App has no
 * Create step at all, rather than one that refuses.
 */
export function githubConnectSteps(creatable: boolean): readonly GithubConnectStep[] {
  return creatable ? ["create", "install", "link", "done"] : ["install", "link", "done"];
}

export type GithubAppResult = "created" | "expired" | "conflict" | "error";

/** The github_app query parameter the callback sends the console back with. */
export function githubAppResult(raw: string | null): GithubAppResult | null {
  return raw === "created" || raw === "expired" || raw === "conflict" || raw === "error"
    ? raw
    : null;
}

/** One sentence per result the operator must act on. "created" is a state, not a message. */
export const GITHUB_APP_RESULT_MESSAGE: Readonly<Record<Exclude<GithubAppResult, "created">, string>> = {
  expired: "The GitHub form took longer than an hour. Start again.",
  conflict: "Someone else stored a GitHub App at the same time. This one was not stored.",
  error: "GitHub did not return an App. Try again.",
};

/**
 * The install link for an App page. GitHub hands [state] to the App's install
 * callback, and the orchestration server's callback sends a request that carries
 * it back to this console instead of its own.
 */
export function githubInstallUrl(appUrl: string): string {
  return `${appUrl.replace(/\/+$/, "")}/installations/new?state=stategraph`;
}

/** GitHub limits an App name to 34 characters. */
export const GITHUB_APP_NAME_MAX = 34;

/**
 * A name to offer for a new App. GitHub requires a name no other App uses, so
 * a fixed one is taken as soon as one person creates it. The suffix is
 * lower-case hex, the charset GitHub keeps in a slug, so the slug reads the
 * same as the name.
 */
export function githubAppNameSuggestion(): string {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  const suffix = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `stategraph-${suffix}`;
}

/**
 * Send the browser to GitHub's App creation form. GitHub's manifest flow takes
 * a form post, not a fetch: the answer is a redirect to the callback carrying
 * the new App's code, so there is nothing to await.
 */
export function postGithubAppManifest(form: { action_url: string; manifest: string }): void {
  const el = document.createElement("form");
  el.method = "post";
  el.action = form.action_url;
  const manifest = document.createElement("input");
  manifest.type = "hidden";
  manifest.name = "manifest";
  manifest.value = form.manifest;
  el.appendChild(manifest);
  document.body.appendChild(el);
  el.submit();
}

/**
 * Which step the wizard shows, given what the server reports. A return from
 * the claim handshake lands on the link step. Otherwise: a server that cannot
 * create an App, or one whose engine already holds an App, starts at install;
 * an App that is stored but not yet loaded keeps the create step, which says
 * the engine is starting.
 */
export function githubConnectStep(args: {
  claimResult: string | null;
  creatable: boolean;
  ready: boolean;
}): GithubConnectStep {
  if (args.claimResult !== null) return "link";
  if (!args.creatable || args.ready) return "install";
  return "create";
}

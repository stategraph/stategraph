/* What the GitHub App settings panel says about the App the engine uses. Pure,
   so the copy and the rules are testable without the page. */

export type GithubAppSource = "environment" | "stored" | "none" | "unknown";

/** Whether the console shows the GitHub App panel at all. A hosted deployment brings its own App
 *  and manages it outside the console, so there is nothing of this server's to show. The server
 *  closes the same surface; this keeps an empty section from rendering before it answers. */
export function showGithubAppPanel(args: {
  instanceAdmin: boolean;
  mode: string | undefined;
}): boolean {
  return args.instanceAdmin && args.mode !== "COMMUNISM";
}

/** One sentence on where the App comes from, and what that means for this panel. */
export function githubAppSourceDescription(source: GithubAppSource): string {
  switch (source) {
    case "environment":
      return "This App comes from the server's environment, so it is managed where those values are set, not here.";
    case "stored":
      return "This App was created from the console. It is stored on the server and managed here.";
    case "none":
      return "This server has no GitHub App. Create one from Get Started, or set the GITHUB_* variables.";
    case "unknown":
      return "This server cannot read its own GitHub App, because it has no admin channel to the orchestration database. One may be in use. Set STATEGRAPH_FDW_PROVISIONER_PASSWORD to manage it here.";
  }
}

/** What the engine is doing with the App, for a one-line state. */
export function githubAppEngineState(loaded: boolean): string {
  return loaded
    ? "The orchestration engine is running this App."
    : "The orchestration engine is restarting on this App. It takes a few seconds.";
}

/** The confirmation for removing the App, which is not reversible. */
export function githubAppDeleteConfirmation(slug: string): string {
  return (
    `Remove ${slug}? Orchestration stops answering GitHub, and the copy of the App's private key is ` +
    "destroyed. GitHub never shows a key twice, so it cannot be restored here. The App and its " +
    "installations stay on GitHub, and their tenant links stay too."
  );
}

/** The warning above the replace action, which swaps the App for a new one. */
export const GITHUB_APP_REPLACE_WARNING =
  "Replacing creates a new App on GitHub and stores it in place of this one. You install the new " +
  "App yourself, and the installations of the old one stop being orchestrated.";

/** The warning above the credential rotation. */
export const GITHUB_APP_ROTATE_WARNING =
  "Rotate a credential on the App's GitHub page, then paste it here. GitHub shows each one time " +
  "only. Fill in what you rotated and leave the rest empty. The engine restarts on what you " +
  "store. A webhook that arrives during the restart is lost, and GitHub does not redeliver it.";

/** Whether the pasted text looks like a PEM private key. The server decides; this catches a paste
 *  that is plainly not one before a request is made. */
export function looksLikePem(text: string): boolean {
  const t = text.trim();
  return t.startsWith("-----BEGIN") && t.includes("PRIVATE KEY-----") && t.includes("-----END");
}

/** The credentials the operator typed, as the request carries them: a field they left empty is
 *  absent, so it keeps its stored value. */
export type GithubAppCredentialFields = {
  pem?: string;
  client_secret?: string;
  webhook_secret?: string;
};

export function githubAppCredentials(fields: {
  pem: string;
  clientSecret: string;
  webhookSecret: string;
}): GithubAppCredentialFields {
  const entries: Array<[keyof GithubAppCredentialFields, string]> = [
    ["pem", fields.pem],
    ["client_secret", fields.clientSecret],
    ["webhook_secret", fields.webhookSecret],
  ];
  return Object.fromEntries(entries.filter(([, value]) => value.trim() !== ""));
}

/** Why the rotation cannot be sent yet, or null when it can. The server decides both rules; these
 *  catch them before a request is made. */
export function githubAppCredentialsError(fields: GithubAppCredentialFields): string | null {
  if (Object.keys(fields).length === 0) {
    return "Paste the private key, the client secret or the webhook secret.";
  }
  if (fields.pem !== undefined && !looksLikePem(fields.pem)) {
    return "Paste the whole private key file that GitHub generated, in PEM form.";
  }
  return null;
}

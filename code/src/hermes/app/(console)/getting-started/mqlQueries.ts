/** Read a GitLab installation's state by its numeric group id, the primary
 *  key of the tenant-scoped gitlab_installations CTE. The id is validated
 *  here, not at the call site, so the builder can never interpolate anything
 *  but a bounded digit run; the query is parsed and compiled to parameterised
 *  pgsql server-side. */
export function gitlabInstallationStateQuery(groupId: string): string {
  if (!isValidGroupId(groupId)) throw new Error(`invalid GitLab group id: ${groupId}`);
  return `select state as state from gitlab_installations where id = ${groupId.trim()}`;
}

/** The group's installation map rows visible to the caller, with the installation state. MQL spans
 *  every tenant the user belongs to, so the caller intersects core_id with the current tenant's list. */
export function gitlabInstallationLinkQuery(groupId: string): string {
  if (!isValidGroupId(groupId)) throw new Error(`invalid GitLab group id: ${groupId}`);
  return (
    "select gim.core_id as core_id, gi.state as state " +
    "from gitlab_installations_map as gim " +
    "inner join gitlab_installations as gi on gi.id = gim.installation_id " +
    `where gim.installation_id = ${groupId.trim()}`
  );
}

/** What resuming a 409'd group can do: continue ("installed"), nothing working to continue from
 *  ("pending"), or nothing of this tenant's ("not-linked"). */
export function gitlabResumeOutcome(
  tenantCoreIds: readonly string[],
  rows: readonly unknown[],
): "installed" | "pending" | "not-linked" {
  const mine = rows
    .map((r) => r as { core_id?: unknown; state?: unknown })
    .find((r) => typeof r.core_id === "string" && tenantCoreIds.includes(r.core_id));
  if (!mine) return "not-linked";
  return mine.state === "installed" ? "installed" : "pending";
}

/** A GitLab group id the console will send to the provisioning endpoint: a
 *  positive integer bounded so it survives the JSON number / OCaml int round
 *  trip (an over-long digit run would serialise in exponential form). */
export function isValidGroupId(raw: string): boolean {
  return /^[1-9]\d{0,14}$/.test(raw.trim());
}

/** The base every wizard link is built from: the user-supplied GitLab URL
 *  parsed, restricted to http(s), and reduced to origin + path with no
 *  trailing slash, query or fragment -- or null when it is not such a URL.
 *  The path is kept because self-managed GitLab may be served under one. */
export function gitlabBaseUrl(raw: string): string | null {
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "http:" && u.protocol !== "https:") return null;
  return u.origin + u.pathname.replace(/\/+$/, "");
}

/** The GitLab deep links the connect wizard renders, built from the
 *  user-supplied base URL (self-managed GitLab support) with each path
 *  segment encoded — nested group paths keep their slashes. Empty group or
 *  project yields empty strings so callers can fall back to plain text. */
export function gitlabWizardLinks(
  base: string,
  group: string,
  project: string,
): {
  hooksUrl: string;
  cicdUrl: string;
  repoUrl: string;
  groupTokensUrl: string;
  projectTokensUrl: string;
  personalTokensUrl: string;
} {
  const seg = (v: string): string => v.split("/").map(encodeURIComponent).join("/");
  const projectPath = group && project ? `${seg(group)}/${seg(project)}` : "";
  return {
    hooksUrl: projectPath ? `${base}/${projectPath}/-/hooks` : "",
    cicdUrl: projectPath ? `${base}/${projectPath}/-/settings/ci_cd` : "",
    repoUrl: projectPath ? `${base}/${projectPath}` : "",
    groupTokensUrl: group ? `${base}/groups/${seg(group)}/-/settings/access_tokens` : "",
    projectTokensUrl: projectPath ? `${base}/${projectPath}/-/settings/access_tokens` : "",
    personalTokensUrl: `${base}/-/user_settings/personal_access_tokens`,
  };
}

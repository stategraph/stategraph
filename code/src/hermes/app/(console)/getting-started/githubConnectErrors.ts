/**
 * The sentences the GitHub connect wizard shows when listing or claiming an installation does not
 * end the way the operator meant it to. Kept next to the wizard, out of the component, so the
 * mapping can be tested without rendering anything: which failure gets a sentence of our own, and
 * which is better told in the server's words, is the part with a decision in it.
 */

/**
 * Both halves of the staff path -- listing the unclaimed installs and linking one to the tenant --
 * gate on the backend's Caps.admin_instance, so a refusal there is always the same missing grant.
 */
export const INSTANCE_ADMIN_REQUIRED =
  "Claiming a GitHub installation requires admin on this installation. Ask an instance admin to link it for you.";

/**
 * For a session that holds neither grant: a tenant admin can claim by verifying with GitHub, and an
 * instance admin can link any installation, so either one can finish the claim.
 */
export const TENANT_ADMIN_REQUIRED =
  "Claiming a GitHub installation for this tenant needs a tenant admin, who can verify with GitHub, or an instance admin.";

const SESSION_EXPIRED = "Your session expired. Signing you back in…";

/**
 * The kind of refusal a throw carries, for the two the wizard answers with a whole screen rather
 * than a line of text. Everything else, 401 included, is [null] and belongs in the error banner.
 */
export type GithubConnectRefusal = "capability" | "orchestration" | null;

/**
 * 503 is the server running without orchestration: the terrateam read FDW this path depends on was
 * never built, so no amount of retrying or re-installing helps. 403 is the capability gate, which
 * answers with no body, so "403 Forbidden" alone would not say which grant is missing.
 *
 * 401 is deliberately neither. It means only "no session" -- it is answered by the session
 * middleware before the endpoint runs -- so fetchAPI has already handed it to the re-authentication
 * handler. Reading it as a capability denial told the operator their grants were wrong when their
 * session had merely expired.
 */
export function githubConnectRefusal(err: unknown): GithubConnectRefusal {
  const status = (err as { status?: number } | null)?.status;
  if (status === 503) return "orchestration";
  if (status === 403) return "capability";
  return null;
}

/**
 * The message for a failed listing or claim, falling back to [fallback] when the throw carries
 * nothing to say. 401 gets a sentence because a re-authentication is already in flight and the raw
 * "API error: 401 Unauthorized" reads as a fault the operator has to act on.
 */
export function githubConnectErrorMessage(err: unknown, fallback: string): string {
  const status = (err as { status?: number } | null)?.status;
  if (status === 503)
    return "Orchestration is not enabled on this server, so GitHub installations cannot be claimed yet.";
  if (status === 403) return INSTANCE_ADMIN_REQUIRED;
  if (status === 401) return SESSION_EXPIRED;
  return err instanceof Error ? err.message : fallback;
}

/**
 * The kind of refusal a self-serve throw carries, for the two the wizard answers with something
 * other than a line of text: 503 is the server running without orchestration, and 412 is a proof
 * that is missing, expired, or minted for another user or tenant, so the handshake has to run again.
 */
export type GithubSelfServeRefusal = "orchestration" | "proof" | null;

export function githubSelfServeRefusal(err: unknown): GithubSelfServeRefusal {
  const status = (err as { status?: number } | null)?.status;
  if (status === 503) return "orchestration";
  if (status === 412) return "proof";
  return null;
}

/**
 * The message for a failed self-serve listing or claim, falling back to [fallback]. Their 403 is not
 * the instance-admin gate. A capability denial is the tenant-admin grant, and says so. Any other 403
 * is the endpoint's own refusal, such as tenant membership or an installation the proof does not
 * name, and its body's sentence is shown rather than fetchAPI's "API error: 403 Forbidden - ID: ...".
 */
export function githubSelfServeErrorMessage(err: unknown, fallback: string): string {
  const e = err as { status?: number; body?: { id?: string; data?: string } | null } | null;
  if (e?.status === 403) {
    if (e.body?.id === "CAPABILITY_UNAUTHORIZED")
      return "Claiming an installation needs admin on this tenant.";
    return e.body?.data ?? fallback;
  }
  if (e?.status === 401) return SESSION_EXPIRED;
  return fallback;
}

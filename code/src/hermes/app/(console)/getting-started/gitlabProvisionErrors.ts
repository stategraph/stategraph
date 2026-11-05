/**
 * The sentences the GitLab connect wizard shows when provisioning does not end the way the
 * operator meant it to. Kept next to the wizard's queries, out of the component, so the mapping
 * can be tested without rendering anything: which failure gets a sentence of our own and which
 * is better told in the server's words is the part with a decision in it.
 */

/**
 * The message for a failed GitLab provision, falling back to [fallback] when the throw carries
 * nothing to say.
 *
 * Three refusals get a sentence of their own. 409 is the one an operator hits when the group
 * already has an installation, and the raw "API error: 409 Conflict - GITLAB_ALREADY_PROVISIONED:
 * ..." that fetchAPI assembles hides the ways forward the wizard offers on this answer: rotating
 * the credentials, or skipping ahead when the webhook already works. 503 is the server running
 * without orchestration. 403 arrives with no body from the capability gate, so "403 Forbidden"
 * alone would not say that tenant admin is what is missing. A network fault
 * (fetch's TypeError) gets one too: the one-shot POST is never re-sent, so the operator cannot
 * tell whether the group was connected, and a resubmit that did land answers 409. Everything
 * else -- a 400 naming the bad field -- already reads as what went wrong.
 */
export function gitlabProvisionErrorMessage(err: unknown, fallback: string): string {
  const status = (err as { status?: number } | null)?.status;
  if (status === 409)
    return "This GitLab group already has an installation. If it belongs to this tenant you can rotate its credentials for a fresh webhook secret, or — if the webhook is already working — skip ahead to the remaining setup steps.";
  if (status === 503)
    return "Orchestration is not enabled on this server, so GitLab groups cannot be connected yet.";
  if (status === 403) return "Connecting a GitLab group requires admin on this tenant.";
  if (err instanceof TypeError)
    return "The request did not complete, so it is unknown whether the group was connected. If submitting again says the group already has an installation, rotate its credentials to get a new webhook secret.";
  return err instanceof Error ? err.message : fallback;
}

/**
 * The message for a failed GitLab credential rotation, falling back to [fallback] when the throw
 * carries nothing to say. Shared by the connect wizard's already-connected path and Settings →
 * Integrations, so both tell a refusal the same way.
 *
 * 404 arrives with an empty body and covers three cases the endpoint deliberately does not tell
 * apart: a group never provisioned, one linked to another tenant, and one linked to no tenant. 503
 * is the server running without orchestration. 403 is either capability or membership, since the
 * endpoint requires both. A network fault (fetch's TypeError) leaves the outcome unknown, and a
 * rotation that did land may already have invalidated the current secret. Everything else -- a
 * 400 naming what is missing -- already reads as what went wrong.
 */
export function gitlabRotateErrorMessage(err: unknown, fallback: string): string {
  const status = (err as { status?: number } | null)?.status;
  if (status === 404)
    return "This GitLab group is not connected to this tenant: it was never provisioned, or its installation is linked to another tenant or to none. Credentials can only be rotated from the tenant it is linked to.";
  if (status === 503)
    return "Orchestration is not enabled on this server, so GitLab credentials cannot be rotated.";
  if (status === 403)
    return "Rotating a GitLab group's credentials requires being an admin and a member of this tenant.";
  if (err instanceof TypeError)
    return "The request did not complete, so it is unknown whether the credentials were rotated. If a new webhook secret was requested, the current one may already have stopped working: rotate again to get a secret you can see.";
  return err instanceof Error ? err.message : fallback;
}

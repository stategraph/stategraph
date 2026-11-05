/**
 * The message for a failed unlink of a VCS installation from a tenant, falling back to [fallback]
 * when the throw carries nothing to say.
 *
 * 403 is either the capability (tenant admin) or membership, since the endpoint requires both.
 * 404 arrives with an empty body: the installation is not linked to this tenant, either already
 * removed (a retried DELETE whose first attempt landed answers this too) or moved elsewhere. A
 * network fault leaves the outcome unknown. Everything else -- a 400 naming the provider, a 500 --
 * reads as what went wrong in the server's words.
 */
export function vcsUnlinkErrorMessage(err: unknown, fallback: string): string {
  const status = (err as { status?: number } | null)?.status;
  if (status === 403)
    return "Removing an integration requires being an admin and a member of this tenant.";
  if (status === 404)
    return "This integration is no longer linked to this tenant: it was already removed or moved to another tenant.";
  if (err instanceof TypeError)
    return "The request did not complete, so it is unknown whether the integration was removed. Refresh the list to see.";
  return err instanceof Error ? err.message : fallback;
}

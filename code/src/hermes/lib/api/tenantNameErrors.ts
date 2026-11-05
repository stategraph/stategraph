/**
 * The sentences the console shows when naming a tenant does not end the way the operator meant it
 * to -- creating one in Settings > Preferences, renaming one in Settings > Members.
 *
 * Both flows put a name to the same uniqueness rule on the same column and read back the same
 * refusals, so they say the same things. Kept out of the pages and next to the client that throws
 * these errors, so the mapping can be tested without rendering anything: which failure gets a
 * sentence of our own and which is better told in the server's words is the part with a decision
 * in it.
 */

/**
 * The message for a failed tenant create or rename, falling back to [fallback] when the throw
 * carries nothing to say.
 *
 * 409 is the one failure the operator can act on, so it gets a sentence rather than the raw
 * "API error: 409 Conflict - TENANT_NAME_CONFLICT: ..." that fetchAPI assembles. Everything else --
 * the name rules behind a 400, a reserved name (#1786), a 403, a network fault -- already reads as
 * what went wrong, and the server's own words carry detail we would only lose.
 */
export function tenantNameErrorMessage(err: unknown, fallback: string): string {
  const status = (err as { status?: number } | null)?.status;
  if (status === 409) return "Another tenant already uses that name.";
  return err instanceof Error ? err.message : fallback;
}

/**
 * The message for a tenant that was created but did not come back in the refreshed list, so the
 * console has nothing to switch to. The create succeeded, so this must not read as a failure to
 * create -- the operator would try the same name again and be told it is taken.
 *
 * [name] is the name the server stored, which is the trimmed one, not what was typed.
 */
export function tenantCreatedButUnlistedMessage(name: string): string {
  return `"${name}" was created, but the tenant list could not be refreshed. Reload the page to switch to it.`;
}

/**
 * The message for a rename the server accepted whose refreshed list never arrived, leaving the old
 * name in the sidebar and the headers. Same shape as the create case and for the same reason: the
 * write landed, so this is a note about a stale screen, not a failure to rename.
 */
export function tenantRenamedButUnlistedMessage(name: string): string {
  return `Renamed to "${name}", but the tenant list could not be refreshed. Reload the page to see the new name everywhere.`;
}

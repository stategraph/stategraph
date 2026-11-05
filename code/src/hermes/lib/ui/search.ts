/**
 * Free-text search over a list row: true when `query` is blank, or when any of
 * `fields` contains it, case-insensitively. Surrounding whitespace is not part
 * of the needle, so a pasted "ci-deploy " still finds "ci-deploy".
 *
 * Each field is matched on its own. A caller that wants one query to span
 * several values -- `acme/infra #12` across a repository and a PR number --
 * joins them into a single field itself.
 */
export function matchesSearch(query: string, ...fields: string[]): boolean {
  const needle = query.trim().toLowerCase();
  return !needle || fields.some((field) => field.toLowerCase().includes(needle));
}

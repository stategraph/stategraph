/**
 * Escape a value for a single-quoted MQL/SQL string literal (single-quote
 * doubling — the same rule the engine and the OCaml side use).
 *
 * Every query builder that interpolates a user-supplied value (search text,
 * filter values, ids taken from the URL) MUST route it through this; bare
 * template interpolation into an MQL string is how injection happens.
 * Promoted out of contexts/mqlQueries.ts, which kept it private.
 */
export function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

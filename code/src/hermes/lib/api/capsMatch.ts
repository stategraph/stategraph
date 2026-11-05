/**
 * Frontend port of the read side of `code/src/sg_caps_match/sg_caps_match.ml`.
 *
 * Only the read side is needed, and only for the capability shapes that predate the decision-tree
 * model: what reaches the client now is a list of rules, read by `scopeReaches` in
 * `lib/api/capabilities.ts`. This module stays for the fixtures it shares with the backend's
 * `sg_caps_match`, which the migration still uses to read what was stored before.
 *
 * This is a *presentation* gate, never enforcement. Every mutation is authorized server-side and
 * answers 403 with a structured denial, so the worst a bug here can do is hide a button the user was
 * allowed to press, or show one whose request then fails. It cannot grant access.
 *
 * Drift is guarded by `caps-match-fixtures.json`, which this module's tests read and which is kept
 * byte-identical to `code/tests/sg_caps_match/caps-match-fixtures.json`, read by the OCaml suite: a
 * semantic change on either side fails CI on both.
 */

/**
 * An all-negation list carries an implicit leading `"*"` — `["!b"]` means "everything except b".
 *
 * The empty list is NOT such a case and must stay empty: it denies everything. In OCaml this falls
 * out of the match arm order (`[] -> []` precedes the all-negation guard); transcribed naively,
 * `every()` over an empty array is vacuously true and would turn deny-all into grant-all. That
 * inversion is the single most dangerous line in this file.
 */
function normalizeList(patterns: readonly string[]): readonly string[] {
  if (patterns.length === 0) return patterns;
  if (patterns.every((p) => p.startsWith("!"))) return ["*", ...patterns];
  return patterns;
}

/**
 * Mirror of `Sg_caps_match.glob_to_lua_pattern` + `glob_matches`: every `*` becomes `.*`, every other
 * regex metacharacter is escaped, and the result is anchored so the whole value must match.
 *
 * Note that this converts a `*` *anywhere*, not only a trailing one. The backend's `parse_glob` — the
 * stricter "literal prefix plus one trailing star" reading — gates `is_valid_pattern`, `subsumes` and
 * `intersects`, but `matches` does not consult it. So a malformed pattern like `a*b` is refused at the
 * input boundary by validation and can never be stored, yet if one were somehow present the matcher
 * would treat its `*` as a wildcard. This port follows the matcher, not the validator: diverging
 * "for safety" would defeat the shared fixtures whose job is to keep the two identical.
 *
 * Tenant ids are UUIDs, so escaping `-` is load-bearing rather than theoretical.
 */
function globMatches(glob: string, value: string): boolean {
  let out = "";
  for (const ch of glob) {
    if (ch === "*") out += ".*";
    else if ("\\^$.|?+()[]{}-".includes(ch)) out += `\\${ch}`;
    else out += ch;
  }
  return new RegExp(`^${out}$`).test(value);
}

/**
 * Whether `patterns` permits `value`: at least one positive matches and no negation does.
 *
 * Mirrors `Sg_caps_match.matches`.
 */
export function capsMatch(patterns: readonly string[], value: string): boolean {
  const normalized = normalizeList(patterns);
  const negations = normalized.filter((p) => p.startsWith("!"));
  const positives = normalized.filter((p) => !p.startsWith("!"));
  return (
    positives.some((p) => globMatches(p, value)) &&
    !negations.some((p) => globMatches(p.slice(1), value))
  );
}

/**
 * Whether `patterns` permits every possible value: a bare `"*"` positive and no negations.
 *
 * Mirrors `Sg_caps_match.grants_all`. This is what distinguishes an installation-wide grant from one
 * that merely happens to list every tenant the client can currently see.
 */
export function grantsAll(patterns: readonly string[]): boolean {
  const normalized = normalizeList(patterns);
  if (normalized.some((p) => p.startsWith("!"))) return false;
  return normalized.some((p) => p === "*");
}

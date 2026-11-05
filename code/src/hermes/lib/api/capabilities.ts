/**
 * Frontend mirror of the backend's `Sgs_session.Caps` helpers: read-only predicates for testing a
 * user's session capabilities.
 *
 * The capability shape is derived straight from the generated API types
 * (`capability-wire.json`), so it stays in sync with the backend and never duplicates the
 * schema. Use these predicates instead of poking at `capabilities.admin` (etc.) directly, so admin
 * status and other gates are expressed in one place.
 */
import type { paths } from "@/lib/api/types-generated";

type WhoAmIUser = NonNullable<
  paths["/api/v1/whoami"]["get"]["responses"]["200"]["content"]["application/json"]
>;

/** The resolved session capabilities carried on the current user (the whoami response). */
export type Capabilities = WhoAmIUser["capabilities"];

type MaybeCaps = Capabilities | null | undefined;

/**
 * One rule of a scope: a pattern that a leading `!` turns into a refusal, and a trailing `*` turns
 * into a prefix. Mirror of the backend's `Sg_caps_trie_scope.of_strings`.
 */
function ruleOf(text: string): { allow: boolean; prefix: boolean; pat: string } {
  const allow = !text.startsWith("!");
  const body = allow ? text : text.slice(1);
  const prefix = body.endsWith("*");
  return { allow, prefix, pat: prefix ? body.slice(0, -1) : body };
}

/**
 * Whether a scope reaches a string: the most specific rule that matches decides it — the longest
 * pattern, a literal before a prefix of the same length — and nothing reaches it when no rule
 * matches. Mirror of the backend's `Sg_caps_trie_scope.mem`.
 */
export function scopeReaches(rules: readonly string[], value: string): boolean {
  let best: { len: number; literal: boolean; allow: boolean } | undefined;
  for (const text of rules) {
    const rule = ruleOf(text);
    const matches = rule.prefix ? value.startsWith(rule.pat) : value === rule.pat;
    if (!matches) continue;
    const candidate = { len: rule.pat.length, literal: !rule.prefix, allow: rule.allow };
    const tie = best !== undefined && candidate.len === best.len && candidate.literal === best.literal;
    if (
      best === undefined ||
      candidate.len > best.len ||
      (candidate.len === best.len && candidate.literal && !best.literal) ||
      // A refusal wins a tie, as it does in Sg_caps_trie_scope.of_rules.
      (tie && !candidate.allow)
    ) {
      best = candidate;
    }
  }
  return best?.allow ?? false;
}

/**
 * Whether a scope reaches everything. The backend writes a scope in canonical form, so reaching
 * everything has exactly one spelling.
 */
export function scopeReachesEverything(rules: readonly string[]): boolean {
  return rules.length === 1 && rules[0] === "*";
}

/** Whether a scope reaches nothing at all, which is what an absent capability now looks like. */
export function scopeReachesNothing(rules: readonly string[]): boolean {
  return rules.length === 0 || (rules.length === 1 && rules[0] === "!*");
}

function scopeOf(caps: MaybeCaps, key: "admin" | "users-manage" | "sudo"): readonly string[] {
  return caps?.[key] ?? [];
}

function administersInstance(caps: MaybeCaps, key: "admin" | "users-manage"): boolean {
  return scopeReachesEverything(scopeOf(caps, key));
}

function administersTenant(
  caps: MaybeCaps,
  key: "admin" | "users-manage",
  tenantId: string | null | undefined,
): boolean {
  if (!tenantId) return false;
  return scopeReaches(scopeOf(caps, key), tenantId);
}

/** Whether an action grant reaches anything at all, along either axis. */
function actionReachesSomething(
  action: { modified: { states: { addresses: string[] }[] }[]; "pulled-in": { states: { addresses: string[] }[] }[] } | undefined,
): boolean {
  if (action === undefined) return false;
  return [...action.modified, ...action["pulled-in"]].some((tenant) =>
    tenant.states.some((state) => !scopeReachesNothing(state.addresses)),
  );
}

/**
 * True iff the session administers the whole installation — the backend's `Caps.admin_instance`.
 *
 * Use this to gate installation-wide surfaces (the Admin tab, the global user list). A user who only
 * administers their own tenant must not see them.
 */
export function isInstanceAdmin(caps: MaybeCaps): boolean {
  return administersInstance(caps, "admin");
}

/**
 * True iff the session administers `tenantId` — the backend's `Caps.admin_tenant`. An
 * installation-wide grant satisfies this too.
 *
 * Returns `false` for a null or undefined `tenantId`, so callers must distinguish "no tenant resolved
 * yet" (render a loading state) from "denied" (render the denial) rather than treating both as false.
 */
export function isTenantAdmin(caps: MaybeCaps, tenantId: string | null | undefined): boolean {
  return administersTenant(caps, "admin", tenantId);
}

/** True iff the session may manage users across the whole installation. */
export function canManageUsersInstance(caps: MaybeCaps): boolean {
  return administersInstance(caps, "users-manage");
}

/** True iff the session may manage the membership of `tenantId`. */
export function canManageUsersInTenant(
  caps: MaybeCaps,
  tenantId: string | null | undefined,
): boolean {
  return administersTenant(caps, "users-manage", tenantId);
}

/**
 * Which of `tenantIds` the session administers. Returns all of them when the grant is
 * installation-wide. Used to badge the tenant switcher.
 */
export function administeredTenantIds(
  caps: MaybeCaps,
  tenantIds: readonly string[],
): string[] {
  return tenantIds.filter((id) => isTenantAdmin(caps, id));
}

/** True iff the session may create access tokens. */
export function canCreateAccessToken(caps: MaybeCaps): boolean {
  return caps?.["access-token-create"] === true;
}

/** True iff the session may refresh access tokens. */
export function canRefreshAccessToken(caps: MaybeCaps): boolean {
  return caps?.["access-token-refresh"] === true;
}

/** True iff the session may preview something (whatever tenant, state or address). */
export function canPreview(caps: MaybeCaps): boolean {
  return actionReachesSomething(caps?.preview) || !scopeReachesNothing(scopeOf(caps, "admin"));
}

/** True iff the session may commit something (whatever tenant, state or address). */
export function canCommit(caps: MaybeCaps): boolean {
  return actionReachesSomething(caps?.commit) || !scopeReachesNothing(scopeOf(caps, "admin"));
}

/** True iff the session may manage the users of some tenant. */
export function canManageUsers(caps: MaybeCaps): boolean {
  return !scopeReachesNothing(scopeOf(caps, "users-manage"));
}

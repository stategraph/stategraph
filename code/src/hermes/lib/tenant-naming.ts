// First-run tenant naming (#1772). In COMMUNISM mode the OAuth callback
// auto-creates a personal tenant named after the user's display name or
// email (derive_personal_tenant_name in sgs_service_auth_ep_oauth2_callback.ml). The
// console prompts the user to replace that derived name on first entry;
// this module holds the detection, the name rule, the name suggestion, and
// the once-per-tenant marker that stops the prompt from nagging.

import { isTenantAdmin } from "@/lib/api/capabilities";
import type { SetupStatusResponse, Tenant, User } from "@/lib/api/client";

// Namespaced like every other key the console writes -- stategraph-theme,
// stategraph-tenant, stategraph-getting-started -- so one prefix finds all of
// them in a browser's storage inspector.
const SEEN_KEY_PREFIX = "stategraph-tenant-naming-seen:";

/** Mirrors the server's Sgs_tenant.max_name_length. The server remains the
 *  authority on the whole rule -- non-blank, length, uniqueness. */
export const MAX_TENANT_NAME = 255;

/**
 * The rule Sgs_tenant.valid_name applies: non-blank once trimmed, and no longer
 * than MAX_TENANT_NAME. A tenant name is the display label for a workspace, not
 * a slug, so it carries no character-class restriction -- "Acme Platform Team"
 * is a tenant name, and so is the derived personal name this prompt replaces.
 */
export function isValidTenantName(name: string): boolean {
  const trimmed = name.trim();
  return trimmed.length > 0 && trimmed.length <= MAX_TENANT_NAME;
}

/** The sentence stating that rule, shared by every surface that applies it so
 *  none of them can describe one bound while enforcing another. */
export const TENANT_NAME_RULE_MESSAGE = `A tenant name must not be blank and must be at most ${MAX_TENANT_NAME} characters.`;

/**
 * True iff `tenantName` still carries the server-derived personal name, i.e. it
 * equals the user's display name (trimmed, as the server trims it) or the user's
 * email. A rename through any path breaks the match and the prompt never returns.
 *
 * `user` is the whoami user the name was derived from, named as a slice of the
 * generated type rather than restated: `name` is required by the schema and
 * `email` is not, and the derivation depends on exactly that.
 */
function isDerivedPersonalName(
  tenantName: string,
  user: Pick<User, "name" | "email">,
): boolean {
  const display = user.name?.trim();
  if (display && tenantName === display) return true;
  if (user.email && tenantName === user.email) return true;
  return false;
}

// Lowercase and hyphen-joined: a suggestion short enough to accept without
// editing and unambiguous read aloud. An aesthetic choice about what to offer,
// not a constraint on what may be typed -- see isValidTenantName.
const ADJECTIVES = [
  "bold",
  "brisk",
  "calm",
  "clear",
  "crisp",
  "deft",
  "keen",
  "neat",
  "prime",
  "quick",
  "solid",
  "spry",
  "stark",
  "swift",
  "tidy",
  "vivid",
];

const NOUNS = [
  "basalt",
  "cedar",
  "comet",
  "delta",
  "ember",
  "falcon",
  "garnet",
  "harbor",
  "lumen",
  "mesa",
  "onyx",
  "orbit",
  "quartz",
  "ridge",
  "summit",
  "vector",
];

// Every suggestion carries a short random tail. Tenant names are globally
// unique -- update_tenant_name.sql refuses a name another tenant already holds --
// and communism mode is one shared substrate, so the 16x16 word pool on its own
// would start colliding at a few dozen tenants. That collision would land on the
// pre-filled default, which is the path most users take, and be reported as an
// error they have to resolve by guessing. Four base-36 characters put it out of
// reach, and stop a refusal from telling the user whether someone else holds the
// name they were offered.
const SUFFIX_ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789";
const SUFFIX_LENGTH = 4;

/**
 * A random tenant name suggestion: an adjective, a noun and a random tail.
 * `rand` is injectable for deterministic tests; defaults to Math.random.
 */
export function randomTenantName(rand: () => number = Math.random): string {
  const adjective = ADJECTIVES[Math.floor(rand() * ADJECTIVES.length)];
  const noun = NOUNS[Math.floor(rand() * NOUNS.length)];
  let suffix = "";
  for (let i = 0; i < SUFFIX_LENGTH; i++) {
    suffix += SUFFIX_ALPHABET[Math.floor(rand() * SUFFIX_ALPHABET.length)];
  }
  return `${adjective}-${noun}-${suffix}`;
}

// Mirrors Sgs_tenant.reserved_names, which arrives with #1786 (PR #1787) and is
// not on main yet -- this branch is only correct once that one lands, or ahead of
// it the console refuses names the server would accept while Settings > Members
// still accepts them. The server is the authority either way, and enforces the
// list only in communism mode, the only mode this prompt renders in.
const RESERVED_TENANT_NAMES = new Set([
  "stategraph",
  "terrateam",
  "admin",
  "administrator",
  "root",
  "support",
  "security",
  "billing",
]);

// The same characters Sgs_tenant.strip_invisible removes: NBSP, the zero-width
// space/non-joiner/joiner, the word joiner and the BOM. String.trim() strips none
// of them, so without this "ad<zwsp>min" reads as "admin" and compares as
// something else -- which is how a reserved name gets past the check while still
// displaying as the reserved one.
const INVISIBLE_CHARACTERS = /[\u00a0\u200b\u200c\u200d\u2060\ufeff]/g;

/**
 * Mirrors Sgs_tenant.is_reserved_name: exact match on the trimmed, lowercased
 * name with the invisible characters removed. Variants like "stategraph-hq"
 * deliberately pass.
 *
 * Only the comparison is mirrored, not the whole rule: #1786's `valid_name` also
 * refuses a name that carries invisible characters at all, which is the server's
 * to enforce.
 */
export function isReservedTenantName(name: string): boolean {
  return RESERVED_TENANT_NAMES.has(
    name.replace(INVISIBLE_CHARACTERS, "").trim().toLowerCase(),
  );
}

/* Reading localStorage throws outright when the browser is set to block site data, and this is
   read during render of a component mounted above the whole console. Treat an unreadable store as
   "not seen": the prompt appears, and it can still be dismissed for the session. */
function hasSeenTenantNaming(tenantId: string): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem(SEEN_KEY_PREFIX + tenantId) !== null;
  } catch {
    return false;
  }
}

export function markTenantNamingSeen(tenantId: string): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(SEEN_KEY_PREFIX + tenantId, "1");
  } catch {
    // Unavailable or full: the dismissal does not persist across reloads, which is preferable to
    // the dialog refusing to close.
  }
}

/**
 * Whether the first-run prompt should open. The whole decision in one place and
 * out of the component, so the part of this with judgement in it can be tested
 * without rendering anything.
 *
 * In order: the mode the prompt exists for; both fetches it reads having settled,
 * so it cannot flash an answer it does not have yet; a user and a tenant to act
 * on; exactly one tenant, since a second means the user has already moved past
 * their personal sandbox; the tenant admin capability the rename endpoint
 * requires, so the prompt never offers an action that would 403; the name still
 * being the derived one, which is what retires the prompt permanently after any
 * rename; and the per-tenant dismissal marker.
 */
export function shouldPromptForTenantName({
  mode,
  licenseLoading,
  tenantLoading,
  user,
  currentTenant,
  tenantCount,
}: {
  mode: SetupStatusResponse["mode"];
  licenseLoading: boolean;
  tenantLoading: boolean;
  user: Pick<User, "name" | "email" | "capabilities"> | null;
  currentTenant: Pick<Tenant, "id" | "name"> | null;
  tenantCount: number;
}): boolean {
  return (
    !licenseLoading &&
    !tenantLoading &&
    mode === "COMMUNISM" &&
    user !== null &&
    currentTenant !== null &&
    tenantCount === 1 &&
    isTenantAdmin(user.capabilities, currentTenant.id) &&
    isDerivedPersonalName(currentTenant.name, user) &&
    !hasSeenTenantNaming(currentTenant.id)
  );
}

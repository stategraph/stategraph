// Deployment-slug validation. Mirrors Aegis's `depSlugSchema` so the
// form rejects invalid input client-side before round-tripping to the
// server. Aegis is still the authority on uniqueness and the
// reserved-name blocklist; this is a UX shortcut, not a security
// control.

export const DEDICATED_SLUG_REGEX = /^[a-z](?:[a-z0-9-]*[a-z0-9])?$/;
export const DEDICATED_SLUG_MAX = 14;

export function isValidDedicatedSlug(s: string): boolean {
  if (s.length === 0 || s.length > DEDICATED_SLUG_MAX) return false;
  return DEDICATED_SLUG_REGEX.test(s);
}

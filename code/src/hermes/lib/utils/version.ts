/**
 * Version comparison utilities for semver-like versions.
 * Handles versions like: 1.0.0, v1.0.0, 1.0.0-rc1, 1.0.0-beta.2
 */

interface ParsedVersion {
  major: number;
  minor: number;
  patch: number;
  prerelease: string | null;
}

/**
 * Parse a version string into its components.
 * Handles versions with optional 'v' prefix and prerelease suffixes.
 */
export function parseVersion(version: string): ParsedVersion | null {
  // Remove leading 'v' if present
  const normalized = version.replace(/^v/, '');

  // Match semver pattern: major.minor.patch[-prerelease]
  const match = normalized.match(/^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$/);
  if (!match) return null;

  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
    prerelease: match[4] || null,
  };
}

/**
 * Compare two prerelease strings.
 * Returns: -1 if a < b, 0 if equal, 1 if a > b
 *
 * Rules:
 * - A version without prerelease has higher precedence
 * - Prerelease versions are compared lexically
 */
function comparePrereleases(a: string | null, b: string | null): number {
  // No prerelease beats prerelease (1.0.0 > 1.0.0-rc1)
  if (!a && !b) return 0;
  if (!a) return 1;
  if (!b) return -1;

  // Compare prerelease strings lexically
  return a.localeCompare(b);
}

/**
 * Compare two version strings.
 * Returns: -1 if a < b, 0 if equal, 1 if a > b
 *
 * Returns null if either version is invalid.
 */
export function compareVersions(a: string, b: string): number | null {
  const parsedA = parseVersion(a);
  const parsedB = parseVersion(b);

  if (!parsedA || !parsedB) return null;

  // Compare major
  if (parsedA.major !== parsedB.major) {
    return parsedA.major > parsedB.major ? 1 : -1;
  }

  // Compare minor
  if (parsedA.minor !== parsedB.minor) {
    return parsedA.minor > parsedB.minor ? 1 : -1;
  }

  // Compare patch
  if (parsedA.patch !== parsedB.patch) {
    return parsedA.patch > parsedB.patch ? 1 : -1;
  }

  // Compare prerelease
  return comparePrereleases(parsedA.prerelease, parsedB.prerelease);
}

/**
 * Check if version `current` is older than version `latest`.
 * Returns false for non-semver versions (like "dev").
 */
export function isVersionOlder(current: string, latest: string): boolean {
  const result = compareVersions(current, latest);
  return result !== null && result < 0;
}

/**
 * Check if a version string is a valid semver version.
 */
export function isValidSemver(version: string): boolean {
  return parseVersion(version) !== null;
}

import type { AccessTokenSummary } from "@/lib/api/client";
import { matchesSearch } from "@/lib/ui/search";

/**
 * Keeps the keys whose name or owner's name matches `search` (see
 * `matchesSearch`) -- the API Keys tab's client-side counterpart of the
 * `search` parameter `/api/v1/users` documents ("Case-insensitive substring
 * match against a user's name or email").
 *
 * Filtering the fetched list client-side is complete: `GET
 * /api/v1/user/access-tokens` has no pagination at all -- its response schema
 * is a bare `tokens` array -- so every key the viewer may see is already in
 * memory and nothing can hide on an un-fetched page.
 */
export function filterApiKeys(
  tokens: readonly AccessTokenSummary[],
  search: string,
): AccessTokenSummary[] {
  return tokens.filter((token) => matchesSearch(search, token.name, token.owner_name));
}

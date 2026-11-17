// A sign-up hint: stategraph.com's Start links add `signup=1`, so the sign-in opens the identity
// provider on its sign-up screen instead of its login form.

/**
 * Whether the login page should ask the identity provider for its sign-up screen: `signup=1` on
 * the login page itself, or on the page it returns to (`next`), where AuthProvider carries the
 * original query.
 */
export function signupRequested(params: URLSearchParams): boolean {
  if (params.get("signup") === "1") return true;
  const next = params.get("next");
  const query = next?.indexOf("?") ?? -1;
  if (!next || query === -1) return false;
  return new URLSearchParams(next.slice(query + 1)).get("signup") === "1";
}

/** The backend start URL with the sign-up hint, which the backend passes to the provider. */
export function withSignupHint(startUrl: string): string {
  return `${startUrl}&screen_hint=signup`;
}

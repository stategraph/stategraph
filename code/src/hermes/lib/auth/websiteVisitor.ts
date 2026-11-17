// stategraph.com adds its PostHog id (`ph_did`) to its links to the console. AuthProvider reads it
// on the page the user lands on after signing in, so a link straight to /login must carry it into
// the return path.

/**
 * The return path `next` with the login page's `ph_did`. `next` is a same-origin path; an id it
 * already carries wins.
 */
export function withWebsiteVisitor(next: string, params: URLSearchParams): string {
  const distinctId = params.get("ph_did");
  if (!distinctId) return next;
  const base = "https://stategraph.invalid";
  const url = new URL(next, base);
  if (url.searchParams.has("ph_did")) return next;
  url.searchParams.set("ph_did", distinctId);
  return url.pathname + url.search + url.hash;
}

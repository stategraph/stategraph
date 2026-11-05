/* What the GitHub App panel says when the server refuses. Its endpoints share
   two statuses with the installation-claim flow and mean something else by
   them, so their copy is not reused. */

type ApiError = { status?: number; body?: { id?: string; data?: string } };

/** The server's own sentence when it sent one, else a status-specific fallback. Every 4xx and 5xx
 *  these endpoints raise themselves carries one, so the fallbacks are for the gates in front of
 *  them. */
export function githubAppErrorMessage(e: unknown, fallback: string): string {
  const err = e as ApiError | null;
  const data = err?.body?.data;
  if (typeof data === "string" && data.length > 0) return data;
  switch (err?.status) {
    case 401:
      return "Your session has expired. Sign in again.";
    case 403:
      return "Managing the GitHub App needs an instance admin.";
    case 404:
      return "This server has no stored GitHub App. Reload the page.";
    default:
      return fallback;
  }
}

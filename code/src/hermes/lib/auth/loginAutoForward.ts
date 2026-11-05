// Login auto-forward (#1774): when a generic OIDC broker is the only way in, the login page sends
// the browser straight to it instead of showing one redundant button in front of its login screen.

/** Per-tab: sessionStorage key holding the time of the last automatic forward. */
const AUTO_FORWARD_KEY = "sg-login-auto-forwarded";

/** A redirect loop resolves within seconds, so the guard only has to cover that window. */
const AUTO_FORWARD_COOLDOWN_MS = 30_000;

/**
 * Whether the login page forwards to the provider: only when the sole provider is a generic "oidc"
 * broker (Auth0, Okta, Keycloak, ...), which brings its own login screen. Raw social OAuth
 * ("google") keeps the button: being dropped into an account chooser with no context reads as
 * phishing. No providers means local auth.
 *
 * `promptRequested` (`?prompt=1`, which logout lands with) holds the forward back: the IdP session
 * usually outlives ours, so forwarding would undo the logout.
 */
export function shouldAutoForward(input: {
  providers: ReadonlyArray<{ name: string }>;
  promptRequested: boolean;
}): boolean {
  return (
    !input.promptRequested && input.providers.length === 1 && input.providers[0].name === "oidc"
  );
}

/* True when this tab forwarded within the cooldown, i.e. the forward failed and came back
   unauthenticated: the page must then show, or the error is unreachable. The guard is time-boxed,
   so a session that expires later in the same tab still re-authenticates without the interstitial.
   Reading sessionStorage throws when the browser blocks site data; the answer is then "not
   recently", so the page still renders rather than crashing. */
export function recentlyAutoForwarded(now: number): boolean {
  if (typeof window === "undefined") return false;
  try {
    const last = Number(window.sessionStorage.getItem(AUTO_FORWARD_KEY));
    return Number.isFinite(last) && last > 0 && now - last < AUTO_FORWARD_COOLDOWN_MS;
  } catch {
    return false;
  }
}

export function markAutoForwarded(now: number): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.setItem(AUTO_FORWARD_KEY, String(now));
  } catch {
    // Without storage the guard cannot arm; the `prompt=1` on logout is what stops a logout from
    // bouncing back.
  }
}

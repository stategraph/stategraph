/**
 * The message for a failed OAuth sign-in. The callback sends the browser back to the login page
 * with `error` (`idp`, `expired` or `denied`) and, for `idp`, the provider's `reason`. Any other
 * value shows nothing.
 */
export function loginErrorMessage(error: string | null, reason: string | null): string | null {
  switch (error) {
    case "idp":
      return reason
        ? `Sign-in failed. Your identity provider returned: ${reason}`
        : "Sign-in failed. Your identity provider returned an error.";
    case "expired":
      return "Sign-in expired. Try again.";
    case "denied":
      return "This account is not allowed to sign in.";
    default:
      return null;
  }
}

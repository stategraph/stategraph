"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  checkAuth,
  getApiBase,
  getSetupStatus,
  loginWithPassword,
  initializeAuth,
} from "@/lib/api/client";
import {
  markAutoForwarded,
  recentlyAutoForwarded,
  shouldAutoForward,
} from "@/lib/auth/loginAutoForward";
import { loginErrorMessage } from "@/lib/auth/loginError";

interface LoginOption {
  name: string;
  display_name: string;
  url: string;
}

interface LoginOptionsResponse {
  options: LoginOption[];
}

function LoginContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [providers, setProviders] = useState<LoginOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [mode, setMode] = useState<string | null>(null);

  // Local auth state
  const [isLocalAuth, setIsLocalAuth] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState<string | null>(null);
  const [loggingIn, setLoggingIn] = useState(false);
  const signInError = loginErrorMessage(searchParams.get("error"), searchParams.get("reason"));

  // Check if registration needed, then check if already authenticated
  useEffect(() => {
    async function check() {
      // Skip setup check if user just completed registration
      const justRegistered = searchParams.get("registered") === "1";

      // First check if initial registration is needed (unless just registered)
      if (!justRegistered) {
        try {
          const status = await getSetupStatus();
          setMode(status.mode ?? null);
          if (status.needs_setup && status.mode !== "COMMUNISM") {
            router.push("/register");
            return;
          }
        } catch (err) {
          // If setup check fails, continue with normal login flow
          console.warn("Setup status check failed:", err);
        }
      }

      // Then check if already authenticated
      const user = await checkAuth();
      if (user) {
        router.push(safeNext(searchParams.get("next")));
      } else {
        setCheckingAuth(false);
      }
    }
    check();
  }, [router, searchParams]);

  // Fetch OAuth providers
  useEffect(() => {
    async function fetchProviders() {
      try {
        const response = await fetch(`${getApiBase()}/api/v1/login/options`, {
          credentials: "include",
        });
        const data: LoginOptionsResponse = await response.json();
        setProviders(data.options || []);
        // If no providers, we're in local auth mode
        setIsLocalAuth(data.options.length === 0);
      } catch (error) {
        console.error("Failed to fetch providers:", error);
      } finally {
        setLoading(false);
      }
    }
    if (!checkingAuth) {
      fetchProviders();
    }
  }, [checkingAuth]);

  const handleLogin = useCallback((providerUrl: string) => {
    const apiBase = getApiBase();
    // In development, use full origin (frontend on :3000, backend on :8080)
    // In production, use relative path to avoid port number issues with reverse proxies
    const next = safeNext(searchParams.get("next"));
    const redirectPath = process.env.NODE_ENV === 'development'
      ? window.location.origin + next
      : next;
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- backend endpoint, not a Next.js page: full-page navigation is required
    window.location.href = `${apiBase}${providerUrl}?rd=${encodeURIComponent(redirectPath)}`;
  }, [searchParams]);

  // Auto-forward straight to the identity provider (#1774). The loop guard is read once per mount:
  // the effect arms it just before navigating, and a later render must not re-read it and flash the
  // page while the browser leaves. Session-expiry redirects from AuthProvider carry no `prompt=1`,
  // so an expired console re-authenticates without the interstitial.
  const [forwardedRecently] = useState(() => recentlyAutoForwarded(Date.now()));
  const autoForwardUrl =
    !loading &&
    !forwardedRecently &&
    shouldAutoForward({ providers, promptRequested: searchParams.get("prompt") === "1" })
      ? providers[0].url
      : null;
  useEffect(() => {
    if (autoForwardUrl === null) return;
    markAutoForwarded(Date.now());
    handleLogin(autoForwardUrl);
  }, [autoForwardUrl, handleLogin]);

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError(null);
    setLoggingIn(true);

    try {
      const result = await loginWithPassword(email, password);

      // Set session cookie
      await initializeAuth(result.session_token);

      // Verify and redirect
      const user = await checkAuth();
      if (user) {
        router.push(safeNext(searchParams.get("next")));
      } else {
        throw new Error("Login failed");
      }
    } catch (err) {
      setLoginError(
        err instanceof Error ? err.message : "Invalid email or password"
      );
    } finally {
      setLoggingIn(false);
    }
  };

  if (checkingAuth) {
    return <LoadingState message="Checking authentication..." />;
  }

  if (autoForwardUrl !== null) {
    return <LoadingState message="Redirecting to sign-in..." />;
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-[var(--sg-bg-0)]">
      <div className="max-w-md w-full px-8">
        {/* Logo/branding */}
        <div className="text-center mb-8">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_white.svg"
            alt="Stategraph"
            className="h-10 mx-auto mb-6 hidden dark:block"
          />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_blue.svg"
            alt="Stategraph"
            className="h-10 mx-auto mb-6 dark:hidden"
          />
          <h1 className="text-3xl font-bold text-[var(--sg-text)]">
            Welcome to Stategraph
          </h1>
          <p className="text-[var(--sg-text-muted)] mt-2">
            Terraform state management and visualization
          </p>
        </div>

        {signInError && (
          <p className="mb-4 text-sm text-red-500 text-center">{signInError}</p>
        )}

        {/* Login options */}
        <div className="space-y-4">
          {loading ? (
            <LoadingState message="Loading login options..." />
          ) : isLocalAuth ? (
            // Local auth mode: show email/password form
            <form onSubmit={handlePasswordLogin} className="space-y-4">
              <div className="space-y-2">
                <label
                  htmlFor="email"
                  className="block text-sm font-medium text-[var(--sg-text)]"
                >
                  Email
                </label>
                <Input
                  id="email"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                />
              </div>
              <div className="space-y-2">
                <label
                  htmlFor="password"
                  className="block text-sm font-medium text-[var(--sg-text)]"
                >
                  Password
                </label>
                <Input
                  id="password"
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter your password"
                />
              </div>
              {loginError && (
                <p className="text-sm text-red-500 text-center">{loginError}</p>
              )}
              <Button
                type="submit"
                variant="default"
                size="lg"
                className="w-full"
                disabled={loggingIn || !email || !password}
              >
                {loggingIn ? "Signing in..." : "Sign In"}
              </Button>
            </form>
          ) : (
            // OAuth mode: show provider buttons
            providers.map((provider) => (
              <Button
                key={provider.name}
                variant="default"
                size="lg"
                className="w-full"
                onClick={() => handleLogin(provider.url)}
              >
                Sign in with {provider.display_name}
              </Button>
            ))
          )}
        </div>

        {mode === "COMMUNISM" && (
          <div className="mt-8 pt-6 border-t border-[var(--sg-border)] text-center text-sm text-[var(--sg-text-muted)]">
            <a
              href="https://stategraph.com/docs/deployment"
              target="_blank"
              rel="noopener noreferrer"
              className="text-[var(--sg-accent)] hover:underline"
            >
              Self-hosted instead?
            </a>
            <span className="mx-3 opacity-50">·</span>
            <a
              href="https://stategraph.com/demo"
              target="_blank"
              rel="noopener noreferrer"
              className="text-[var(--sg-accent)] hover:underline"
            >
              Book a demo
            </a>
          </div>
        )}
      </div>
    </div>
  );
}

function LoadingState({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center">
      <p className="text-[var(--sg-text-muted)]">{message}</p>
    </div>
  );
}

/**
 * Where to land after signing in.
 *
 * `AuthProvider` has always written `?next=` when it bounces an unauthenticated user here, but
 * nothing read it — all three paths below hardcoded "/". That silently discarded the destination,
 * which the invite flow depends on.
 *
 * Only same-origin paths are honoured. We resolve `next` against a throwaway origin and keep it
 * only if it stays on that origin. A plain prefix check (`startsWith("//")`) is not enough: the
 * WHATWG URL parser folds backslashes to slashes for special schemes, so `/\host` and `/\/host`
 * become protocol-relative `//host`, and control characters the browser later strips (`/⇥/host`)
 * splice the same way — every off-origin shape collapses to a foreign origin here and is rejected.
 * This matters because the value becomes the `rd` the backend copies verbatim into a `Location`
 * header (sgs_service_auth_ep_oauth2_callback.ml), so this guard is the only thing between `?next=` and an open
 * redirect.
 */
function safeNext(next: string | null): string {
  if (!next) return "/";
  const base = "https://stategraph.invalid";
  try {
    const url = new URL(next, base);
    if (url.origin !== base) return "/";
    return url.pathname + url.search + url.hash;
  } catch {
    return "/";
  }
}

export default function LoginPage() {
  return (
    <Suspense fallback={<LoadingState message="Loading..." />}>
      <LoginContent />
    </Suspense>
  );
}

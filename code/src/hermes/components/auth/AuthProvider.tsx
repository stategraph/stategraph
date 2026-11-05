"use client";

import { createContext, useContext, useEffect, useRef, useState, ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { checkAuth, initializeAuth, getSetupStatus, setSessionExpiredHandler } from '@/lib/api/client';
import { identifyUser, pushSignupEvent } from '@/lib/analytics';
import { BootstrapLoader } from '@/components/layout/bootstrap-loader';
import type { paths } from '@/lib/api/types-generated';

type WhoAmIResponse = paths['/api/v1/whoami']['get']['responses']['200']['content']['application/json'];

interface AuthContextValue {
  isLoading: boolean;
  isAuthenticated: boolean;
  error: string | null;
  user: WhoAmIResponse | null;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

// In hosted (COMMUNISM) mode a sign-up and a login are the same OAuth action,
// so the backend OAuth callback tags the post-registration redirect with
// `?sg_signup=1` when (and only when) it just created the account. Read that
// marker once and strip it from the URL immediately, so a reload — or React's
// dev-mode double-invoke of effects — can't re-fire the sign_up event.
function consumeSignupFlag(): boolean {
  if (typeof window === 'undefined') return false;
  const params = new URLSearchParams(window.location.search);
  if (params.get('sg_signup') !== '1') return false;
  params.delete('sg_signup');
  const qs = params.toString();
  // null, not window.history.state: see the deep-linking note in CLAUDE.md.
  window.history.replaceState(
    null,
    '',
    window.location.pathname + (qs ? `?${qs}` : '') + window.location.hash
  );
  return true;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [user, setUser] = useState<WhoAmIResponse | null>(null);
  const [mounted, setMounted] = useState(false);
  const [checkingSetup, setCheckingSetup] = useState(true);

  // Ensure we only run client-side code after mount
  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (user) identifyUser(user);
  }, [user]);

  // Mirror `authenticated` into a ref so the session-expiry handler can read the latest value
  // without being re-registered on every auth change.
  const authenticatedRef = useRef(false);
  useEffect(() => {
    authenticatedRef.current = authenticated;
  }, [authenticated]);

  // Runtime 401 handling: once authenticated, a 401 means the session was lost mid-use, so send the
  // user through a clean re-authentication instead of leaving a component showing a raw error.
  // Initial-load 401s (before authentication) are handled by setupAuth below, so this no-ops then.
  useEffect(() => {
    setSessionExpiredHandler(() => {
      if (!authenticatedRef.current) return;
      authenticatedRef.current = false;
      setAuthenticated(false);
      setUser(null);
      if (typeof window !== 'undefined') {
        localStorage.removeItem('stategraph-session-id');
        const path = window.location.pathname + window.location.search;
        const next = path && path !== '/login' ? `?next=${encodeURIComponent(path)}` : '';
        router.replace(`/login${next}`);
      }
    });
    return () => setSessionExpiredHandler(null);
  }, [router]);

  useEffect(() => {
    if (!mounted) return;

    async function setupAuth() {
      try {
        console.log('[AuthProvider] Starting auth setup...');

        // Capture (and clear) the brand-new-account marker up front so it
        // survives the awaits/redirects below and fires exactly once, only
        // after we've confirmed the user is actually authenticated.
        const isNewSignup = consumeSignupFlag();

        // 0. First, check if setup/registration is needed
        try {
          const status = await getSetupStatus();
          if (status.needs_setup && status.mode !== 'COMMUNISM') {
            console.log('[AuthProvider] Setup needed - redirecting to /register');
            // Preserve session token for after registration
            const urlParams = new URLSearchParams(window.location.search);
            const sessionId = urlParams.get('session') || localStorage.getItem('stategraph-session-id');
            if (sessionId) {
              router.replace(`/register?session=${encodeURIComponent(sessionId)}`);
            } else {
              router.replace('/register');
            }
            // Keep checkingSetup true so children don't render during redirect
            return;
          }
        } catch (err) {
          console.warn('[AuthProvider] Setup status check failed:', err);
          // Continue with auth if check fails
          setCheckingSetup(false);
        }
        // Setup check complete, no redirect needed
        setCheckingSetup(false);

        // 1. First, check if we're already authenticated (cookie might be set)
        const userResponse = await checkAuth();
        if (userResponse) {
          if (isNewSignup) pushSignupEvent('oauth');
          setAuthenticated(true);
          setUser(userResponse);
          console.log('[AuthProvider] ✓ Already authenticated!');
          return;
        }

        // 2. Not authenticated yet - try to get session ID from URL parameter
        const urlParams = new URLSearchParams(window.location.search);
        let sessionId = urlParams.get('session');
        console.log('[AuthProvider] Session from URL:', sessionId ? 'Found' : 'Not found');

        // 3. If no URL param, try localStorage (persisted from previous visit)
        if (!sessionId) {
          sessionId = localStorage.getItem('stategraph-session-id');
          console.log('[AuthProvider] Session from localStorage:', sessionId ? 'Found' : 'Not found');
        }

        // 4. If we have a session ID, initialize auth
        if (sessionId) {
          console.log('[AuthProvider] Initializing auth with session ID');
          const success = await initializeAuth(sessionId);

          if (success) {
            // Verify the session cookie is live. In the common case it already
            // is, so we clear the loading gate immediately; only if the very
            // first check misses do we retry once after a short beat (instead
            // of a blind fixed delay that prolongs the first-login screen).
            let verifyUser = await checkAuth();
            if (!verifyUser) {
              await new Promise(resolve => setTimeout(resolve, 150));
              verifyUser = await checkAuth();
            }
            if (verifyUser) {
              if (isNewSignup) pushSignupEvent('oauth');
              setAuthenticated(true);
              setUser(verifyUser);
              // Persist session ID for future visits
              localStorage.setItem('stategraph-session-id', sessionId);
              console.log('[AuthProvider] ✓ Authentication successful!');
              return;
            }
          }

          // Session initialization failed - clear stale session from localStorage
          console.log('[AuthProvider] Session invalid, clearing localStorage');
          localStorage.removeItem('stategraph-session-id');
        }

        // 5. No session ID or auth failed — send the user to /login.
        //    The login page handles every deployment mode (OAuth, Auth0,
        //    local-auth dev), so it's the safe destination even when we
        //    couldn't determine the license type (e.g. getSetupStatus
        //    threw on a SaaS deployment with a flaky network).
        console.log('[AuthProvider] Authentication failed - redirecting to /login');
        const path = window.location.pathname + window.location.search;
        const next = path && path !== '/login' ? `?next=${encodeURIComponent(path)}` : '';
        router.replace(`/login${next}`);
        return;
      } catch (e: unknown) {
        console.error('[AuthProvider] Error during auth setup:', e);
        setError(e instanceof Error ? e.message : 'Authentication setup failed');
      } finally {
        setIsLoading(false);
      }
    }

    setupAuth();
  }, [mounted, router]);

  // One calm loading visual while we resolve setup/auth, so the pre-chrome
  // gate matches every other bootstrap state instead of being a distinct screen.
  if (checkingSetup) {
    return <BootstrapLoader />;
  }

  return (
    <AuthContext.Provider value={{ isLoading, isAuthenticated: authenticated, error, user }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

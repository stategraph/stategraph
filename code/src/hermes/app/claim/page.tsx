"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  claimMagicLink,
  getLicenseStatus,
  getSetupStatus,
  initializeAuth,
  submitLicense,
} from "@/lib/api/client";

/**
 * /claim — magic-link admin claim page.
 *
 * Lands here from a Stategraph Cloud "Open deployment" handoff:
 * `https://<fqdn>/claim?token=<encoded>`. The token carries the
 * customer's email and an expiry; the customer confirms the
 * email and picks a password. Server reverifies the token's
 * HMAC signature before creating the admin.
 */

interface TokenPayload {
  email?: string;
  exp?: number;
}

/* Decode the base64url(json).base64url(sig) shape for DISPLAY
   only — the server is the authority on verification. We don't
   care about the signature here. Returns null on any decode
   error; the form just falls back to "type your email manually." */
function decodePayloadForDisplay(token: string | null): TokenPayload | null {
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  try {
    const raw = parts[0]!.replace(/-/g, "+").replace(/_/g, "/");
    const padded = raw + "===".slice((raw.length + 3) % 4);
    const json = atob(padded);
    return JSON.parse(json) as TokenPayload;
  } catch {
    return null;
  }
}

function ClaimContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  const payload = useMemo(() => decodePayloadForDisplay(token), [token]);
  const previewEmail = payload?.email ?? null;

  // SaaS deployments have no in-app claim flow — bounce to login.
  // Hold the form behind `checkingLicense` until the status check
  // resolves, otherwise the form flashes before the redirect.
  const [checkingLicense, setCheckingLicense] = useState(true);
  // Managed/communism deployments are already licensed; only self-hosted
  // handoffs that aren't licensed yet need a key before claiming.
  const [licenseRequired, setLicenseRequired] = useState(false);
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const status = await getSetupStatus();
        if (cancelled) return;
        if (status.mode === "COMMUNISM") {
          router.replace("/login");
          return;
        }
        const licenseStatus = await getLicenseStatus().catch(() => null);
        if (cancelled) return;
        setLicenseRequired(
          licenseStatus ? !licenseStatus.licensed && licenseStatus.required : false,
        );
        setCheckingLicense(false);
      } catch {
        /* ignore — claim form remains usable on transient failures */
        if (!cancelled) setCheckingLicense(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [router]);

  const [licenseKey, setLicenseKey] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [alreadySetUp, setAlreadySetUp] = useState(false);

  const passwordsMatch = password.length > 0 && password === passwordConfirm;
  const passwordLongEnough = password.length >= 8;
  const licenseOk = !licenseRequired || licenseKey.trim().length > 0;
  const canSubmit =
    !!token && passwordsMatch && passwordLongEnough && licenseOk && !submitting;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!token || !canSubmit) return;
    setSubmitting(true);
    setError(null);

    try {
      // Self-hosted handoffs that aren't licensed yet must apply the key
      // before the backend will let the admin claim complete.
      if (licenseRequired) {
        await submitLicense(licenseKey.trim());
      }
      const res = await claimMagicLink(token, password);
      // Set the session cookie, then land on the dashboard.
      const ok = await initializeAuth(res.session_token);
      if (!ok) {
        setError("Couldn't sign you in. Try refreshing the page.");
        setSubmitting(false);
        return;
      }
      router.push("/");
    } catch (e) {
      const err = e as Error & { status?: number; code?: string };
      if (err.status === 409 || err.code === "SETUP_ALREADY_COMPLETE") {
        setAlreadySetUp(true);
      } else {
        setError(err.message || "Couldn't complete setup. Please try again.");
      }
      setSubmitting(false);
    }
  }

  if (checkingLicense) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <div className="text-[var(--sg-text-muted)]">Loading…</div>
      </div>
    );
  }

  if (!token) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <div className="max-w-md text-center">
          <h1 className="text-2xl font-semibold mb-2">Missing setup link</h1>
          <p className="text-[var(--sg-text-muted)] mb-6">
            This page expects a magic link from your Stategraph Cloud
            dashboard. Open your deployment from there to continue.
          </p>
          <Link
            href="/login"
            className="text-[var(--sg-accent)] hover:underline"
          >
            Sign in instead
          </Link>
        </div>
      </div>
    );
  }

  if (alreadySetUp) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <div className="max-w-md text-center">
          <h1 className="text-2xl font-semibold mb-2">Already set up</h1>
          <p className="text-[var(--sg-text-muted)] mb-6">
            An admin user has already been created for this deployment.
            Sign in with the password that was set up.
          </p>
          <Link
            href="/login"
            className="inline-block bg-[var(--sg-accent)] text-white px-4 py-2 rounded hover:opacity-90"
          >
            Go to sign in
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        <h1 className="text-2xl font-semibold mb-2">Set up your account</h1>
        <p className="text-[var(--sg-text-muted)] mb-6">
          {previewEmail ? (
            <>
              Signing in as <strong>{previewEmail}</strong>. Pick a password
              you&apos;ll use for this deployment from now on.
            </>
          ) : (
            <>Pick a password you&apos;ll use for this deployment from now on.</>
          )}
        </p>

        <form onSubmit={onSubmit} className="space-y-4">
          {licenseRequired && (
            <div>
              <label
                htmlFor="license-key"
                className="block text-sm font-medium mb-1"
              >
                License key
              </label>
              <Input
                id="license-key"
                type="text"
                value={licenseKey}
                onChange={(e) => setLicenseKey(e.target.value)}
                required
                placeholder="Paste your license key"
              />
            </div>
          )}

          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium mb-1"
            >
              Set a password
            </label>
            <Input
              id="password"
              type="password"
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              placeholder="At least 8 characters"
            />
          </div>

          <div>
            <label
              htmlFor="password-confirm"
              className="block text-sm font-medium mb-1"
            >
              Confirm password
            </label>
            <Input
              id="password-confirm"
              type="password"
              autoComplete="new-password"
              value={passwordConfirm}
              onChange={(e) => setPasswordConfirm(e.target.value)}
              required
              minLength={8}
            />
            {passwordConfirm.length > 0 && !passwordsMatch && (
              <p className="text-xs text-[var(--sg-error)] mt-1">
                Passwords don&apos;t match.
              </p>
            )}
          </div>

          {error && (
            <div className="text-sm text-[var(--sg-error)] bg-[var(--sg-error-bg)] p-3 rounded">
              {error}
            </div>
          )}

          <Button type="submit" disabled={!canSubmit} className="w-full">
            {submitting ? "Setting up…" : "Create account"}
          </Button>
        </form>
      </div>
    </div>
  );
}

export default function ClaimPage() {
  return (
    <Suspense fallback={<div className="p-6">Loading…</div>}>
      <ClaimContent />
    </Suspense>
  );
}

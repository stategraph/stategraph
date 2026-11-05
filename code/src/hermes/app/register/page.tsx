"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  getSetupStatus,
  getLoginOptions,
  createAdminUser,
  initializeAuth,
  checkAuth,
  getLicenseStatus,
  submitLicense,
} from "@/lib/api/client";
import { Mail, ArrowLeft, ExternalLink, CheckCircle2, KeyRound } from "lucide-react";
import { pushSignupEvent } from "@/lib/analytics";

type Step = "license" | "register";

const STEPS: { key: Step; label: string }[] = [
  { key: "license", label: "License" },
  { key: "register", label: "Account" },
];

function StepIndicator({ current }: { current: Step }) {
  const currentIndex = STEPS.findIndex((s) => s.key === current);
  return (
    <div className="flex items-center justify-center gap-3 mb-10">
      {STEPS.map((s, i) => {
        const isDone = i < currentIndex;
        const isActive = i === currentIndex;
        return (
          <div key={s.key} className="flex items-center gap-3">
            {i > 0 && (
              <div
                className={`w-12 h-px ${
                  isDone ? "bg-[var(--sg-accent)]" : "bg-[var(--sg-border)]"
                }`}
              />
            )}
            <div className="flex items-center gap-2">
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold transition-colors ${
                  isDone || isActive
                    ? "bg-[var(--sg-accent)] text-white"
                    : "bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border border-[var(--sg-border)]"
                }`}
              >
                {isDone ? (
                  <CheckCircle2 className="w-4 h-4" />
                ) : (
                  i + 1
                )}
              </div>
              <span
                className={`text-sm font-medium ${
                  isActive
                    ? "text-[var(--sg-text)]"
                    : "text-[var(--sg-text-muted)]"
                }`}
              >
                {s.label}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function RegisterContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Current step in the flow
  const [step, setStep] = useState<Step>("license");

  // Get session token from URL (passed from AuthProvider)
  const sessionToken = searchParams.get("session");

  // Form state
  const [licenseKey, setLicenseKey] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [organization, setOrganization] = useState("");
  // Check if we're in local auth mode (no OAuth providers)
  const [isLocalAuth, setIsLocalAuth] = useState(false);

  // Check if registration is needed and auth mode
  useEffect(() => {
    async function checkSetup() {
      try {
        // Check if we're in local auth mode (no OAuth providers)
        const loginOpts = await getLoginOptions();
        const localAuthMode = loginOpts.options.length === 0;
        setIsLocalAuth(localAuthMode);

        const status = await getSetupStatus();
        if (!status.needs_setup) {
          // Registration already done, redirect with session if available
          if (sessionToken) {
            router.push(`/?session=${encodeURIComponent(sessionToken)}`);
          } else {
            router.push("/login");
          }
          return;
        }

        // If the instance is already licensed (e.g. license provided via env
        // var), or this edition needs no license, skip the key prompt and go
        // straight to account creation.
        const licenseStatus = await getLicenseStatus().catch(() => null);
        const licenseNeeded = !(licenseStatus?.licensed || licenseStatus?.required === false);
        if (localAuthMode) {
          setStep(licenseNeeded ? "license" : "register");
        } else if (licenseNeeded) {
          setStep("license");
        } else if (sessionToken) {
          router.push(`/?session=${encodeURIComponent(sessionToken)}`);
          return;
        } else {
          // OAuth users arrive through the identity provider: with the license
          // in place there is nothing left to do here.
          router.push("/login");
          return;
        }

        setLoading(false);
      } catch (err) {
        console.error("Failed to check setup status:", err);
        // If we can't check, assume registration needed
        setLoading(false);
      }
    }
    checkSetup();
  }, [router, sessionToken]);

  // Step 1: Apply the license key, then advance to account creation.
  const handleSubmitLicense = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);

    try {
      await submitLicense(licenseKey.trim());
      if (isLocalAuth) {
        setStep("register");
      } else if (sessionToken) {
        router.push(`/?session=${encodeURIComponent(sessionToken)}`);
      } else {
        // OAuth: the license was all that was missing; sign-in goes through the
        // identity provider.
        router.push("/login");
      }
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Invalid license key."
      );
    } finally {
      setSubmitting(false);
    }
  };

  // Step 2: Create the first admin account. Local auth only: with OAuth, users arrive through the
  // identity provider and there is no account to create here.
  const handleCompleteRegistration = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);

    try {
      // Local auth mode: create admin user with password
      const result = await createAdminUser(email, password, name, organization);

      // Set session cookie using the returned token
      await initializeAuth(result.session_token);

      // Verify auth worked
      const user = await checkAuth();
      if (!user) {
        throw new Error("Session initialization failed");
      }

      pushSignupEvent("local");

      // Redirect to app
      router.push("/");
    } catch (err) {
      console.error("Registration error:", err);
      setError(
        err instanceof Error
          ? err.message
          : "An error occurred. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return <LoadingState message="Checking setup status..." />;
  }

  // Step 1: License key entry
  if (step === "license") {
    return (
      <Shell>
        <StepIndicator current="license" />

        <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-[var(--sg-card-radius)] p-6 sm:p-10">
          {/* Header */}
          <div className="text-center mb-8">
            <div className="w-16 h-16 rounded-full bg-[var(--sg-accent-bg)] flex items-center justify-center mx-auto mb-5">
              <KeyRound className="w-8 h-8 text-[var(--sg-accent)]" />
            </div>
            <h1 className="text-3xl font-bold text-[var(--sg-text)]">
              Enter your license key
            </h1>
            <p className="text-base text-[var(--sg-text-muted)] mt-3">
              Paste the license key you received to activate Stategraph.
            </p>
          </div>

          {/* License Key Form */}
          <form onSubmit={handleSubmitLicense} className="space-y-5">
            <div className="space-y-2">
              <label
                htmlFor="license-key"
                className="block text-base font-medium text-[var(--sg-text)]"
              >
                License key
              </label>
              <Input
                id="license-key"
                type="text"
                required
                value={licenseKey}
                onChange={(e) => setLicenseKey(e.target.value)}
                placeholder="Paste your license key"
                className="h-12 text-base"
                autoFocus
              />
            </div>

            {error && <ErrorMessage message={error} />}

            <Button
              type="submit"
              variant="default"
              size="lg"
              className="w-full h-12 text-base"
              disabled={submitting || !licenseKey.trim()}
            >
              {submitting ? (
                "Activating..."
              ) : (
                <>
                  <KeyRound className="w-5 h-5 mr-2" />
                  Activate
                </>
              )}
            </Button>
          </form>
        </div>

        {/* Air-gapped help */}
        <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-[var(--sg-card-radius)] p-6 sm:p-8 mt-4">
          <div className="flex items-center gap-3 mb-5">
            <Mail className="w-6 h-6 text-[var(--sg-text-muted)]" />
            <span className="text-base font-medium text-[var(--sg-text)]">
              Need a license key?
            </span>
          </div>
          <p className="text-base text-[var(--sg-text-muted)] text-center mb-3">
            Contact us to obtain an offline license:
          </p>
          <div className="flex flex-wrap justify-center gap-x-6 gap-y-3">
            <a
              href="mailto:hello@stategraph.com?subject=Stategraph%20Air-Gapped%20License%20Request"
              className="text-base text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1.5"
            >
              <Mail className="w-4 h-4" />
              hello@stategraph.com
            </a>
            <a
              href="https://stategraph.com/discord"
              target="_blank"
              rel="noopener noreferrer"
              className="text-base text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1.5"
            >
              <ExternalLink className="w-4 h-4" />
              Discord
            </a>
          </div>
        </div>
      </Shell>
    );
  }

  // Step 2: Complete registration
  return (
    <Shell>
      <StepIndicator current="register" />

      <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-[var(--sg-card-radius)] p-10">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-full bg-[var(--sg-accent-bg)] flex items-center justify-center mx-auto mb-5">
            <CheckCircle2 className="w-8 h-8 text-[var(--sg-accent)]" />
          </div>
          <h1 className="text-3xl font-bold text-[var(--sg-text)]">
            Complete Setup
          </h1>
          <p className="text-base text-[var(--sg-text-muted)] mt-3">
            Create your admin account to get started
          </p>
        </div>

        {/* Registration Form */}
        <form onSubmit={handleCompleteRegistration} className="space-y-5">
          {/* Email */}
          <div className="space-y-2">
            <label
              htmlFor="email"
              className="block text-base font-medium text-[var(--sg-text)]"
            >
              Email <span className="text-[var(--sg-error)]">*</span>
            </label>
            <Input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              className="h-12 text-base"
              autoFocus
            />
          </div>

          {/* Password */}
          <div className="space-y-2">
            <label
              htmlFor="password"
              className="block text-base font-medium text-[var(--sg-text)]"
            >
              Password <span className="text-[var(--sg-error)]">*</span>
            </label>
            <Input
              id="password"
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Minimum 8 characters"
              className="h-12 text-base"
              minLength={8}
              maxLength={128}
            />
            <p className="text-sm text-[var(--sg-text-muted)]">
              Must be at least 8 characters
            </p>
          </div>

          {/* Name */}
          <div className="space-y-2">
            <label
              htmlFor="name"
              className="block text-base font-medium text-[var(--sg-text)]"
            >
              Your name <span className="text-[var(--sg-error)]">*</span>
            </label>
            <Input
              id="name"
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Jane Doe"
              className="h-12 text-base"
            />
          </div>

          {/* Organization */}
          <div className="space-y-2">
            <label
              htmlFor="organization"
              className="block text-base font-medium text-[var(--sg-text)]"
            >
              Organization <span className="text-[var(--sg-error)]">*</span>
            </label>
            <Input
              id="organization"
              type="text"
              required
              value={organization}
              onChange={(e) => setOrganization(e.target.value)}
              placeholder="Acme Corp"
              className="h-12 text-base"
            />
          </div>

          {error && <ErrorMessage message={error} />}

          {/* Submit button */}
          <Button
            type="submit"
            variant="default"
            size="lg"
            className="w-full h-12 text-base"
            disabled={submitting || !name || !organization || !email || password.length < 8}
          >
            {submitting ? "Creating Account..." : "Create Account"}
          </Button>
        </form>

        {/* Back button */}
        <div className="mt-8 pt-8 border-t border-[var(--sg-border)]">
          <Button
            type="button"
            variant="ghost"
            size="lg"
            className="w-full text-base"
            onClick={() => {
              setStep("license");
              setError(null);
            }}
          >
            <ArrowLeft className="w-5 h-5 mr-2" />
            Back
          </Button>
        </div>
      </div>
    </Shell>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-[var(--sg-bg-0)] px-6">
      <div className="max-w-lg w-full">
        {/* Branding */}
        <div className="text-center mb-8">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_white.svg"
            alt="Stategraph"
            className="h-16 mx-auto hidden dark:block"
          />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_blue.svg"
            alt="Stategraph"
            className="h-16 mx-auto dark:hidden"
          />
        </div>
        {children}
      </div>
    </div>
  );
}

function ErrorMessage({ message }: { message: string }) {
  if (message === "NETWORK_ERROR") {
    return <NetworkErrorMessage />;
  }
  return (
    <div className="px-5 py-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
      <p className="text-base text-[var(--sg-error)] text-center">{message}</p>
    </div>
  );
}

function NetworkErrorMessage() {
  return (
    <div className="px-5 py-5 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg space-y-3">
      <p className="text-base font-medium text-[var(--sg-text)]">
        Unable to reach the license server
      </p>
      <p className="text-sm text-[var(--sg-text-muted)]">
        This can happen in air-gapped or restricted network environments.
        Contact us for an offline license.
      </p>
      <div className="flex flex-wrap gap-4 pt-1">
        <a
          href="mailto:hello@stategraph.com?subject=Stategraph%20License%20Request"
          className="text-base text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1.5"
        >
          <Mail className="w-4 h-4" />
          hello@stategraph.com
        </a>
        <a
          href="https://stategraph.com/discord"
          target="_blank"
          rel="noopener noreferrer"
          className="text-base text-[var(--sg-accent)] hover:underline inline-flex items-center gap-1.5"
        >
          <ExternalLink className="w-4 h-4" />
          Discord
        </a>
      </div>
    </div>
  );
}

function LoadingState({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center min-h-screen bg-[var(--sg-bg-0)]">
      <div className="text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[var(--sg-accent)] mx-auto mb-3"></div>
        <p className="text-sm text-[var(--sg-text-muted)]">{message}</p>
      </div>
    </div>
  );
}

export default function RegisterPage() {
  return (
    <Suspense fallback={<LoadingState message="Loading..." />}>
      <RegisterContent />
    </Suspense>
  );
}

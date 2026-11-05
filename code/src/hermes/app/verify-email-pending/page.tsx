"use client";

/**
 * /verify-email-pending — landing page shown after a user signs up via
 * Auth0 but hasn't clicked the verification email yet.
 *
 * Reached via external redirect, not in-app navigation: Auth0 is
 * configured (in the Auth0 Dashboard under Branding → Universal Login,
 * or via a post-login Action) to redirect unverified-email logins here.
 * That's why grep for "/verify-email-pending" in this repo turns up
 * nothing — the route lives in Auth0's tenant config.
 */

import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Mail } from "lucide-react";

export default function VerifyEmailPendingPage() {
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

        <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-[var(--sg-card-radius)] p-6 sm:p-10">
          <div className="text-center mb-8">
            <div className="w-16 h-16 rounded-full bg-[var(--sg-accent-bg)] flex items-center justify-center mx-auto mb-5">
              <Mail className="w-8 h-8 text-[var(--sg-accent)]" />
            </div>
            <h1 className="text-3xl font-bold text-[var(--sg-text)]">
              Check your inbox
            </h1>
            <p className="text-base text-[var(--sg-text-muted)] mt-3">
              We sent you a verification email when you signed up. Click the
              link in that email to verify your address, then sign in again.
            </p>
          </div>

          <Button
            asChild
            variant="default"
            size="lg"
            className="w-full h-12 text-base"
          >
            <Link href="/login">Back to sign in</Link>
          </Button>

          <p className="text-sm text-[var(--sg-text-muted)] text-center mt-6">
            Didn&apos;t get the email? Check your spam folder, or contact{" "}
            <a
              href="mailto:hello@stategraph.com?subject=Stategraph%20verification%20email"
              className="text-[var(--sg-accent)] hover:underline"
            >
              hello@stategraph.com
            </a>
            .
          </p>
        </div>
      </div>
    </div>
  );
}

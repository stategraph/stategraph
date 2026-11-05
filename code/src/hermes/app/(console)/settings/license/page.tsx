"use client";

import { Suspense, useState } from "react";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { useLicense } from "@/contexts";
import { ExternalLink } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { submitLicense } from "@/lib/api/client";

function StatusBadge({ licensed }: { licensed: boolean }) {
  const className = licensed
    ? "bg-[var(--sg-success)]/15 text-[var(--sg-success)] border-[var(--sg-success)]/30"
    : "bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border-[var(--sg-border)]";

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${className}`}>
      {licensed ? "Licensed" : "Not licensed"}
    </span>
  );
}

function DetailRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between py-3 border-b border-[var(--sg-border)] last:border-b-0">
      <span className="text-sm text-[var(--sg-text-muted)]">{label}</span>
      <span className="text-sm font-medium text-[var(--sg-text)]">{children}</span>
    </div>
  );
}

function LicenseSettingsContent() {
  const { isLoading, licensed, required, refresh } = useLicense();

  const [key, setKey] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [applyError, setApplyError] = useState<string | null>(null);
  const [applySuccess, setApplySuccess] = useState(false);

  async function handleApply(e: React.FormEvent) {
    e.preventDefault();
    setApplyError(null);
    setApplySuccess(false);
    setSubmitting(true);
    try {
      await submitLicense(key.trim());
      await refresh();
      setKey("");
      setApplySuccess(true);
    } catch (err) {
      setApplyError(err instanceof Error ? err.message : "Invalid license key.");
    } finally {
      setSubmitting(false);
    }
  }


  return (
    <div className="flex flex-col w-full">
      <PageHeader title="License" subtitle="Your Stategraph license details" />

      <PageSection title="License Status">
        <PageSurface>
          {isLoading ? (
            <div className="space-y-4">
              <div className="h-5 w-24 sg-skeleton-shimmer" />
              <div className="h-4 w-48 sg-skeleton-shimmer" />
            </div>
          ) : (
            <div>
              {required ? (
                <DetailRow label="Status">
                  <StatusBadge licensed={licensed} />
                </DetailRow>
              ) : (
                <DetailRow label="Status">Not required by this build</DetailRow>
              )}
            </div>
          )}
        </PageSurface>
      </PageSection>

      {/* A build that needs no license takes no key. */}
      {!isLoading && required && (
      <PageSection title="Apply license key">
        <PageSurface>
          <form onSubmit={handleApply} className="space-y-4">
            <Input
              id="license-key"
              type="text"
              value={key}
              onChange={(e) => {
                setKey(e.target.value);
                setApplyError(null);
                setApplySuccess(false);
              }}
              placeholder="Paste your license key"
            />
            {applyError && (
              <div className="text-sm text-[var(--sg-error)]">{applyError}</div>
            )}
            {applySuccess && (
              <div className="text-sm text-[var(--sg-success)]">License applied.</div>
            )}
            <Button
              type="submit"
              variant="default"
              disabled={submitting || !key.trim()}
            >
              {submitting ? "Applying..." : "Apply key"}
            </Button>
          </form>
        </PageSurface>
      </PageSection>
      )}

      {!licensed && (
        <PageSection title="">
          <div className="pt-2">
            <a
              href="https://stategraph.com/contact"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button variant="default" className="gap-2">
                <ExternalLink className="h-4 w-4" />
                Contact Sales
              </Button>
            </a>
          </div>
        </PageSection>
      )}
    </div>
  );
}

export default function LicenseSettingsPage() {
  return (
    <Suspense fallback={<div className="text-[var(--sg-text-muted)]">Loading...</div>}>
      <AuthGuard>
        <LicenseSettingsContent />
      </AuthGuard>
    </Suspense>
  );
}

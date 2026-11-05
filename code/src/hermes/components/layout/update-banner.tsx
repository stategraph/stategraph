"use client";

import { useState } from "react";
import { useVersion, useLicense } from "@/contexts";
import { AlertCircle, X, ExternalLink } from "lucide-react";

const DISMISSED_KEY = "stategraph-update-banner-dismissed";

export function UpdateBanner() {
  const { updateAvailable, latestRelease, currentVersion } = useVersion();
  const { mode } = useLicense();
  const [dismissed, setDismissed] = useState(() => {
    if (typeof window === "undefined") return false;
    const stored = localStorage.getItem(DISMISSED_KEY);
    if (!stored) return false;
    // Only stay dismissed if it was for this specific version
    return stored === latestRelease?.tag_name;
  });

  // In COMMUNISM mode the server is a shared hosted substrate; users don't
  // self-upgrade, so the upgrade banner is irrelevant.
  if (mode === "COMMUNISM" || !updateAvailable || !latestRelease || dismissed) {
    return null;
  }

  const handleDismiss = () => {
    setDismissed(true);
    localStorage.setItem(DISMISSED_KEY, latestRelease.tag_name);
  };

  return (
    <div className="flex items-center justify-between gap-4 px-4 py-2 bg-[var(--sg-warning)]/10 border-b border-[var(--sg-warning)]/30">
      <div className="flex items-center gap-3 text-sm">
        <AlertCircle className="h-4 w-4 text-[var(--sg-warning)] flex-shrink-0" />
        <span className="text-[var(--sg-text)]">
          A new version of Stategraph is available:{" "}
          <span className="font-medium">{latestRelease.tag_name}</span>
          {currentVersion && (
            <span className="text-[var(--sg-text-muted)]">
              {" "}(current: {currentVersion})
            </span>
          )}
        </span>
        <a
          href={latestRelease.html_url}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 text-[var(--sg-accent)] hover:underline"
        >
          View release
          <ExternalLink className="h-3 w-3" />
        </a>
      </div>
      <button
        onClick={handleDismiss}
        className="p-1 rounded hover:bg-[var(--sg-warning)]/20 text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] transition-colors"
        aria-label="Dismiss update notification"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}

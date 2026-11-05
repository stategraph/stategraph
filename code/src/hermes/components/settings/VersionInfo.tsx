"use client";

import { useVersion } from "@/contexts";
import { Button } from "@/components/ui/button";
import { RefreshCw, ExternalLink, CheckCircle2, AlertCircle } from "lucide-react";
import { isValidSemver } from "@/lib/utils/version";

export function VersionInfo() {
  const {
    currentVersion,
    latestRelease,
    updateAvailable,
    isLoading,
    error,
    lastChecked,
    refresh,
  } = useVersion();

  const formatLastChecked = (timestamp: number | null): string => {
    if (!timestamp) return "Never";
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  const isDevVersion = currentVersion && !isValidSemver(currentVersion);

  return (
    <div className="space-y-4">
      {/* Current Version */}
      <div className="space-y-2">
        <div className="text-sm font-semibold text-[var(--sg-text)]">
          Current Version
        </div>
        <div className="flex items-center gap-2">
          <code className="px-2 py-1 rounded bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-sm font-mono text-[var(--sg-text)]">
            {isLoading && !currentVersion ? "Loading..." : currentVersion || "Unknown"}
          </code>
          {isDevVersion && (
            <span className="text-xs text-[var(--sg-text-muted)]">
              (development build)
            </span>
          )}
        </div>
      </div>

      {/* Latest Version / Update Available */}
      {latestRelease && (
        <div className="space-y-2">
          <div className="text-sm font-semibold text-[var(--sg-text)]">
            Latest Version
          </div>
          <div className="flex items-center gap-2">
            <code className="px-2 py-1 rounded bg-[var(--sg-bg-0)] border border-[var(--sg-border)] text-sm font-mono text-[var(--sg-text)]">
              {latestRelease.tag_name}
            </code>
            {updateAvailable ? (
              <span className="flex items-center gap-1 text-xs text-[var(--sg-warning)]">
                <AlertCircle className="h-3.5 w-3.5" />
                Update available
              </span>
            ) : (
              !isDevVersion && currentVersion && (
                <span className="flex items-center gap-1 text-xs text-[var(--sg-success)]">
                  <CheckCircle2 className="h-3.5 w-3.5" />
                  Up to date
                </span>
              )
            )}
          </div>
        </div>
      )}

      {/* Update Notification */}
      {updateAvailable && latestRelease && (
        <div className="p-3 rounded-lg bg-[var(--sg-warning)]/10 border border-[var(--sg-warning)]/30">
          <div className="text-sm text-[var(--sg-text)] mb-2">
            A new version of Stategraph is available!
          </div>
          <a
            href={latestRelease.html_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-sm text-[var(--sg-accent)] hover:underline"
          >
            View release notes
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="p-3 rounded-lg bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30">
          <div className="text-sm text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Last Checked & Refresh */}
      <div className="flex flex-wrap items-center justify-between gap-2 pt-2">
        <div className="text-xs text-[var(--sg-text-dim)]">
          Last checked: {formatLastChecked(lastChecked)}
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={refresh}
          disabled={isLoading}
          className="gap-2"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${isLoading ? "animate-spin" : ""}`} />
          Check for updates
        </Button>
      </div>
    </div>
  );
}

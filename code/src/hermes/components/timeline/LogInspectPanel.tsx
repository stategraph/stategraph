"use client";

import { useEffect, useCallback, useState } from "react";
import { X, Copy, Check } from "lucide-react";
import type { TransactionLogRow } from "@/lib/timeline/types";
import { cn } from "@/lib/utils";

interface LogInspectPanelProps {
  log: TransactionLogRow | null;
  onClose: () => void;
}

function CopyJsonButton({ content }: { content: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(content);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error("Failed to copy:", err);
    }
  };

  return (
    <button
      onClick={handleCopy}
      className="flex items-center gap-1 px-2 py-1 text-xs rounded bg-[var(--sg-bg-2)] hover:bg-[var(--sg-accent-bg)] text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] border border-[var(--sg-border)] transition-colors"
      title="Copy JSON to clipboard"
    >
      {copied ? (
        <>
          <Check className="h-3 w-3" />
          <span>Copied</span>
        </>
      ) : (
        <>
          <Copy className="h-3 w-3" />
          <span>Copy</span>
        </>
      )}
    </button>
  );
}

export function LogInspectPanel({ log, onClose }: LogInspectPanelProps) {
  const handleClose = useCallback(() => {
    onClose();
  }, [onClose]);

  // Close with Escape key
  useEffect(() => {
    if (!log) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        handleClose();
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [log, handleClose]);

  if (!log) return null;

  const fullJson = JSON.stringify(log, null, 2);
  const dataJson = log.data !== null && log.data !== undefined
    ? JSON.stringify(log.data, null, 2)
    : null;

  return (
    <>
      {/* Backdrop — mobile/tablet only, dismisses the sheet on tap */}
      <div
        className="fixed inset-0 z-40 bg-black/50 lg:hidden"
        onClick={handleClose}
        aria-hidden="true"
      />
      <aside
        className={cn(
          "flex flex-col bg-[var(--sg-bg-2)] border-l border-[var(--sg-border)]",
          "w-[var(--sg-inspector-width)] max-w-[90vw]",
          // Off-canvas sheet on mobile/tablet …
          "fixed inset-y-0 right-0 z-50",
          // … static side column on lg+
          "lg:static lg:z-auto lg:max-w-none"
        )}
      >
      {/* Header */}
      <div className="sticky top-0 bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] px-4 py-3 flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="text-sm font-semibold text-[var(--sg-text)] mb-1">
            Log Entry
          </div>
          <div className="text-xs text-[var(--sg-text-muted)] font-mono break-all">
            {log.id}
          </div>
        </div>
        <button
          onClick={handleClose}
          className="flex-shrink-0 p-1 rounded-[var(--sg-radius-xs)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)] transition-colors"
          aria-label="Close inspector"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      {/* Body */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {/* Metadata */}
        <div>
          <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)] mb-3">
            Metadata
          </h3>
          <div className="grid grid-cols-[100px,1fr] gap-x-3 gap-y-2 text-xs">
            <span className="text-[var(--sg-text-dim)]">Action</span>
            <span
              className={`font-mono px-1.5 py-0.5 rounded w-fit ${
                log.action === "state_set"
                  ? "bg-[var(--sg-success)]/10 text-[var(--sg-success)]"
                  : "bg-[var(--sg-error)]/10 text-[var(--sg-error)]"
              }`}
            >
              {log.action}
            </span>

            <span className="text-[var(--sg-text-dim)]">Object Type</span>
            <span className="font-mono text-[var(--sg-accent)]">
              {log.object_type}
            </span>

            <span className="text-[var(--sg-text-dim)]">Created At</span>
            <span className="font-mono text-[var(--sg-text)]">
              {log.created_at}
            </span>

            <span className="text-[var(--sg-text-dim)]">State ID</span>
            <span className="font-mono text-[var(--sg-text)] break-all">
              {log.state_id}
            </span>

            {log.user_id && (
              <>
                <span className="text-[var(--sg-text-dim)]">User ID</span>
                <span className="font-mono text-[var(--sg-text)] break-all">
                  {log.user_id}
                </span>
              </>
            )}
          </div>
        </div>

        {/* Data payload */}
        {dataJson && (
          <div>
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)]">
                Data Payload
              </h3>
              <CopyJsonButton content={dataJson} />
            </div>
            <pre className="text-xs font-mono text-[var(--sg-text)] bg-[var(--sg-bg-0)] p-3 rounded border border-[var(--sg-border)] overflow-x-auto overflow-y-auto max-h-[60vh] min-w-0 w-full whitespace-pre-wrap break-all">
              {dataJson}
            </pre>
          </div>
        )}

        {/* Full log JSON */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-text-muted)]">
              Full Log JSON
            </h3>
            <CopyJsonButton content={fullJson} />
          </div>
          <pre className="text-xs font-mono text-[var(--sg-text)] bg-[var(--sg-bg-0)] p-3 rounded border border-[var(--sg-border)] overflow-x-auto overflow-y-auto max-h-[40vh] min-w-0 w-full whitespace-pre-wrap break-all">
            {fullJson}
          </pre>
        </div>
      </div>
      </aside>
    </>
  );
}

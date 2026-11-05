"use client";

import { useMemo, useState, type ReactNode } from "react";
import { AlertTriangle, Download, Maximize2 } from "lucide-react";
import { CopyButton } from "@/components/ui/copy-button";
import { downloadFile } from "@/lib/export";
import { formatSize, previewOf, sizeTier } from "@/lib/wm/outputSize";

/** Opens the expanded view of an output with the renderer its block uses. */
export type ExpandOutput = (content: string, title: string, render: (text: string) => ReactNode) => void;

interface OutputSizeGuardProps {
  content: string;
  /** Names the output in warnings and the expand modal. */
  title: string;
  downloadName: string;
  onExpand?: ExpandOutput;
  /** Identity row content (dir, workspace, counts) shown left of the toolbar buttons. */
  heading?: ReactNode;
  /** Renders the (possibly truncated) text; called only when safe to render. */
  children: (text: string) => ReactNode;
}

/** Gate rendering by content size so a huge plan can never freeze the tab:
 *  small output renders immediately, larger output renders behind a click,
 *  and anything over 20MB is download-only. */
export function OutputSizeGuard({ content, title, downloadName, onExpand, heading, children }: OutputSizeGuardProps) {
  const tier = sizeTier(content.length);
  const initial = tier === "auto" ? "preview" : "hidden";
  const [state, setState] = useState<"hidden" | "preview" | "full">(initial);
  // The content can change under a mounted guard (Older/Newer reuses this
  // component for another run's output): a different size tier starts over,
  // so a small output never inherits a large one's hidden state.
  const [stateTier, setStateTier] = useState(tier);
  if (stateTier !== tier) {
    setStateTier(tier);
    setState(initial);
  }
  // Splitting a multi-MB string is not free, and a live run re-renders on
  // every poll; only a new content or state recomputes the preview.
  const preview = useMemo(
    () => (state === "preview" ? previewOf(content) : { text: content, truncated: false }),
    [state, content],
  );

  if (tier === "blocked" || state === "hidden") {
    const label =
      tier === "warn" ? "Large output" : tier === "explicit" ? "Very large output" : "Extremely large output";
    return (
      <div className="m-3 rounded-md border border-[var(--sg-warning)] bg-[var(--sg-warning-bg)] p-3 text-xs">
        <div className="flex items-center gap-2 text-[var(--sg-warning)] font-medium">
          <AlertTriangle className="w-4 h-4 shrink-0" />
          {label}: {title} is {formatSize(content.length)}.
        </div>
        <div className="mt-2 flex flex-wrap gap-2">
          {tier !== "blocked" && (
            <button
              type="button"
              onClick={() => setState("preview")}
              className="px-2 py-1 rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
            >
              Show preview
            </button>
          )}
          {tier === "warn" && (
            <button
              type="button"
              onClick={() => setState("full")}
              className="px-2 py-1 rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
            >
              Load full output
            </button>
          )}
          <button
            type="button"
            onClick={() => downloadFile(content, downloadName, "text/plain")}
            className="inline-flex items-center gap-1 px-2 py-1 rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
          >
            <Download className="w-3 h-3" /> Download
          </button>
        </div>
        {tier === "blocked" && (
          <p className="mt-2 text-[var(--sg-text-muted)]">
            This output is too large to view in the browser. Download it instead.
          </p>
        )}
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-end gap-2 px-2 py-1 border-b border-[var(--sg-border-light)] bg-[var(--sg-bg-2)] rounded-t-md">
        {heading && <div className="mr-auto flex items-center gap-2 min-w-0 pl-1">{heading}</div>}
        {content.length > 1_000_000 && (
          <span className={`text-[10px] text-[var(--sg-text-dim)] ${heading ? "" : "mr-auto"}`}>
            {formatSize(content.length)}
          </span>
        )}
        <CopyButton text={content} />
        {onExpand && (
          <button
            type="button"
            // The modal renders what the guard currently allows: a truncated
            // preview stays truncated there until the full output is loaded.
            onClick={() => onExpand(preview.text, title, children)}
            title="Expand"
            className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
          >
            <Maximize2 className="w-3 h-3" /> Expand
          </button>
        )}
        <button
          type="button"
          onClick={() => downloadFile(content, downloadName, "text/plain")}
          title="Download"
          className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
        >
          <Download className="w-3 h-3" /> Download
        </button>
      </div>
      <div className={state === "full" ? "" : "max-h-96 overflow-auto"}>{children(preview.text)}</div>
      {preview.truncated && (
        <div className="px-3 py-2 text-center border-t border-[var(--sg-border-light)]">
          <button
            type="button"
            onClick={() => setState("full")}
            className="px-3 py-1 text-xs rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
          >
            Load full output ({formatSize(content.length)})
          </button>
        </div>
      )}
    </div>
  );
}

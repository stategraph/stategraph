"use client";

import { useMemo, type ReactNode } from "react";
import { CopyButton } from "@/components/ui/copy-button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";

interface OutputModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  content: string;
  /** Renders the content as its inline block does; plain monospace text when absent. */
  render?: (text: string) => ReactNode;
}

/** Full-screen view of one step output with copy and line/character counts. */
export function OutputModal({ open, onOpenChange, title, content, render }: OutputModalProps) {
  const lineCount = useMemo(() => (content ? content.split("\n").length : 0), [content]);
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[90vw] max-h-[85vh] flex flex-col">
        <DialogHeader>
          <DialogTitle className="truncate pr-8">{title}</DialogTitle>
          <DialogDescription className="sr-only">
            {lineCount.toLocaleString()} lines, {content.length.toLocaleString()} characters
          </DialogDescription>
        </DialogHeader>
        {render ? (
          <div className="flex-1 min-h-0 overflow-auto rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
            {render(content)}
          </div>
        ) : (
          <pre className="flex-1 min-h-0 overflow-auto text-xs font-mono whitespace-pre-wrap rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 text-[var(--sg-text-muted)]">
            {content}
          </pre>
        )}
        <div className="flex items-center justify-between pt-2 text-xs text-[var(--sg-text-dim)]">
          <span>
            {lineCount.toLocaleString()} lines · {content.length.toLocaleString()} characters
          </span>
          <CopyButton text={content} />
        </div>
      </DialogContent>
    </Dialog>
  );
}

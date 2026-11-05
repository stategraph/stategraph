"use client";

import { useState } from "react";
import { Check, Copy } from "lucide-react";
import { copyText } from "@/lib/utils/clipboard";

interface CopyButtonProps {
  text: string;
  title?: string;
}

/**
 * A compact "Copy" button that puts `text` on the clipboard and reads "Copied"
 * for a moment after. It copies through {@link copyText}, so it works on a
 * plain-HTTP self-hosted origin too, where `navigator.clipboard` is missing.
 */
export function CopyButton({ text, title = "Copy" }: CopyButtonProps) {
  const [copied, setCopied] = useState(false);

  const onCopy = async () => {
    // A failed copy changes nothing on screen: the text is displayed and
    // selectable, so the user can still copy it by hand.
    if (await copyText(text)) {
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
    }
  };

  return (
    <button
      type="button"
      onClick={onCopy}
      title={copied ? "Copied" : title}
      className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded border border-[var(--sg-border)] bg-[var(--sg-bg-1)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] cursor-pointer"
    >
      {copied ? (
        <>
          <Check className="w-3 h-3 text-[var(--sg-success)]" />
          <span>Copied</span>
        </>
      ) : (
        <>
          <Copy className="w-3 h-3" />
          <span>Copy</span>
        </>
      )}
    </button>
  );
}

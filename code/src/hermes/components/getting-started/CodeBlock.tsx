"use client";

import { useState, useCallback } from "react";
import { Copy, Check } from "lucide-react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vs, vscDarkPlus } from "react-syntax-highlighter/dist/esm/styles/prism";
import { Button } from "@/components/ui/button";
import { useTheme } from "@/contexts";

const supportedLanguages: string[] =
  (SyntaxHighlighter as unknown as { supportedLanguages?: string[] }).supportedLanguages ?? [];

interface CodeBlockProps {
  code: string;
  /** Shown as the block's label. Highlighted when Prism knows it; plain text otherwise. */
  language?: string;
}

export function CodeBlock({ code, language = "bash" }: CodeBlockProps) {
  const [copied, setCopied] = useState(false);
  const { resolvedTheme } = useTheme();
  const isDark = resolvedTheme === "dark";

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback: select text
    }
  }, [code]);

  return (
    <div className="relative group rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)]">
      {language && (
        <div className="px-3 py-1 text-[10px] uppercase tracking-wider text-[var(--sg-text-dim)] border-b border-[var(--sg-border)]">
          {language}
        </div>
      )}
      {supportedLanguages.includes(language) ? (
        <SyntaxHighlighter
          language={language}
          style={isDark ? vscDarkPlus : vs}
          wrapLongLines={false}
          customStyle={{
            margin: 0,
            padding: "0.75rem",
            border: "none",
            background: "transparent",
            backgroundColor: "transparent",
            fontSize: "0.875rem",
            lineHeight: "1.5",
          }}
          codeTagProps={{ style: { fontFamily: "var(--font-mono, ui-monospace, monospace)" } }}
        >
          {code}
        </SyntaxHighlighter>
      ) : (
        <pre className="p-3 overflow-x-auto text-sm font-mono text-[var(--sg-text)]">
          <code>{code}</code>
        </pre>
      )}
      <Button
        variant="ghost"
        size="sm"
        onClick={handleCopy}
        className="absolute top-1 right-1 h-7 w-7 p-0 opacity-100 lg:opacity-0 lg:group-hover:opacity-100 transition-opacity"
        aria-label="Copy to clipboard"
      >
        {copied ? (
          <Check className="h-3.5 w-3.5 text-[var(--sg-success)]" />
        ) : (
          <Copy className="h-3.5 w-3.5" />
        )}
      </Button>
    </div>
  );
}

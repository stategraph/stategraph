"use client";

import { useMemo } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import {
  vs,
  vscDarkPlus,
} from "react-syntax-highlighter/dist/esm/styles/prism";
import { CopyButton } from "@/components/ui/copy-button";
import { useTheme } from "@/contexts/ThemeContext";
import { cn } from "@/lib/utils";
import { HIGHLIGHT_MAX_CHARS } from "@/lib/wm/outputSize";

export type LineKind = "create" | "destroy" | "update" | "replace" | "comment" | null;

export interface ClassifiedLine {
  text: string;
  kind: LineKind;
}

const REPLACE_RE = /^\s*[-+]\/[+-]/;

export function classifyLine(line: string): ClassifiedLine {
  if (REPLACE_RE.test(line)) return { text: line, kind: "replace" };
  const m = line.match(/^\s*(\S)/);
  if (!m) return { text: line, kind: null };
  switch (m[1]) {
    case "+":
      return { text: line, kind: "create" };
    case "-":
      return { text: line, kind: "destroy" };
    case "~":
      return { text: line, kind: "update" };
    case "#":
      return { text: line, kind: "comment" };
    default:
      return { text: line, kind: null };
  }
}

// Per-line tints sit under Prism's token colors. Dark mode needs higher alpha
// to remain visible against the near-black codeblock surface; light mode keeps
// them muted so they don't drown the HCL syntax.
const LINE_BG_LIGHT: Record<NonNullable<LineKind>, string | undefined> = {
  create: "rgba(34, 197, 94, 0.10)",
  update: "rgba(234, 179, 8, 0.10)",
  replace: "rgba(249, 115, 22, 0.10)",
  destroy: "rgba(239, 68, 68, 0.10)",
  comment: undefined,
};

const LINE_BG_DARK: Record<NonNullable<LineKind>, string | undefined> = {
  create: "rgba(34, 197, 94, 0.18)",
  update: "rgba(234, 179, 8, 0.18)",
  replace: "rgba(249, 115, 22, 0.18)",
  destroy: "rgba(239, 68, 68, 0.18)",
  comment: undefined,
};

interface PlanOutputProps {
  text: string;
  className?: string;
  copyable?: boolean;
}

export function PlanOutput({ text, className, copyable = true }: PlanOutputProps) {
  // [lineProps] is called with a 1-based line number; pre-split so the
  // classifier can map a line number back to its source line.
  const lines = useMemo(() => text.split("\n"), [text]);
  const { resolvedTheme } = useTheme();
  const isDark = resolvedTheme === "dark";
  const lineBg = isDark ? LINE_BG_DARK : LINE_BG_LIGHT;

  return (
    <div
      className={cn(
        "m-4 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-1)] shadow-sm overflow-hidden",
        className,
      )}
    >
      {copyable && (
        <div className="flex items-center justify-end px-2 py-1 border-b border-[var(--sg-border-light)] bg-[var(--sg-bg-2)]">
          <CopyButton text={text} />
        </div>
      )}
      {/* Past the highlight cap the text renders as tinted plain lines; the
          per-line add/change/destroy colors, the part a reader needs, stay. */}
      {text.length > HIGHLIGHT_MAX_CHARS ? (
        <pre className="text-xs font-mono leading-normal p-4 overflow-x-auto">
          {lines.map((line, i) => {
            const kind = classifyLine(line).kind;
            const bg = kind ? lineBg[kind] : undefined;
            return (
              <span
                key={i}
                style={{ display: "block", backgroundColor: bg, marginLeft: "-1rem", marginRight: "-1rem", paddingLeft: "1rem", paddingRight: "1rem" }}
              >
                {line || " "}
              </span>
            );
          })}
        </pre>
      ) : (
      <SyntaxHighlighter
        language="hcl"
        style={isDark ? vscDarkPlus : vs}
        wrapLines
        wrapLongLines={false}
        lineProps={(lineNumber: number) => {
          const line = lines[lineNumber - 1] ?? "";
          const kind = classifyLine(line).kind;
          const bg = kind ? lineBg[kind] : undefined;
          // Negative margin + padding bleeds the tint past the customStyle
          // padding to the edges of the scrollable area.
          return {
            style: {
              display: "block",
              backgroundColor: bg,
              marginLeft: "-1rem",
              marginRight: "-1rem",
              paddingLeft: "1rem",
              paddingRight: "1rem",
            },
          };
        }}
        customStyle={{
          margin: 0,
          padding: "1rem",
          // The light (vs) theme sets the pre's `backgroundColor` (longhand)
          // while the dark (vsc-dark-plus) theme uses `background` (shorthand).
          // Switching themes — including the initial light→dark resolve on
          // mount — would otherwise make React remove one while the other is
          // set, which it warns about. Pin both to transparent so the property
          // set is identical across themes and neither is ever removed.
          background: "transparent",
          backgroundColor: "transparent",
          fontSize: "0.75rem",
          lineHeight: "1.5",
        }}
        codeTagProps={{
          style: { fontFamily: "var(--font-mono, ui-monospace, monospace)" },
        }}
      >
        {text}
      </SyntaxHighlighter>
      )}
    </div>
  );
}

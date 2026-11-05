"use client";

import { memo, useMemo } from "react";
import DOMPurify from "dompurify";
import { marked } from "marked";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vs, vscDarkPlus } from "react-syntax-highlighter/dist/esm/styles/prism";
import { useTheme } from "@/contexts";
import { normalizeLang, type OutputFormat } from "@/lib/wm/outputFormat";
import { HIGHLIGHT_MAX_CHARS } from "@/lib/wm/outputSize";

const supportedLanguages: string[] =
  (SyntaxHighlighter as unknown as { supportedLanguages?: string[] }).supportedLanguages ?? [];

// Step output is printed by whatever the run executed, PR-branch scripts
// included. Keep markdown's structure but drop styling, forms and controls,
// which could restyle the console or pose as its UI, and open links outside
// it. A dedicated instance, created on first use (there is no window during
// the static prerender), keeps the link hook off any other DOMPurify user.
let purifier: ReturnType<typeof DOMPurify> | null = null;
function sanitizeMarkdown(html: string): string {
  if (!purifier) {
    purifier = DOMPurify(window);
    purifier.addHook("afterSanitizeAttributes", (node) => {
      if (node.tagName === "A") {
        node.setAttribute("target", "_blank");
        node.setAttribute("rel", "noopener noreferrer");
      }
    });
  }
  return purifier.sanitize(html, {
    FORBID_TAGS: ["style", "form", "input", "button", "textarea", "select"],
    FORBID_ATTR: ["style"],
  });
}

interface FormattedOutputProps {
  text: string;
  format: OutputFormat;
}

const sameLang = (a: OutputFormat, b: OutputFormat): boolean =>
  (a.kind === "code" ? a.lang : "") === (b.kind === "code" ? b.lang : "");

/** Render a step output per its declared format: sanitized markdown, a
 *  highlighted code block, or plain text. Rendering failures, unknown
 *  languages and code past the highlight cap degrade to plain text. Memoized
 *  on the text and format fields: a live run re-renders every poll with a
 *  freshly parsed format, and re-highlighting unchanged text each time is the
 *  expensive part. */
export const FormattedOutput = memo(
  FormattedOutputImpl,
  (a, b) => a.text === b.text && a.format.kind === b.format.kind && sameLang(a.format, b.format),
);

function FormattedOutputImpl({ text, format }: FormattedOutputProps) {
  const { resolvedTheme } = useTheme();
  const isDark = resolvedTheme === "dark";

  const markdownHtml = useMemo(() => {
    if (format.kind !== "markdown" || !text) return "";
    try {
      return sanitizeMarkdown(marked.parse(text, { async: false }));
    } catch (e) {
      console.error("markdown render failed", e);
      return "";
    }
  }, [format.kind, text]);

  if (format.kind === "markdown" && markdownHtml) {
    return (
      <div
        className="output-markdown text-sm p-3 overflow-x-auto"
        dangerouslySetInnerHTML={{ __html: markdownHtml }}
      />
    );
  }

  const lang = format.kind === "code" ? normalizeLang(format.lang) : "";
  if (lang && lang !== "text" && supportedLanguages.includes(lang) && text.length <= HIGHLIGHT_MAX_CHARS) {
    return (
      <SyntaxHighlighter
        language={lang}
        style={isDark ? vscDarkPlus : vs}
        wrapLongLines={false}
        customStyle={{
          margin: 0,
          padding: "0.75rem",
          // Pin both properties transparent so the set is identical across
          // themes and React never has to remove one (see PlanOutput).
          background: "transparent",
          backgroundColor: "transparent",
          fontSize: "0.75rem",
          lineHeight: "1.5",
        }}
        codeTagProps={{ style: { fontFamily: "var(--font-mono, ui-monospace, monospace)" } }}
      >
        {text}
      </SyntaxHighlighter>
    );
  }

  return (
    <pre className="text-xs font-mono whitespace-pre-wrap p-3 text-[var(--sg-text-muted)] overflow-x-auto">
      {text}
    </pre>
  );
}

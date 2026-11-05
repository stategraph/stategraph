/**
 * Size gating for step output rendering.
 *
 * Terraform plans routinely reach megabytes; pushing that much text through a
 * syntax highlighter in one pass can freeze the tab. These tiers match the
 * iris console (SafeOutput.svelte) so both UIs degrade the same way:
 * small content renders immediately, larger content renders behind an
 * explicit click, and huge content is download-only.
 */

export type SizeTier = "auto" | "warn" | "explicit" | "blocked";

const AUTO_MAX = 1_000_000; // 1MB: render immediately
const WARN_MAX = 5_000_000; // 5MB: warn, render on request
const EXPLICIT_MAX = 20_000_000; // 20MB: explicit load only; above: download only

export function sizeTier(chars: number): SizeTier {
  if (chars <= AUTO_MAX) return "auto";
  if (chars <= WARN_MAX) return "warn";
  if (chars <= EXPLICIT_MAX) return "explicit";
  return "blocked";
}

/** Above this many characters, output is rendered as plain lines instead of
 *  going through Prism. Tokenizing a multi-hundred-KB text builds a DOM node
 *  per token and can lock up the tab, well below the size tiers above. */
export const HIGHLIGHT_MAX_CHARS = 150_000;

const PREVIEW_LINES = 5000;
const PREVIEW_CHARS = 1_000_000;

/** First 5000 lines (or 1MB of characters) with an explicit truncation notice,
 *  so a preview never carries the full rendering cost. */
export function previewOf(content: string): { text: string; truncated: boolean } {
  const lines = content.split("\n");
  if (lines.length > PREVIEW_LINES) {
    return {
      text: lines.slice(0, PREVIEW_LINES).join("\n") +
        `\n\n... (truncated, showing first ${PREVIEW_LINES} lines)`,
      truncated: true,
    };
  }
  if (content.length > PREVIEW_CHARS) {
    return { text: content.substring(0, PREVIEW_CHARS) + "\n\n... (truncated)", truncated: true };
  }
  return { text: content, truncated: false };
}

export function formatSize(chars: number): string {
  if (chars < 1024) return `${chars} characters`;
  if (chars < 1024 * 1024) return `${(chars / 1024).toFixed(1)}KB`;
  return `${(chars / (1024 * 1024)).toFixed(1)}MB`;
}

/**
 * Rendering format of a workflow step output.
 *
 * A step payload may carry a `format` key, set from the `format:` field of a
 * `run` step in the workflow config. This mirrors `output_of_run` in
 * code/src/terrat_vcs_github_comment/terrat_vcs_github_comment_publishers.ml so
 * that the console and the pull request comment render the same payload the
 * same way.
 *
 * Accepted shapes (see hook-op-run-format in api_schemas/terrat/config-schema.json):
 *   "code"                      -> plain code block
 *   "raw" | "markdown"          -> rendered as markdown
 *   { type: "code", lang: "x" } -> code block highlighted as "x"
 * Anything unrecognized falls back to a plain code block.
 */

export type OutputFormat =
  | { kind: "text" }
  | { kind: "code"; lang: string }
  | { kind: "markdown" };

export const TEXT_FORMAT: OutputFormat = { kind: "text" };

export function parseOutputFormat(format: unknown): OutputFormat {
  if (format === "raw" || format === "markdown") return { kind: "markdown" };
  if (format && typeof format === "object" && !Array.isArray(format)) {
    const lang = (format as { lang?: unknown }).lang;
    if (typeof lang === "string" && lang !== "") return { kind: "code", lang };
  }
  return TEXT_FORMAT;
}

/** Workflow configs use common shorthand names; Prism registers canonical
 *  names only, so map the aliases before the supported-language check. */
const LANG_ALIASES: Record<string, string> = {
  sh: "bash",
  shell: "bash",
  zsh: "bash",
  py: "python",
  yml: "yaml",
  tf: "hcl",
  terraform: "hcl",
  dockerfile: "docker",
  golang: "go",
  rb: "ruby",
  ps1: "powershell",
  plaintext: "text",
  plain: "text",
  txt: "text",
};

export function normalizeLang(lang: string): string {
  const l = lang.trim().toLowerCase();
  return LANG_ALIASES[l] ?? l;
}

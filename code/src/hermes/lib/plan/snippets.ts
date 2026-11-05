import { stripStateWrapper } from "./tree";

/**
 * Slice [plan_stdout] (the verbatim `tofu plan` output) into a map of
 * `address → snippet`. Used by the tree view to show the per-resource block
 * in a side panel on click.
 *
 * Each block starts with a header line of the shape
 *
 *     `  # <address> will be|must be|is …`
 *
 * and runs until the next such header or the trailing `Plan: …` summary.
 * Other `  # (because …)` notes that terraform emits don't open a new block,
 * so we require the address to be followed by a state verb.
 *
 * Keys are stored with stategraph's synthetic `module.state_<hex>.` wrapper
 * stripped, so a tree node id (which is already stripped) matches directly.
 */
export function parsePlanStdoutByAddress(stdout: string | null | undefined): Map<string, string> {
  const result = new Map<string, string>();
  if (!stdout) return result;

  // The leading `  # ` is two spaces then a hash then a space.
  // The address character class accepts letters, digits, dots, underscores,
  // brackets, hyphens, and quotes (for `["key"]`-style indices).
  const headerRe = /^ {2}# ([A-Za-z_][\w.[\]"\-]*)\s+(will be|must be|is\b)/;

  const lines = stdout.split("\n");
  let curKey: string | null = null;
  let buf: string[] = [];

  const flush = () => {
    if (curKey !== null) result.set(curKey, buf.join("\n"));
    curKey = null;
    buf = [];
  };

  for (const line of lines) {
    // The summary line terminates the resource section.
    if (/^Plan:\s/.test(line) || /^No changes\./.test(line)) {
      flush();
      break;
    }
    const m = line.match(headerRe);
    if (m) {
      flush();
      curKey = stripStateWrapper(m[1]);
      buf = [line];
      continue;
    }
    if (curKey !== null) buf.push(line);
  }
  flush();
  return result;
}

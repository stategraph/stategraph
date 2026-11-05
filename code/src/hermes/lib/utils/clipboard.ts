/** Copy to the clipboard with a document.execCommand fallback for non-secure
 *  origins (self-hosted plain-HTTP deployments have no navigator.clipboard).
 *  Returns whether the copy succeeded so the caller can surface failure —
 *  shown-once secrets make a silent no-op costly. */
export async function copyText(text: string): Promise<boolean> {
  if (typeof navigator !== "undefined" && navigator.clipboard) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      /* fall through to the legacy path */
    }
  }
  if (typeof document === "undefined") return false;
  // The scratch textarea holds the secret: it must leave the DOM (and be
  // emptied) whether execCommand returns, returns false, or throws.
  const ta = document.createElement("textarea");
  try {
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    return document.execCommand("copy");
  } catch {
    return false;
  } finally {
    ta.value = "";
    ta.remove();
  }
}

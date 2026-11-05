/**
 * A transaction's apply output as `GET /api/v1/tx/{tx_id}/output` serves it:
 * stored chunk rows the client reassembles -- base64-decode each `data`,
 * concatenate the fragments in ascending `idx`, JSON-parse -- into the payload
 * the page's `payload` field names. Two shapes exist: the stdout of a completed
 * apply (a JSON string), or the run-failure record of an apply that did not
 * complete (a refused run included). Each chunk decodes on its own (the cuts
 * fall between codepoints and outside escapes), which is what will let a
 * viewer show fragments as they arrive.
 */

import type { RunFailure, TxOutputChunk, TxOutputPayloadKind } from "@/lib/api/client";

export type TxOutput =
  | { kind: "apply_stdout"; text: string }
  | { kind: "run_failure"; failure: RunFailure };

function bytesOfBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

/**
 * Rebuild the payload from its chunk rows: decode each, concatenate the bytes
 * in idx order, decode the UTF-8 once. Throws on malformed base64 or JSON,
 * i.e. when not every row was fetched.
 */
export function reassembleTxOutput(chunks: readonly TxOutputChunk[]): unknown {
  const parts = [...chunks].sort((a, b) => a.idx - b.idx).map((c) => bytesOfBase64(c.data));
  const bytes = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  parts.reduce((at, p) => {
    bytes.set(p, at);
    return at + p.length;
  }, 0);
  return JSON.parse(new TextDecoder().decode(bytes));
}

function isRunFailure(v: unknown): v is RunFailure {
  if (typeof v !== "object" || v === null) return false;
  const o = v as { kind?: unknown; reason?: unknown };
  return o.kind === "failure" && typeof o.reason === "object" && o.reason !== null;
}

/** Reassemble the chunks and check they are the shape `kind` announced. */
export function decodeTxOutput(kind: TxOutputPayloadKind, chunks: readonly TxOutputChunk[]): TxOutput {
  const payload = reassembleTxOutput(chunks);
  switch (kind) {
    case "apply_stdout":
      if (typeof payload !== "string") throw new Error("apply_stdout payload is not a JSON string");
      return { kind, text: payload };
    case "run_failure":
      if (!isRunFailure(payload)) throw new Error("run_failure payload is not a run-failure record");
      return { kind, failure: payload };
  }
}

/**
 * The text a failure carries when it happened inside a terraform phase (init,
 * plan, show -json, apply): stderr first, since that is where tofu puts the
 * error, then stdout. Null for the reasons that carry none. Blank lines that
 * only pad the text at either end are dropped (tofu opens its error block
 * with one), so the first line shown is the error itself.
 */
export function failureOutputText(failure: RunFailure): string | null {
  const r = failure.reason as { stdout?: unknown; stderr?: unknown };
  const parts = [r.stderr, r.stdout].filter(
    (t): t is string => typeof t === "string" && t.length > 0
  );
  if (parts.length === 0) return null;
  const text = trimBlankLines(parts.join("\n"));
  return text.length > 0 ? text : null;
}

function isBlank(line: string): boolean {
  return line.trim().length === 0;
}

/**
 * `text` without the whitespace-only lines that pad it at either end. Walks in
 * from each end over those lines only, so an output of thousands of lines costs
 * what its padding costs, and takes a single slice.
 */
function trimBlankLines(text: string): string {
  let start = 0;
  for (;;) {
    const nl = text.indexOf("\n", start);
    if (nl === -1 || !isBlank(text.slice(start, nl))) break;
    start = nl + 1;
  }
  let end = text.length;
  for (;;) {
    const nl = text.lastIndexOf("\n", end - 1);
    if (nl < start || !isBlank(text.slice(nl + 1, end))) break;
    end = nl;
  }
  return text.slice(start, end);
}

const FAILURE_LABELS: Partial<Record<RunFailure["reason"]["kind"], string>> = {
  apply: "Apply failed",
  plan: "Plan failed",
  init: "Init failed",
  show_json: "Reading the plan failed",
  capability_denied: "Run refused: capability denied",
  tx_conflict: "Transaction conflict",
  tx_invalid_state: "Transaction was not in a state that allows this run",
  tf_binary_not_found: "terraform/tofu binary not found",
  state_schema_behind: "State schema behind this server",
};

/** A short human label for a failure, from its reason. */
export function failureLabel(failure: RunFailure): string {
  return FAILURE_LABELS[failure.reason.kind] ?? `Run failed (${failure.reason.kind})`;
}

/**
 * The trailing `n` non-blank lines of `text` as one snippet, and whether that
 * left any line out. Most terraform failures put the real error in the last
 * handful of lines, so a banner shows the tail; blank lines are dropped so
 * they do not eat into the budget.
 */
export function outputTail(text: string, n: number): { snippet: string; truncated: boolean } {
  const lines = text.split("\n").filter((line) => line.trim().length > 0);
  return { snippet: lines.slice(-n).join("\n"), truncated: lines.length > n };
}

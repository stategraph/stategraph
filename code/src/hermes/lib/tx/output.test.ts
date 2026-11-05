import assert from "node:assert";
import type { RunFailure } from "@/lib/api/client";
import { decodeTxOutput, failureLabel, failureOutputText, outputTail, reassembleTxOutput } from "./output";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

/** Encode a payload the way the server stores it: the JSON text cut into
 *  `size`-byte fragments, each base64-encoded on its own; shuffled so order is
 *  not assumed. The server cuts between codepoints; the reader must not depend
 *  on it, so the cuts here are blind. */
function chunksOf(payload: unknown, size: number) {
  const bytes = Buffer.from(JSON.stringify(payload), "utf8");
  const chunks = [];
  for (let idx = 0, at = 0; at < bytes.length; idx++, at += size) {
    chunks.push({ idx, data: bytes.subarray(at, at + size).toString("base64") });
  }
  return chunks.reverse();
}

const applyFailure: RunFailure = {
  kind: "failure",
  reason: { kind: "apply", stdout: "null_resource.x: Creating...", stderr: "Error: exit status 1" },
};

test("reassemble: chunks cut mid-quad, out of order, non-ASCII", () => {
  const text = "Apply complete! Resources: 1 added — é☃";
  const chunks = chunksOf(text, 7);
  assert.ok(chunks.length > 2);
  assert.equal(reassembleTxOutput(chunks), text);
});

test("reassemble: a missing chunk does not decode into a plausible value", () => {
  assert.throws(() => reassembleTxOutput(chunksOf({ kind: "failure" }, 5).slice(1)));
});

test("reassemble: a chunk cut through a codepoint still concatenates to the text", () => {
  const text = "☃☃☃";
  assert.equal(reassembleTxOutput(chunksOf(text, 2)), text);
});

test("decode: apply_stdout", () => {
  assert.deepEqual(decodeTxOutput("apply_stdout", chunksOf("ok", 1000)), { kind: "apply_stdout", text: "ok" });
});

test("decode: run_failure", () => {
  assert.deepEqual(decodeTxOutput("run_failure", chunksOf(applyFailure, 9)), { kind: "run_failure", failure: applyFailure });
});

test("decode: a payload that is not what the page announced is an error, never a guess", () => {
  assert.throws(() => decodeTxOutput("apply_stdout", chunksOf(applyFailure, 1000)));
  assert.throws(() => decodeTxOutput("run_failure", chunksOf("text", 1000)));
});

test("failure text: terraform-phase reasons carry stderr then stdout, others nothing", () => {
  assert.equal(failureOutputText(applyFailure), "Error: exit status 1\nnull_resource.x: Creating...");
  assert.equal(failureOutputText({ kind: "failure", reason: { kind: "tx_conflict", conflicting_tx_ids: [] } }), null);
});

test("failure text: padding blank lines are dropped, inner ones kept", () => {
  const padded: RunFailure = {
    kind: "failure",
    reason: { kind: "apply", stderr: "\nError: exit status 1\n\n  with null_resource.x,\n", stdout: "" },
  };
  assert.equal(failureOutputText(padded), "Error: exit status 1\n\n  with null_resource.x,");
  assert.equal(failureOutputText({ kind: "failure", reason: { kind: "apply", stderr: "\n \n", stdout: "" } }), null);
});

test("failure label: known reasons are named, unknown ones still say the kind", () => {
  assert.equal(failureLabel(applyFailure), "Apply failed");
  assert.equal(failureLabel({ kind: "failure", reason: { kind: "read" } }), "Run failed (read)");
});

test("output tail: a short output is shown whole and is not truncated", () => {
  assert.deepEqual(outputTail("a\nb\nc", 16), { snippet: "a\nb\nc", truncated: false });
  assert.deepEqual(outputTail("a\nb\nc", 3), { snippet: "a\nb\nc", truncated: false });
});

test("output tail: a long output keeps its last n lines and is truncated", () => {
  const lines = Array.from({ length: 20 }, (_, i) => `line ${i + 1}`);
  const tail = outputTail(lines.join("\n"), 16);
  assert.equal(tail.truncated, true);
  assert.deepEqual(tail.snippet.split("\n"), lines.slice(4));
});

test("output tail: blank lines neither count nor appear", () => {
  assert.deepEqual(outputTail("\n\na\n   \nb\n\n", 2), { snippet: "a\nb", truncated: false });
  assert.deepEqual(outputTail("x\n\ny\n\nz\n", 2), { snippet: "y\nz", truncated: true });
});

if (failures > 0) {
  console.error(`${failures} test(s) failed`);
  process.exit(1);
}
console.log("All tx output tests passed");

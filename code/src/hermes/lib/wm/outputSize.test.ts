import assert from "node:assert";
import { formatSize, previewOf, sizeTier } from "./outputSize";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("sizeTier boundaries", () => {
  assert.equal(sizeTier(0), "auto");
  assert.equal(sizeTier(1_000_000), "auto");
  assert.equal(sizeTier(1_000_001), "warn");
  assert.equal(sizeTier(5_000_000), "warn");
  assert.equal(sizeTier(5_000_001), "explicit");
  assert.equal(sizeTier(20_000_000), "explicit");
  assert.equal(sizeTier(20_000_001), "blocked");
});

test("previewOf leaves small content untouched", () => {
  const p = previewOf("a\nb\nc");
  assert.equal(p.text, "a\nb\nc");
  assert.equal(p.truncated, false);
});

test("previewOf cuts at 5000 lines", () => {
  const content = Array.from({ length: 6001 }, (_, i) => `line${i}`).join("\n");
  const p = previewOf(content);
  assert.equal(p.truncated, true);
  const lines = p.text.split("\n");
  assert.equal(lines[4999], "line4999");
  assert.ok(p.text.includes("truncated, showing first 5000 lines"));
});

test("previewOf cuts at 1MB of characters", () => {
  const content = "x".repeat(1_000_001);
  const p = previewOf(content);
  assert.equal(p.truncated, true);
  assert.ok(p.text.length < content.length + 100);
  assert.ok(p.text.endsWith("... (truncated)"));
});

test("formatSize units", () => {
  assert.equal(formatSize(500), "500 characters");
  assert.equal(formatSize(2048), "2.0KB");
  assert.equal(formatSize(1_500_000), "1.4MB");
});

if (failures > 0) process.exit(1);

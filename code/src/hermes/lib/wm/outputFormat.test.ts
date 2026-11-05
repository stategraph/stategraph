import assert from "node:assert";
import { normalizeLang, parseOutputFormat, TEXT_FORMAT } from "./outputFormat";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("raw and markdown strings render as markdown", () => {
  assert.deepEqual(parseOutputFormat("raw"), { kind: "markdown" });
  assert.deepEqual(parseOutputFormat("markdown"), { kind: "markdown" });
});

test("the bare 'code' string is a plain code block", () => {
  assert.deepEqual(parseOutputFormat("code"), TEXT_FORMAT);
});

test("an object with a non-empty lang is a highlighted code block", () => {
  assert.deepEqual(parseOutputFormat({ type: "code", lang: "python" }), { kind: "code", lang: "python" });
  assert.deepEqual(parseOutputFormat({ lang: "json" }), { kind: "code", lang: "json" });
});

test("unrecognized shapes fall back to plain text", () => {
  assert.deepEqual(parseOutputFormat({ lang: "" }), TEXT_FORMAT);
  assert.deepEqual(parseOutputFormat({ lang: 42 }), TEXT_FORMAT);
  assert.deepEqual(parseOutputFormat(null), TEXT_FORMAT);
  assert.deepEqual(parseOutputFormat(undefined), TEXT_FORMAT);
  assert.deepEqual(parseOutputFormat(42), TEXT_FORMAT);
  assert.deepEqual(parseOutputFormat(["markdown"]), TEXT_FORMAT);
  assert.deepEqual(parseOutputFormat("unknown"), TEXT_FORMAT);
});

test("normalizeLang maps aliases and lowercases", () => {
  assert.equal(normalizeLang("sh"), "bash");
  assert.equal(normalizeLang("Shell"), "bash");
  assert.equal(normalizeLang("YML"), "yaml");
  assert.equal(normalizeLang("tf"), "hcl");
  assert.equal(normalizeLang("terraform"), "hcl");
  assert.equal(normalizeLang("py"), "python");
  assert.equal(normalizeLang(" golang "), "go");
  assert.equal(normalizeLang("json"), "json");
  assert.equal(normalizeLang("plaintext"), "text");
});

if (failures > 0) process.exit(1);

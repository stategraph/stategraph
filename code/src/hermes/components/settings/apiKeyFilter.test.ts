import assert from "node:assert";
import type { AccessTokenSummary } from "@/lib/api/client";
import { filterApiKeys } from "./apiKeyFilter";

function token(
  name: string,
  ownerName: string,
  ownerType: AccessTokenSummary["owner_type"] = "user",
): AccessTokenSummary {
  return {
    id: `id-${name}`,
    name,
    created_at: "2026-10-06T00:00:00Z",
    owner_id: `owner-${ownerName}`,
    owner_name: ownerName,
    owner_type: ownerType,
  };
}

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`);
  }
}

const KEYS = [
  token("ci-deploy", "Ada Lovelace"),
  token("my-laptop", "Grace Hopper", "api"),
  token("Backup", "cyberdyne/hal", "system"),
];

test("an empty search keeps every key, in order", () => {
  assert.deepEqual(filterApiKeys(KEYS, "").map((t) => t.name), ["ci-deploy", "my-laptop", "Backup"]);
});

test("a whitespace-only search keeps every key", () => {
  assert.equal(filterApiKeys(KEYS, "   ").length, KEYS.length);
});

test("matches the key name case-insensitively", () => {
  assert.deepEqual(filterApiKeys(KEYS, "CI-").map((t) => t.name), ["ci-deploy"]);
  assert.deepEqual(filterApiKeys(KEYS, "backup").map((t) => t.name), ["Backup"]);
});

test("matches the owner name case-insensitively", () => {
  assert.deepEqual(filterApiKeys(KEYS, "hopper").map((t) => t.name), ["my-laptop"]);
  assert.deepEqual(filterApiKeys(KEYS, "HAL").map((t) => t.name), ["Backup"]);
});

test("a key matching on name OR owner is included", () => {
  assert.deepEqual(filterApiKeys(KEYS, "a").map((t) => t.name), ["ci-deploy", "my-laptop", "Backup"]);
});

test("the search is trimmed before matching", () => {
  assert.deepEqual(filterApiKeys(KEYS, "  ci-deploy  ").map((t) => t.name), ["ci-deploy"]);
});

test("no match yields an empty list", () => {
  assert.deepEqual(filterApiKeys(KEYS, "nonexistent"), []);
});

test("the input list is never mutated", () => {
  const before = KEYS.map((t) => t.name);
  filterApiKeys(KEYS, "ci");
  filterApiKeys(KEYS, "");
  assert.deepEqual(KEYS.map((t) => t.name), before);
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed`);
  process.exit(1);
}
console.log("\nall apiKeyFilter tests passed");

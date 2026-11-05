import assert from "node:assert";
import { matchesSearch } from "./search";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("a blank query matches everything, even a row with no fields", () => {
  assert.equal(matchesSearch("", "acme/infra"), true);
  assert.equal(matchesSearch("   ", "acme/infra"), true);
  assert.equal(matchesSearch(""), true);
});

test("a non-blank query matches nothing without fields", () => {
  assert.equal(matchesSearch("acme"), false);
});

test("substring match, case-insensitive both ways", () => {
  assert.equal(matchesSearch("INFRA", "acme/infra"), true);
  assert.equal(matchesSearch("infra", "Acme/INFRA"), true);
  assert.equal(matchesSearch("prod", "acme/infra"), false);
});

test("the query is trimmed, inner whitespace is kept", () => {
  assert.equal(matchesSearch("  acme/infra  ", "acme/infra"), true);
  assert.equal(matchesSearch("acme infra", "acme/infra"), false);
});

test("any field may match", () => {
  assert.equal(matchesSearch("hopper", "my-laptop", "Grace Hopper"), true);
  assert.equal(matchesSearch("laptop", "my-laptop", "Grace Hopper"), true);
  assert.equal(matchesSearch("hal", "my-laptop", "Grace Hopper"), false);
});

test("fields are matched one by one, a query does not span two of them", () => {
  assert.equal(matchesSearch("laptop Grace", "my-laptop", "Grace Hopper"), false);
});

test("a caller-joined field lets one query span values", () => {
  assert.equal(matchesSearch("acme/infra #12", "acme/infra #12 Fix drift"), true);
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed`);
  process.exit(1);
}
console.log("\nall search tests passed");

import assert from "node:assert";
import { sqlLiteral } from "./escape";

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

test("wraps in single quotes", () => {
  assert.equal(sqlLiteral("dev"), "'dev'");
});
test("doubles embedded single quotes", () => {
  assert.equal(sqlLiteral("o'brien"), "'o''brien'");
  assert.equal(sqlLiteral("''"), "''''''");
});
test("leaves double quotes and backslashes alone", () => {
  assert.equal(sqlLiteral('a"b\\c'), "'a\"b\\c'");
});
test("empty string is an empty literal", () => {
  assert.equal(sqlLiteral(""), "''");
});

if (failures > 0) process.exit(1);

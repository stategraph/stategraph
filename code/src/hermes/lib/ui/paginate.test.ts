import assert from "node:assert";
import { pageBounds } from "./paginate";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("first page of many", () => {
  const b = pageBounds(95, 1, 25);
  assert.deepEqual([b.totalPages, b.page, b.start, b.end], [4, 1, 0, 25]);
  assert.equal(b.hasPrevious, false);
  assert.equal(b.hasNext, true);
});
test("last partial page", () => {
  const b = pageBounds(95, 4, 25);
  assert.deepEqual([b.page, b.start, b.end], [4, 75, 95]);
  assert.equal(b.hasNext, false);
  assert.equal(b.hasPrevious, true);
});
test("page beyond range clamps to last", () => {
  const b = pageBounds(30, 9, 25);
  assert.equal(b.page, 2);
  assert.equal(b.hasNext, false);
});
test("empty set -> one page, no rows", () => {
  const b = pageBounds(0, 1, 25);
  assert.deepEqual([b.totalPages, b.start, b.end, b.hasNext, b.hasPrevious], [1, 0, 0, false, false]);
});
test("exactly one full page", () => {
  const b = pageBounds(25, 1, 25);
  assert.equal(b.totalPages, 1);
  assert.equal(b.hasNext, false);
});
test("page 0 / negative clamps to 1", () => {
  assert.equal(pageBounds(50, 0, 25).page, 1);
  assert.equal(pageBounds(50, -3, 25).page, 1);
});

if (failures > 0) { console.error(`\n${failures} test(s) failed`); process.exit(1); }
else console.log("\nall paginate tests passed");

import assert from "node:assert";
import { outputFilename } from "./download";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("joins the parts in order with the step slashes flattened", () => {
  const name = outputFilename({ repo: "acme/infra", pullNumber: "42", runType: "plan", step: "tf/plan" });
  assert.match(name, /^acme_infra_PR42_plan_tf_plan_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.txt$/);
});

test("sanitizes every character outside [a-zA-Z0-9-_]", () => {
  const name = outputFilename({ repo: "a b:c", step: "run" });
  assert.ok(!/[^a-zA-Z0-9\-_.]/.test(name), name);
});

test("empty parts still produce a timestamped .txt name", () => {
  const name = outputFilename({});
  assert.match(name, /^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.txt$/);
});

if (failures > 0) process.exit(1);

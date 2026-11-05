import assert from "node:assert";
import { isResourceAddress } from "./transform";

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

test("plain and module-nested resources are resources", () => {
  assert.equal(isResourceAddress("aws_instance.web"), true);
  assert.equal(isResourceAddress("module.foo.aws_instance.web"), true);
  assert.equal(isResourceAddress("module.foo.module.bar.aws_s3_bucket.b[0]"), true);
});

test("non-resource address kinds are excluded, including module-nested", () => {
  assert.equal(isResourceAddress("terraform"), false);
  assert.equal(isResourceAddress("data.aws_ami.ubuntu"), false);
  assert.equal(isResourceAddress("module.foo.data.aws_ami.ubuntu"), false);
  assert.equal(isResourceAddress("local.x"), false);
  assert.equal(isResourceAddress("var.region"), false);
  assert.equal(isResourceAddress("output.url"), false);
  assert.equal(isResourceAddress("provider.aws"), false);
  assert.equal(isResourceAddress("module.foo.var.region"), false);
});

test("a bare module node is not a resource", () => {
  assert.equal(isResourceAddress("module.foo"), false);
  assert.equal(isResourceAddress("module.foo.module.bar"), false);
});

if (failures > 0) process.exit(1);

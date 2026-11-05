import assert from "node:assert";
import { gitlabRotateErrorMessage } from "./gitlabRotateErrors";

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

/** Build an error shaped like the one thrown by `fetchAPI`. */
function apiError(status: number, message: string): unknown {
  return Object.assign(new Error(message), { status });
}

const message = (err: unknown) => gitlabRotateErrorMessage(err, "Rotation failed.");

test("404 says the group is not connected to this tenant, without claiming another tenant owns it", () => {
  const m = message(apiError(404, "API error: 404 Not Found"));
  assert.ok(m.includes("not connected to this tenant"));
  assert.ok(!m.includes("different tenant"));
});

test("403 names the admin requirement", () => {
  assert.ok(message(apiError(403, "API error: 403 Forbidden")).includes("admin"));
});

test("503 says orchestration is off", () => {
  assert.ok(
    message(apiError(503, "API error: 503 Service Unavailable - PROVISIONING_UNAVAILABLE: ...")).includes(
      "not enabled"
    )
  );
});

test("a network fault says the outcome is unknown", () => {
  assert.ok(message(new TypeError("Failed to fetch")).includes("unknown whether"));
});

test("400 keeps the server's words, which name what is missing", () => {
  const m =
    "API error: 400 Bad Request - GITLAB_ROTATE_INVALID: Provide a non-empty access_token, regenerate_webhook_secret, or both, for a positive group_id.";
  assert.equal(message(apiError(400, m)), m);
});

test("a non-Error throw falls back rather than rendering as [object Object]", () => {
  assert.equal(message({ oops: true }), "Rotation failed.");
  assert.equal(message(null), "Rotation failed.");
});

if (failures > 0) process.exit(1);

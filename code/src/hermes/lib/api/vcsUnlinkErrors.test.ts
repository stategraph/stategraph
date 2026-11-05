import assert from "node:assert";
import { vcsUnlinkErrorMessage } from "./vcsUnlinkErrors";

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

const message = (err: unknown) => vcsUnlinkErrorMessage(err, "Failed to remove the integration.");

test("403 names both requirements, with or without a body", () => {
  assert.ok(message(apiError(403, "API error: 403 Forbidden")).includes("admin and a member"));
  assert.ok(
    message(apiError(403, "API error: 403 Forbidden - TENANT_MEMBERSHIP_REQUIRED")).includes(
      "admin and a member"
    )
  );
});

test("404 says the integration is no longer linked to this tenant", () => {
  assert.ok(message(apiError(404, "API error: 404 Not Found")).includes("no longer linked to this tenant"));
});

test("a network fault says the outcome is unknown", () => {
  assert.ok(message(new TypeError("Failed to fetch")).includes("unknown whether"));
});

test("400 keeps the server's words, which name the provider", () => {
  const m = "API error: 400 Bad Request - VCS_INSTALLATION_INVALID_PROVIDER: provider must be github or gitlab";
  assert.equal(message(apiError(400, m)), m);
});

test("a non-Error throw falls back rather than rendering as [object Object]", () => {
  assert.equal(message({ oops: true }), "Failed to remove the integration.");
  assert.equal(message(null), "Failed to remove the integration.");
});

if (failures > 0) process.exit(1);

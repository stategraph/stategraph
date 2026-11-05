import assert from "node:assert";
import { gitlabProvisionErrorMessage } from "./gitlabProvisionErrors";

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

const message = (err: unknown) => gitlabProvisionErrorMessage(err, "Failed to create the installation.");

test("409 points at rotating the credentials or skipping ahead", () => {
  const m = message(
    apiError(409, "API error: 409 Conflict - GITLAB_ALREADY_PROVISIONED: This GitLab group already has an installation.")
  );
  assert.ok(m.includes("already has an installation"));
  assert.ok(m.includes("rotate its credentials"));
  assert.ok(m.includes("skip ahead"));
  assert.ok(!m.includes("removed on the Stategraph side"));
});

test("503 says orchestration is off", () => {
  assert.ok(
    message(apiError(503, "API error: 503 Service Unavailable - PROVISIONING_UNAVAILABLE: ...")).includes(
      "not enabled on this server"
    )
  );
});

test("403 names the missing capability, even with no body", () => {
  assert.ok(message(apiError(403, "API error: 403 Forbidden")).includes("requires admin"));
});

test("400 keeps the server's words, which name the bad field", () => {
  const m =
    "API error: 400 Bad Request - GITLAB_PROVISION_INVALID: group_id must be a positive integer; name and access_token are required.";
  assert.equal(message(apiError(400, m)), m);
});

test("a network fault says the group may already be connected", () => {
  const m = message(new TypeError("Failed to fetch"));
  assert.ok(m.includes("unknown whether the group was connected"));
  assert.ok(m.includes("rotate its credentials"));
});

test("a status-less failure still reports what threw", () => {
  assert.equal(message(new Error("Failed to fetch")), "Failed to fetch");
});

test("a non-Error throw falls back rather than rendering as [object Object]", () => {
  assert.equal(message({ oops: true }), "Failed to create the installation.");
  assert.equal(message(null), "Failed to create the installation.");
});

if (failures > 0) process.exit(1);

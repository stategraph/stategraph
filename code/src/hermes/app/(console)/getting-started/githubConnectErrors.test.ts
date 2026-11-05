import assert from "node:assert";
import {
  INSTANCE_ADMIN_REQUIRED,
  githubConnectErrorMessage,
  githubConnectRefusal,
  githubSelfServeErrorMessage,
  githubSelfServeRefusal,
} from "./githubConnectErrors";

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
function apiError(status: number, message: string, body: unknown = null): unknown {
  return Object.assign(new Error(message), { status, body });
}

const message = (err: unknown) => githubConnectErrorMessage(err, "Failed to claim the installation.");

test("503 is the orchestration refusal, not a line of error text", () => {
  const err = apiError(503, "API error: 503 Service Unavailable - ORCHESTRATION_UNAVAILABLE: ...");
  assert.equal(githubConnectRefusal(err), "orchestration");
  assert.ok(message(err).includes("not enabled on this server"));
});

test("403 names the missing capability, even with no body", () => {
  const err = apiError(403, "API error: 403 Forbidden");
  assert.equal(githubConnectRefusal(err), "capability");
  assert.equal(message(err), INSTANCE_ADMIN_REQUIRED);
});

test("401 is a lost session, not a capability denial", () => {
  const err = apiError(401, "API error: 401 Unauthorized");
  assert.equal(githubConnectRefusal(err), null);
  assert.ok(!message(err).includes("admin"));
  assert.ok(message(err).includes("session"));
});

test("500 keeps the server's words", () => {
  const m = "API error: 500 Internal Server Error";
  assert.equal(githubConnectRefusal(apiError(500, m)), null);
  assert.equal(message(apiError(500, m)), m);
});

test("a status-less failure still reports what threw", () => {
  assert.equal(githubConnectRefusal(new Error("Failed to fetch")), null);
  assert.equal(message(new Error("Failed to fetch")), "Failed to fetch");
});

test("a non-Error throw falls back rather than rendering as [object Object]", () => {
  assert.equal(message({ oops: true }), "Failed to claim the installation.");
  assert.equal(message(null), "Failed to claim the installation.");
});

const selfServeMessage = (err: unknown) =>
  githubSelfServeErrorMessage(err, "Failed to claim the installation.");

test("self-serve: 503 is the orchestration refusal and 412 the spent proof", () => {
  assert.equal(githubSelfServeRefusal(apiError(503, "API error: 503 Service Unavailable")), "orchestration");
  assert.equal(githubSelfServeRefusal(apiError(412, "API error: 412 Precondition Failed")), "proof");
  assert.equal(githubSelfServeRefusal(apiError(403, "API error: 403 Forbidden")), null);
  assert.equal(githubSelfServeRefusal(apiError(409, "API error: 409 Conflict")), null);
  assert.equal(githubSelfServeRefusal(null), null);
});

test("self-serve: a capability denial asks for tenant admin, not an instance admin", () => {
  const err = apiError(403, "API error: 403 Forbidden - CAPABILITY_UNAUTHORIZED", {
    id: "CAPABILITY_UNAUTHORIZED",
  });
  assert.equal(selfServeMessage(err), "Claiming an installation needs admin on this tenant.");
  assert.notEqual(selfServeMessage(err), INSTANCE_ADMIN_REQUIRED);
});

test("self-serve: the endpoint's own 403 shows the server's sentence, not the raw API error", () => {
  const data = "You have not proven access to that installation.";
  const err = apiError(403, `API error: 403 Forbidden - GITHUB_INSTALLATION_NOT_PROVEN: ${data}`, {
    id: "GITHUB_INSTALLATION_NOT_PROVEN",
    data,
  });
  assert.equal(selfServeMessage(err), data);
});

test("self-serve: a 403 with no body falls back", () => {
  assert.equal(selfServeMessage(apiError(403, "API error: 403 Forbidden")), "Failed to claim the installation.");
});

test("self-serve: 401 is the lost session", () => {
  const err = apiError(401, "API error: 401 Unauthorized");
  assert.equal(selfServeMessage(err), message(err));
});

test("self-serve: anything else falls back rather than showing the raw API error", () => {
  assert.equal(selfServeMessage(apiError(500, "API error: 500 Internal Server Error")), "Failed to claim the installation.");
  assert.equal(selfServeMessage(new Error("Failed to fetch")), "Failed to claim the installation.");
  assert.equal(selfServeMessage(null), "Failed to claim the installation.");
});

if (failures > 0) process.exit(1);

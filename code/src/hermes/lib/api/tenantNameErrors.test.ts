/**
 * Tests for the tenant naming messages shared by Settings > Preferences (create) and
 * Settings > Members (rename).
 * Run with: npx tsx lib/api/tenantNameErrors.test.ts
 */

import {
  tenantCreatedButUnlistedMessage,
  tenantNameErrorMessage,
  tenantRenamedButUnlistedMessage,
} from "./tenantNameErrors";

console.log("🧪 Testing tenant naming messages\n");
console.log("=".repeat(60));

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

/** Build an error shaped like the one thrown by `fetchAPI`. */
function apiError(status: number, message: string): unknown {
  return Object.assign(new Error(message), { status });
}

const conflict = "Another tenant already uses that name.";

/** The two callers differ only in the fallback they pass. */
const createMessage = (err: unknown) => tenantNameErrorMessage(err, "Failed to create tenant");
const renameMessage = (err: unknown) => tenantNameErrorMessage(err, "Failed to rename tenant");

const tests: TestCase[] = [
  {
    name: "409 is replaced with a sentence of our own",
    fn: () =>
      createMessage(
        apiError(409, "API error: 409 Conflict - TENANT_NAME_CONFLICT: taken")
      ) === conflict,
  },
  {
    name: "400 keeps the server's words, which carry the name rules",
    fn: () => {
      // Only the 409 is replaced. A 400 says which rule the name broke -- blank, or too long -- and
      // that detail exists nowhere on the client.
      const message =
        "API error: 400 Bad Request - INVALID_TENANT_NAME: A tenant name must not be blank and must be at most 255 characters";
      return createMessage(apiError(400, message)) === message;
    },
  },
  {
    name: "403 keeps the server's words",
    fn: () => {
      // Creating a tenant is installation-admin only, and being told so is the useful answer.
      const message = "API error: 403 Forbidden - FORBIDDEN";
      return createMessage(apiError(403, message)) === message;
    },
  },
  {
    name: "a status-less failure still reports what threw",
    fn: () => {
      // fetchAPI attaches no status when the request never reached the server.
      return (
        createMessage(new Error("Failed to fetch")) === "Failed to fetch"
      );
    },
  },
  {
    name: "a non-Error throw falls back rather than rendering as [object Object]",
    fn: () =>
      createMessage({ oops: true }) === "Failed to create tenant" &&
      createMessage(null) === "Failed to create tenant" &&
      renameMessage({ oops: true }) === "Failed to rename tenant",
  },
  {
    name: "the conflict sentence is the same one on the rename side",
    fn: () => {
      // Both flows collide on the same unique index, so telling the operator two different things
      // about the same refusal would be an accident, not a decision.
      return (
        renameMessage(apiError(409, "API error: 409 Conflict - TENANT_NAME_CONFLICT: taken")) ===
        conflict
      );
    },
  },
  {
    name: "a reserved name keeps the server's words",
    fn: () => {
      // #1786 refuses reserved names in communism mode with a 400. The client mirrors the list for
      // instant feedback but the server is the authority, and its sentence is the one that is
      // current.
      const message = "API error: 400 Bad Request - TENANT_NAME_RESERVED: That name is reserved";
      return renameMessage(apiError(400, message)) === message;
    },
  },
  {
    name: "the unlisted-rename message names the tenant and does not read as a failure to rename",
    fn: () => {
      const r = tenantRenamedButUnlistedMessage("Platform");
      return r.includes('"Platform"') && r.includes("Renamed to") && r.includes("Reload");
    },
  },
  {
    name: "the unlisted-tenant message names the tenant and does not read as a failure to create",
    fn: () => {
      const r = tenantCreatedButUnlistedMessage("New Team");
      return (
        r.includes('"New Team"') && r.includes("was created") && r.includes("Reload")
      );
    },
  },
];

tests.forEach((test) => {
  try {
    if (test.fn()) {
      console.log(`✅ PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`❌ FAIL: ${test.name}`);
      failed++;
    }
  } catch (error) {
    console.log(`❌ FAIL: ${test.name} (threw error: ${error})`);
    failed++;
  }
});

console.log("\n" + "=".repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${tests.length} tests`);

process.exit(failed > 0 ? 1 : 0);

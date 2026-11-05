import assert from "node:assert";
import type { UserDetailResponse } from "@/lib/api/client";
import { capabilitiesNote, membershipsScopeNote, userDetailFacts } from "./userDetailFacts";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

function detailOf(overrides: Partial<UserDetailResponse>): UserDetailResponse {
  return {
    id: "user-1",
    name: "Ada Lovelace",
    email: "ada@example.com",
    auth_origin: "github:acme",
    created_at: "2026-01-05T10:00:00Z",
    type: "user",
    admin_rights: { is_instance_admin: false, is_tenant_admin: false },
    tenants: [{ id: "tenant-1", name: "Acme" }],
    tenants_complete: true,
    ...overrides,
  };
}

test("the facts name every identity line of the box, in display order", () => {
  assert.deepStrictEqual(
    userDetailFacts(detailOf({})),
    [
      { label: "Email", value: "ada@example.com" },
      { label: "User ID", value: "user-1", mono: true },
      { label: "Type", value: "user" },
      { label: "Auth", value: "github:acme" },
      { label: "Role", value: "User" },
    ]
  );
});

test("an account without email or auth origin keeps the same shape", () => {
  const facts = userDetailFacts(detailOf({ email: undefined, auth_origin: undefined }));
  assert.deepStrictEqual(facts.find((f) => f.label === "Email")?.value, "—");
  assert.deepStrictEqual(facts.find((f) => f.label === "Auth")?.value, "password");
});

test("the role line reads the single admin grant apart", () => {
  const roleOf = (admin_rights: UserDetailResponse["admin_rights"]) =>
    userDetailFacts(detailOf({ admin_rights })).find((f) => f.label === "Role")?.value;
  assert.deepStrictEqual(
    roleOf({ is_instance_admin: true, is_tenant_admin: false }),
    "Admin (installation-wide)"
  );
  assert.deepStrictEqual(
    roleOf({ is_instance_admin: false, is_tenant_admin: true }),
    "Admin (some tenants)"
  );
  assert.deepStrictEqual(roleOf({ is_instance_admin: false, is_tenant_admin: false }), "User");
});

test("a whole membership list carries no note", () => {
  assert.deepStrictEqual(membershipsScopeNote(detailOf({ tenants_complete: true })), null);
});

test("a membership list the caller cannot see whole is labelled as partial", () => {
  const note = membershipsScopeNote(detailOf({ tenants_complete: false }));
  assert.ok(note !== null);
  assert.ok(note.includes("scope"));
});

test("capabilities the answer carries need no note", () => {
  const capabilities = {
    "access-token-create": false,
    "access-token-refresh": false,
    admin: ["tenant-1"],
    commit: { modified: [], "pulled-in": [] },
    preview: { modified: [], "pulled-in": [] },
    sudo: [],
    "users-manage": [],
  };
  assert.deepStrictEqual(capabilitiesNote(detailOf({ capabilities })), null);
});

test("capabilities the answer leaves out are explained, not read as no grants", () => {
  const note = capabilitiesNote(detailOf({ capabilities: undefined }));
  assert.ok(note !== null);
  assert.ok(note.includes("can edit"));
});

if (failures > 0) process.exit(1);

/**
 * Tests for addTenantMember, the client half of
 * POST /api/v1/tenants/{tenant_id}/members.
 *
 * addTenantMember goes through fetchAPI -> globalThis.fetch, so fetch is stubbed at the global
 * level. Each test installs its own stub and restores the previous one afterwards, following
 * lib/tasks.test.ts.
 *
 * The refusal cases are the point of most of this file. MembersPanel renders `err.message`
 * verbatim when an add fails, so the server's error id and detail are what an operator actually
 * reads on screen -- these tests pin that path from response body to message text.
 *
 * Run with: npx tsx lib/api/addTenantMember.test.ts
 */

import { addTenantMember } from "./client";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => Promise<boolean>;
}

type FetchFn = typeof globalThis.fetch;

function installFetch(stub: FetchFn): () => void {
  const prev = globalThis.fetch;
  globalThis.fetch = stub;
  return () => {
    globalThis.fetch = prev;
  };
}

interface Capture {
  url: string;
  init: RequestInit | undefined;
}

/** A stub that records the single request it is given and answers with [status] and [body]. */
function recordingFetch(
  captured: Capture[],
  status: number,
  body: unknown
): FetchFn {
  return (async (input: RequestInfo | URL, init?: RequestInit) => {
    captured.push({ url: String(input), init });
    return new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });
  }) as FetchFn;
}

const member = {
  user_id: "1f1b6e6a-0000-4000-8000-000000000001",
  name: "newbie",
  type: "user",
  joined_at: "2026-08-27T00:00:00Z",
  admin_scope: "none",
  users_manage_scope: "none",
};

const tests: TestCase[] = [
  {
    name: "POSTs the user id in the body, not the path",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 201, member));
      try {
        await addTenantMember("tenant-1", member.user_id);
        const [req] = captured;
        return (
          captured.length === 1 &&
          req.url.endsWith("/api/v1/tenants/tenant-1/members") &&
          req.init?.method === "POST" &&
          req.init?.body === JSON.stringify({ user_id: member.user_id })
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "percent-encodes the tenant id into the path",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 201, member));
      try {
        await addTenantMember("a/b c", member.user_id);
        return captured[0].url.endsWith("/api/v1/tenants/a%2Fb%20c/members");
      } finally {
        restore();
      }
    },
  },
  {
    name: "a user id needing escaping still reaches the server verbatim",
    fn: async () => {
      // The subject travels in the JSON body, so it is never path-escaped. A server that reads it
      // back out of the URL instead would see a mangled id; this pins which half carries it.
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 201, member));
      try {
        await addTenantMember("tenant-1", "not a uuid/at all");
        const req = captured[0];
        return (
          req.url.endsWith("/api/v1/tenants/tenant-1/members") &&
          req.init?.body === JSON.stringify({ user_id: "not a uuid/at all" })
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "returns the tenant-member the server answers 201 with, flagged as created",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 201, member));
      try {
        const result = await addTenantMember("tenant-1", member.user_id);
        // The endpoint grants no capability, so a freshly added member is scoped to nothing --
        // the UI reads these two fields to decide what it may offer for the row.
        return (
          result.created &&
          result.member.user_id === member.user_id &&
          result.member.admin_scope === "none" &&
          result.member.users_manage_scope === "none"
        );
      } finally {
        restore();
      }
    },
  },
  {
    // The two success statuses are the ONLY way to tell an add from a no-op: the members listing is
    // oldest-membership-first and read a page at a time, so a user missing from it may simply be on
    // a later page. Getting this backwards would have the UI claim it added someone it did not.
    name: "200 means the user was already a member, and is not reported as created",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 200, member));
      try {
        const result = await addTenantMember("tenant-1", member.user_id);
        return !result.created && result.member.user_id === member.user_id;
      } finally {
        restore();
      }
    },
  },
  {
    name: "404 USER_NOT_FOUND surfaces the server's id and detail in the message",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(
        recordingFetch(captured, 404, {
          id: "USER_NOT_FOUND",
          data: "No such active user",
        })
      );
      try {
        await addTenantMember("tenant-1", "00000000-0000-0000-0000-000000000000");
        return false; // should have thrown
      } catch (err) {
        const e = err as Error & { status?: number };
        return (
          e instanceof Error &&
          e.status === 404 &&
          e.message.includes("USER_NOT_FOUND") &&
          e.message.includes("No such active user")
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "400 INVALID_REQUEST surfaces the server's id and detail in the message",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(
        recordingFetch(captured, 400, {
          id: "INVALID_REQUEST",
          data: "user_id is not a uuid",
        })
      );
      try {
        await addTenantMember("tenant-1", "not-a-uuid");
        return false; // should have thrown
      } catch (err) {
        const e = err as Error & { status?: number };
        return (
          e.status === 400 &&
          e.message.includes("INVALID_REQUEST") &&
          e.message.includes("user_id is not a uuid")
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "403 is not retried away: one request, and it throws",
    fn: async () => {
      // fetchAPI retries 401 three times. A capability refusal is a settled answer, so it must
      // reach the panel on the first attempt rather than being slept over twice first.
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 403, { id: "FORBIDDEN" }));
      try {
        await addTenantMember("tenant-1", member.user_id);
        return false; // should have thrown
      } catch (err) {
        return (err as Error & { status?: number }).status === 403 && captured.length === 1;
      } finally {
        restore();
      }
    },
  },
];

(async () => {
  for (const test of tests) {
    try {
      if (await test.fn()) {
        console.log(`PASS: ${test.name}`);
        passed++;
      } else {
        console.log(`FAIL: ${test.name}`);
        failed++;
      }
    } catch (error) {
      console.log(`FAIL: ${test.name} (threw: ${error})`);
      failed++;
    }
  }
  console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
  process.exit(failed > 0 ? 1 : 0);
})();

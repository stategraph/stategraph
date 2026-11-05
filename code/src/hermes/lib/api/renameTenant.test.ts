/**
 * Tests for renameTenant, the client half of PUT /api/v1/tenants/{tenant_id}.
 *
 * renameTenant goes through fetchAPI -> globalThis.fetch, so fetch is stubbed at the global level.
 * Each test installs its own stub and restores the previous one afterwards, following
 * lib/api/createTenant.test.ts.
 *
 * The refusal cases carry most of the weight: what TenantRename shows an operator is chosen from
 * the status and the body of the thrown error, so what the server sends is what gets read. These
 * tests pin the path from response to thrown error.
 *
 * Run with: npx tsx lib/api/renameTenant.test.ts
 */

import { renameTenant } from "./client";

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
function recordingFetch(captured: Capture[], status: number, body: unknown): FetchFn {
  return (async (input: RequestInfo | URL, init?: RequestInit) => {
    captured.push({ url: String(input), init });
    return new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });
  }) as FetchFn;
}

const tenant = {
  id: "9c2f1a54-0000-4000-8000-000000000001",
  name: "Platform",
};

const tests: TestCase[] = [
  {
    name: "PUTs the name in the body to the tenant's own path",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 200, tenant));
      try {
        await renameTenant(tenant.id, { name: tenant.name });
        const [req] = captured;
        return (
          captured.length === 1 &&
          req.url.endsWith(`/api/v1/tenants/${tenant.id}`) &&
          req.init?.method === "PUT" &&
          req.init?.body === JSON.stringify({ name: tenant.name })
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "the tenant id is escaped into the path",
    fn: async () => {
      // Ids are server-issued uuids today, so nothing here needs escaping in practice. The encoding
      // is what keeps that true: an id carrying a `/` or `?` would otherwise reshape the request
      // into a call on a different endpoint.
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 200, tenant));
      try {
        await renameTenant("a/b?c", { name: tenant.name });
        return captured[0].url.endsWith("/api/v1/tenants/a%2Fb%3Fc");
      } finally {
        restore();
      }
    },
  },
  {
    name: "a name needing escaping reaches the server verbatim",
    fn: async () => {
      // The name travels in the JSON body, never in the path, so it is not URL-escaped on the way
      // out. A client that built the name into the URL would mangle this one.
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 200, tenant));
      try {
        await renameTenant(tenant.id, { name: "a/b c & d" });
        return captured[0].init?.body === JSON.stringify({ name: "a/b c & d" });
      } finally {
        restore();
      }
    },
  },
  {
    name: "returns the tenant as the server stored it, not the argument",
    fn: async () => {
      // The server trims before storing, so echoing the caller's string would put a name in the
      // switcher that the tenant does not have.
      const restore = installFetch(recordingFetch([], 200, tenant));
      try {
        const renamed = await renameTenant(tenant.id, { name: `   ${tenant.name}   ` });
        return renamed.id === tenant.id && renamed.name === tenant.name;
      } finally {
        restore();
      }
    },
  },
  {
    name: "409 is not retried away: one request, and it throws with the status attached",
    fn: async () => {
      // fetchAPI retries 401 three times. A name conflict is a settled answer, so it must reach the
      // caller on the first attempt -- and carry `status`, which is what picks the conflict sentence
      // over the raw "API error: 409 Conflict - ..." that fetchAPI assembles.
      const captured: Capture[] = [];
      const restore = installFetch(
        recordingFetch(captured, 409, {
          id: "TENANT_NAME_CONFLICT",
          data: "Another tenant already uses that name",
        })
      );
      try {
        await renameTenant(tenant.id, { name: tenant.name });
        return false; // should have thrown
      } catch (err) {
        return (err as Error & { status?: number }).status === 409 && captured.length === 1;
      } finally {
        restore();
      }
    },
  },
  {
    name: "400 surfaces the server's error id and detail, body included",
    fn: async () => {
      // Communism-mode installs answer a reserved name with TENANT_NAME_RESERVED (#1786); the
      // generic invalid-name refusal is a 400 too. Both are told in the server's words, so the id
      // and detail have to survive the throw -- on `body` for the sentence, in `message` as a
      // fallback.
      const restore = installFetch(
        recordingFetch([], 400, { id: "TENANT_NAME_RESERVED", data: "That name is reserved" })
      );
      try {
        await renameTenant(tenant.id, { name: "stategraph" });
        return false; // should have thrown
      } catch (err) {
        const e = err as Error & { status?: number; body?: { id?: string; data?: string } };
        return (
          e.status === 400 &&
          e.body?.data === "That name is reserved" &&
          e.message.includes("TENANT_NAME_RESERVED")
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "403 reaches the caller on the first attempt",
    fn: async () => {
      // Renaming is tenant-admin only; a refusal is settled, not worth retrying.
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 403, { id: "FORBIDDEN" }));
      try {
        await renameTenant(tenant.id, { name: tenant.name });
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

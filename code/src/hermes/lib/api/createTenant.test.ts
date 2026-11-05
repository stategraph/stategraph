/**
 * Tests for createTenant, the client half of POST /api/v1/tenants.
 *
 * createTenant goes through fetchAPI -> globalThis.fetch, so fetch is stubbed at the global level.
 * Each test installs its own stub and restores the previous one afterwards, following
 * lib/api/addTenantMember.test.ts.
 *
 * The refusal cases carry most of the weight. Settings > Preferences renders the thrown error for
 * everything except the 409, which it replaces with a sentence of its own -- so what the server
 * puts in the body is what an operator reads, and the status is what decides between the two. These
 * tests pin that path from response body to message text.
 *
 * Run with: npx tsx lib/api/createTenant.test.ts
 */

import { createTenant } from "./client";

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

const tenant = {
  id: "9c2f1a54-0000-4000-8000-000000000001",
  name: "New Team",
};

const tests: TestCase[] = [
  {
    name: "POSTs the name in the body to the collection path",
    fn: async () => {
      const captured: Capture[] = [];
      const restore = installFetch(recordingFetch(captured, 201, tenant));
      try {
        await createTenant(tenant.name);
        const [req] = captured;
        return (
          captured.length === 1 &&
          req.url.endsWith("/api/v1/tenants") &&
          req.init?.method === "POST" &&
          req.init?.body === JSON.stringify({ name: tenant.name })
        );
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
      const restore = installFetch(recordingFetch(captured, 201, tenant));
      try {
        await createTenant("a/b c & d");
        const req = captured[0];
        return (
          req.url.endsWith("/api/v1/tenants") &&
          req.init?.body === JSON.stringify({ name: "a/b c & d" })
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "returns the tenant the server answers 201 with",
    fn: async () => {
      const restore = installFetch(recordingFetch([], 201, tenant));
      try {
        const created = await createTenant(tenant.name);
        return created.id === tenant.id && created.name === tenant.name;
      } finally {
        restore();
      }
    },
  },
  {
    name: "the server's trimmed name is what comes back, not the argument",
    fn: async () => {
      // The server trims before storing, so the caller's padded string is not what the tenant is
      // called. Anything that echoed the argument instead would put the wrong label in the switcher.
      const restore = installFetch(recordingFetch([], 201, tenant));
      try {
        const created = await createTenant(`   ${tenant.name}   `);
        return created.name === tenant.name;
      } finally {
        restore();
      }
    },
  },
  {
    name: "409 is not retried away: one request, and it throws with the status attached",
    fn: async () => {
      // fetchAPI retries 401 three times. A name conflict is a settled answer, so it must reach the
      // caller on the first attempt -- and carry `status`, which is what Preferences reads to
      // replace the raw message with "Another tenant already uses that name."
      const captured: Capture[] = [];
      const restore = installFetch(
        recordingFetch(captured, 409, {
          id: "TENANT_NAME_CONFLICT",
          data: "Another tenant already uses that name",
        })
      );
      try {
        await createTenant(tenant.name);
        return false; // should have thrown
      } catch (err) {
        return (
          (err as Error & { status?: number }).status === 409 &&
          captured.length === 1
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "400 surfaces the server's error id and detail in the message",
    fn: async () => {
      // Preferences renders `err.message` verbatim for everything but the 409, so the id and detail
      // the server sends are what an operator actually reads for an invalid name.
      const restore = installFetch(
        recordingFetch([], 400, {
          id: "INVALID_TENANT_NAME",
          data: "A tenant name must not be blank and must be at most 255 characters",
        })
      );
      try {
        await createTenant("   ");
        return false; // should have thrown
      } catch (err) {
        const message = (err as Error).message;
        return (
          message.includes("INVALID_TENANT_NAME") &&
          message.includes("must not be blank")
        );
      } finally {
        restore();
      }
    },
  },
  {
    name: "403 reaches the caller on the first attempt",
    fn: async () => {
      // Creating a tenant is installation-admin only; a refusal is settled, not worth retrying.
      const captured: Capture[] = [];
      const restore = installFetch(
        recordingFetch(captured, 403, { id: "FORBIDDEN" })
      );
      try {
        await createTenant(tenant.name);
        return false; // should have thrown
      } catch (err) {
        return (
          (err as Error & { status?: number }).status === 403 &&
          captured.length === 1
        );
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

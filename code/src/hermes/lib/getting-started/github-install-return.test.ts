/**
 * Run with: npx tsx lib/getting-started/github-install-return.test.ts
 */

import assert from "node:assert/strict";
import {
  GITHUB_INSTALL_PENDING_TTL_MS,
  clearGithubInstallPending,
  githubInstallReturnHref,
  markGithubInstallPending,
  parseInstallationId,
  readGithubInstallPending,
  type StoreLike,
} from "./github-install-return";

function memoryStore(): StoreLike {
  const values = new Map<string, string>();
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => {
      values.set(key, value);
    },
    removeItem: (key) => {
      values.delete(key);
    },
  };
}

const href = (search: string, pending: { tenantId: string; startedAt: number } | null = null) =>
  githubInstallReturnHref({ search: new URLSearchParams(search), pending });

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "a sign-in redirect with an installation resumes the wizard at link",
    run: () => {
      assert.equal(
        href("installation_id=123"),
        "/getting-started/?path=github&github_claim=installed&installation_id=123",
      );
    },
  },
  {
    name: "a pending install without an installation resumes as returned, for its tenant",
    run: () => {
      assert.equal(
        href("", { tenantId: "t1", startedAt: 1 }),
        "/getting-started/?path=github&github_claim=returned&tenant=t1",
      );
      assert.equal(
        href("installation_id=9", { tenantId: "t1", startedAt: 1 }),
        "/getting-started/?path=github&github_claim=installed&installation_id=9&tenant=t1",
      );
    },
  },
  {
    name: "nothing to resume without an installation or a pending install",
    run: () => {
      assert.equal(href(""), null);
      assert.equal(href("installation_id=abc"), null);
      assert.equal(href("installation_id=0"), null);
      assert.equal(href("installation_id=1%26path%3Dgitlab"), null);
    },
  },
  {
    name: "an installation id is a positive decimal integer",
    run: () => {
      assert.equal(parseInstallationId("183597565"), "183597565");
      assert.equal(parseInstallationId("-1"), null);
      assert.equal(parseInstallationId(""), null);
      assert.equal(parseInstallationId(null), null);
    },
  },
  {
    name: "a pending install lasts until its TTL or a clear",
    run: () => {
      const store = memoryStore();
      assert.equal(readGithubInstallPending(1000, store), null);
      markGithubInstallPending("t1", 1000, store);
      assert.deepEqual(readGithubInstallPending(1005, store), { tenantId: "t1", startedAt: 1000 });
      assert.equal(readGithubInstallPending(1000 + GITHUB_INSTALL_PENDING_TTL_MS + 1, store), null);
      assert.equal(readGithubInstallPending(999, store), null);
      clearGithubInstallPending(store);
      assert.equal(readGithubInstallPending(1005, store), null);
    },
  },
  {
    name: "a damaged or missing store reads as no pending install",
    run: () => {
      const store = memoryStore();
      store.setItem("stategraph-github-install-pending", "{not json");
      assert.equal(readGithubInstallPending(1, store), null);
      store.setItem("stategraph-github-install-pending", JSON.stringify({ tenantId: 1 }));
      assert.equal(readGithubInstallPending(1, store), null);
      assert.equal(readGithubInstallPending(1, null), null);
      markGithubInstallPending("t1", 1, null);
      clearGithubInstallPending(null);
    },
  },
];

let failed = 0;
for (const t of tests) {
  try {
    t.run();
    console.log(`ok - ${t.name}`);
  } catch (e) {
    failed += 1;
    console.error(`not ok - ${t.name}`);
    console.error(e);
  }
}
if (failed > 0) process.exit(1);

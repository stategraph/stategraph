import assert from "node:assert";
import { executeWithRetry, orchestrationUnavailable, runAcrossProviders, VCS_PROVIDERS } from "./providers";

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

test("orchestrationUnavailable matches only TABLE_ACCESS_ERR bodies", () => {
  const err = Object.assign(new Error("API error: 400"), {
    body: { id: "TABLE_ACCESS_ERR", data: "github_work_manifests" },
  });
  assert.equal(orchestrationUnavailable(err), true);
  assert.equal(
    orchestrationUnavailable(Object.assign(new Error("x"), { body: { id: "UNKNOWN_COLUMN_ERR" } })),
    false,
  );
  assert.equal(orchestrationUnavailable(new Error("network down")), false);
  assert.equal(orchestrationUnavailable(null), false);
  assert.equal(orchestrationUnavailable({ body: null }), false);
});

test("both providers enumerated", () => {
  assert.deepEqual(VCS_PROVIDERS, ["github", "gitlab"]);
});

const pending: Promise<void>[] = [];
function testAsync(name: string, fn: () => Promise<void>) {
  pending.push(
    fn().then(
      () => console.log(`ok - ${name}`),
      (e) => {
        failures++;
        console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`);
      },
    ),
  );
}

testAsync("runAcrossProviders keeps the successes and names the failures", async () => {
  const partial = await runAcrossProviders(async (p) => {
    if (p === "gitlab") throw new Error("gitlab down");
    return p.toUpperCase();
  });
  assert.deepEqual(partial.results, [{ provider: "github", value: "GITHUB" }]);
  assert.deepEqual(partial.failed, ["gitlab"]);
});

testAsync("runAcrossProviders throws only when every provider fails, with the first failure", async () => {
  await assert.rejects(
    runAcrossProviders(async (p) => {
      throw new Error(`${p} down`);
    }),
    /github down/,
  );
});

testAsync("runAcrossProviders fans out only across the providers it is given", async () => {
  const called: string[] = [];
  const subset = await runAcrossProviders(async (p) => {
    called.push(p);
    return p.toUpperCase();
  }, ["gitlab"]);
  assert.deepEqual(called, ["gitlab"]);
  assert.deepEqual(subset, { results: [{ provider: "gitlab", value: "GITLAB" }], failed: [] });
});

const httpError = (status: number, body?: unknown) =>
  Object.assign(new Error(`API error: ${status}`), { status, body });

/** An exec that plays the given outcomes in order and counts its calls. */
function scripted(...outcomes: (unknown[] | Error)[]) {
  const calls = { n: 0 };
  const exec = async () => {
    const o = outcomes[calls.n++];
    if (o instanceof Error) throw o;
    return { data: o };
  };
  return { exec, calls };
}

testAsync("executeWithRetry retries a 5xx once and returns the second attempt's rows", async () => {
  const { exec, calls } = scripted(httpError(502), [1]);
  assert.deepEqual(await executeWithRetry("q", { exec, delayMs: 0 }), [1]);
  assert.equal(calls.n, 2);
});

testAsync("executeWithRetry retries a failure with no HTTP status", async () => {
  const { exec, calls } = scripted(new TypeError("fetch failed"), [2]);
  assert.deepEqual(await executeWithRetry("q", { exec, delayMs: 0 }), [2]);
  assert.equal(calls.n, 2);
});

testAsync("executeWithRetry never retries a 4xx, a 401, or TABLE_ACCESS_ERR even on a 5xx", async () => {
  for (const e of [httpError(400), httpError(401), httpError(500, { id: "TABLE_ACCESS_ERR" })]) {
    const { exec, calls } = scripted(e, [3]);
    await assert.rejects(executeWithRetry("q", { exec, delayMs: 0 }), (x) => x === e);
    assert.equal(calls.n, 1);
  }
});

testAsync("executeWithRetry throws the second attempt's error when the retry fails too", async () => {
  const second = httpError(503);
  const { exec } = scripted(httpError(502), second);
  await assert.rejects(executeWithRetry("q", { exec, delayMs: 0 }), (x) => x === second);
});

void Promise.all(pending).then(() => {
  if (failures > 0) process.exit(1);
});

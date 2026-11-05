import assert from "node:assert";
import { REDACTED, redactRepoConfig } from "./redactRepoConfig";

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

test("hook env maps are masked, commands stay visible", () => {
  const out = redactRepoConfig({
    hooks: {
      plan: {
        pre: [
          { type: "run", cmd: ["./login.sh"], env: { AWS_SESSION_TOKEN: "abc", REGION: "eu-west-1" } },
          { type: "env", name: "TF_VAR_x", cmd: ["cat", "x"], sensitive: true },
        ],
      },
    },
  }) as { hooks: { plan: { pre: Record<string, unknown>[] } } };
  const [run, env] = out.hooks.plan.pre;
  assert.deepEqual(run.env, { AWS_SESSION_TOKEN: REDACTED, REGION: REDACTED });
  assert.deepEqual(run.cmd, ["./login.sh"]);
  assert.deepEqual(env.cmd, ["cat", "x"]);
});

test("credential-looking keys are masked anywhere in the tree", () => {
  const out = redactRepoConfig({
    storage: { plans: { method: "s3", bucket: "b", access_key_id: "example-access-key", secret_access_key: "example-secret" } },
    notify: { slack_webhook_url: "https://hooks.slack.com/example", github_token: "example-github-token" },
    n: { password: 42 },
  }) as Record<string, Record<string, unknown>>;
  assert.equal(out.storage.plans && (out.storage.plans as Record<string, unknown>).secret_access_key, REDACTED);
  assert.equal((out.storage.plans as Record<string, unknown>).access_key_id, REDACTED);
  assert.equal((out.storage.plans as Record<string, unknown>).bucket, "b");
  assert.equal(out.notify.slack_webhook_url, REDACTED);
  assert.equal(out.notify.github_token, REDACTED);
  assert.equal(out.n.password, REDACTED);
});

test("gate tokens and ordinary values are untouched; input is not mutated", () => {
  const input = { gates: [{ name: "prod", token: "gate-1", any_of: ["team:ops"] }], engine: { name: "tofu" } };
  const out = redactRepoConfig(input);
  assert.deepEqual(out, input);
  assert.notEqual(out, input);
  assert.equal(redactRepoConfig(null), null);
  assert.equal(redactRepoConfig("x"), "x");
});

if (failures > 0) process.exit(1);

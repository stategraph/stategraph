import assert from "node:assert/strict";
import {
  GITHUB_APP_REPLACE_WARNING,
  GITHUB_APP_ROTATE_WARNING,
  githubAppCredentials,
  showGithubAppPanel,
  githubAppCredentialsError,
  githubAppDeleteConfirmation,
  githubAppEngineState,
  githubAppSourceDescription,
  looksLikePem,
  type GithubAppSource,
} from "./github-app-panel";

const PEM = "-----BEGIN RSA PRIVATE KEY-----\nx\n-----END RSA PRIVATE KEY-----";

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "every source has a description",
    run: () => {
      for (const source of ["environment", "stored", "none", "unknown"] as const) {
        assert.ok(githubAppSourceDescription(source).length > 0, source);
      }
    },
  },
  {
    name: "a server that cannot read its App does not claim it has none",
    run: () => {
      assert.match(githubAppSourceDescription("unknown"), /cannot read/);
      assert.doesNotMatch(githubAppSourceDescription("unknown"), /has no GitHub App/);
    },
  },
  {
    name: "the environment's App says it is managed elsewhere",
    run: () => {
      assert.match(githubAppSourceDescription("environment"), /environment/);
    },
  },
  {
    name: "the engine state distinguishes running from restarting",
    run: () => {
      assert.notEqual(githubAppEngineState(true), githubAppEngineState(false));
      assert.match(githubAppEngineState(false), /restarting/);
    },
  },
  {
    name: "the delete confirmation names the App and says the key is gone",
    run: () => {
      const text = githubAppDeleteConfirmation("my-app");
      assert.match(text, /my-app/);
      assert.match(text, /private key/);
      assert.match(text, /installations stay/);
    },
  },
  {
    name: "the replace and rotate warnings say what the operator must do next",
    run: () => {
      assert.match(GITHUB_APP_REPLACE_WARNING, /install the new/i);
      assert.match(GITHUB_APP_ROTATE_WARNING, /paste/i);
    },
  },
  {
    name: "a plain paste is rejected and a PEM is not",
    run: () => {
      assert.equal(looksLikePem(""), false);
      assert.equal(looksLikePem("hunter2"), false);
      assert.equal(looksLikePem("-----BEGIN CERTIFICATE-----\nx\n-----END CERTIFICATE-----"), false);
      assert.equal(
        looksLikePem("  -----BEGIN RSA PRIVATE KEY-----\nx\n-----END RSA PRIVATE KEY-----\n"),
        true,
      );
    },
  },
  {
    name: "a hosted deployment shows no GitHub App panel",
    run: () => {
      assert.equal(showGithubAppPanel({ instanceAdmin: true, mode: undefined }), true);
      assert.equal(showGithubAppPanel({ instanceAdmin: true, mode: "COMMUNISM" }), false);
      assert.equal(showGithubAppPanel({ instanceAdmin: false, mode: undefined }), false);
      assert.equal(showGithubAppPanel({ instanceAdmin: false, mode: "COMMUNISM" }), false);
    },
  },
  {
    name: "an empty field is left out, so it keeps its stored value",
    run: () => {
      assert.deepEqual(
        githubAppCredentials({ pem: "", clientSecret: "  ", webhookSecret: "wh" }),
        { webhook_secret: "wh" },
      );
      assert.deepEqual(githubAppCredentials({ pem: "", clientSecret: "", webhookSecret: "" }), {});
    },
  },
  {
    name: "every field is sent under the name the request uses",
    run: () => {
      assert.deepEqual(githubAppCredentials({ pem: PEM, clientSecret: "cs", webhookSecret: "wh" }), {
        pem: PEM,
        client_secret: "cs",
        webhook_secret: "wh",
      });
    },
  },
  {
    name: "a rotation needs one credential, and a private key that is one",
    run: () => {
      assert.match(githubAppCredentialsError({}) ?? "", /paste/i);
      assert.match(githubAppCredentialsError({ pem: "hunter2" }) ?? "", /PEM/);
      assert.equal(githubAppCredentialsError({ pem: PEM }), null);
      assert.equal(githubAppCredentialsError({ webhook_secret: "wh" }), null);
      assert.equal(githubAppCredentialsError({ client_secret: "cs" }), null);
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

// The response's source union must stay the panel's union.
const _source: GithubAppSource = "stored";
void _source;

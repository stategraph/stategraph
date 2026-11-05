import assert from "node:assert";
import {
  ciRunUrl,
  prNoun,
  providerName,
  prSigil,
  projectUrl,
  pullRequestUrl,
  treeUrl,
} from "./links";

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

test("pullRequestUrl: github shape", () => {
  assert.equal(
    pullRequestUrl("github", "terrateam-demo", "kick-the-tires", 69),
    "https://github.com/terrateam-demo/kick-the-tires/pull/69",
  );
});
test("pullRequestUrl: gitlab shape", () => {
  assert.equal(
    pullRequestUrl("gitlab", "acme", "app", "42"),
    "https://gitlab.com/acme/app/-/merge_requests/42",
  );
});
test("pullRequestUrl: null without a number", () => {
  assert.equal(pullRequestUrl("github", "acme", "app", ""), null);
  assert.equal(pullRequestUrl("gitlab", "acme", "app", null), null);
});
test("self-hosted base is respected and trailing slash trimmed", () => {
  assert.equal(
    pullRequestUrl("gitlab", "g/sub", "app", 3, "https://gitlab.internal/"),
    "https://gitlab.internal/g/sub/app/-/merge_requests/3",
  );
  assert.equal(
    pullRequestUrl("github", "acme", "app", 3, "https://ghe.internal/"),
    "https://ghe.internal/acme/app/pull/3",
  );
});
test("treeUrl differs per provider (the iris /-/tree bug)", () => {
  assert.equal(
    treeUrl("github", "acme", "app", "main", "dev"),
    "https://github.com/acme/app/tree/main/dev",
  );
  assert.equal(
    treeUrl("gitlab", "acme", "app", "main", "dev"),
    "https://gitlab.com/acme/app/-/tree/main/dev",
  );
});
test("ciRunUrl: github actions link, gitlab null", () => {
  assert.equal(
    ciRunUrl("github", "acme", "app", "123"),
    "https://github.com/acme/app/actions/runs/123",
  );
  assert.equal(ciRunUrl("gitlab", "acme", "app", "123"), null);
  assert.equal(ciRunUrl("github", "acme", "app", null), null);
});
test("sigils and nouns", () => {
  assert.equal(prSigil("github"), "#");
  assert.equal(prSigil("gitlab"), "!");
  assert.equal(prNoun("gitlab"), "Merge Request");
});
test("projectUrl handles subgroup owners", () => {
  assert.equal(projectUrl("gitlab", "g/sub", "app"), "https://gitlab.com/g/sub/app");
});
test("missing owner/repo yields null, not a malformed URL", () => {
  assert.equal(projectUrl("github", "", "app"), null);
  assert.equal(treeUrl("github", "acme", "", "main"), null);
  assert.equal(ciRunUrl("github", "", "", "123"), null);
  assert.equal(pullRequestUrl("github", "", "app", 1), null);
});
test("path segments are percent-encoded, separators preserved", () => {
  assert.equal(
    treeUrl("github", "acme", "app", "feat/x", "envs/us east"),
    "https://github.com/acme/app/tree/feat/x/envs/us%20east",
  );
});

test("providerName: display name per provider", () => {
  assert.equal(providerName("github"), "GitHub");
  assert.equal(providerName("gitlab"), "GitLab");
});

if (failures > 0) process.exit(1);

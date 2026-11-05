import assert from "node:assert";
import { groupRepoOptions, matchesOwner, ownerFacetOptions, ownerKey, parseOwnerKey } from "./ownerFacet";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

test("ownerFacetOptions dedupes and sorts, provider disambiguates", () => {
  const opts = ownerFacetOptions([
    { provider: "github", owner: "zeta" },
    { provider: "github", owner: "acme" },
    { provider: "github", owner: "acme" },
    { provider: "gitlab", owner: "acme" },
    { provider: "github", owner: "" },
  ]);
  assert.deepEqual(opts, [
    { label: "acme (GitHub)", value: "github:acme" },
    { label: "acme (GitLab)", value: "gitlab:acme" },
    { label: "zeta (GitHub)", value: "github:zeta" },
  ]);
});

test("matchesOwner: empty selects all; value is provider-scoped", () => {
  assert.equal(matchesOwner("", "github", "acme"), true);
  assert.equal(matchesOwner(ownerKey("github", "acme"), "github", "acme"), true);
  assert.equal(matchesOwner(ownerKey("github", "acme"), "gitlab", "acme"), false);
  assert.equal(matchesOwner(ownerKey("github", "acme"), "github", "zeta"), false);
});

test("parseOwnerKey: known provider and non-empty owner only", () => {
  assert.deepEqual(parseOwnerKey(ownerKey("gitlab", "group:sub")), { provider: "gitlab", owner: "group:sub" });
  assert.equal(parseOwnerKey(""), null);
  assert.equal(parseOwnerKey("acme"), null);
  assert.equal(parseOwnerKey("bitbucket:acme"), null);
  assert.equal(parseOwnerKey("github:"), null);
  assert.equal(parseOwnerKey(":acme"), null);
});

test("groupRepoOptions groups by owner, values stay owner/name", () => {
  const groups = groupRepoOptions([
    { provider: "github", owner: "acme", name: "infra" },
    { provider: "github", owner: "acme", name: "app" },
    { provider: "github", owner: "acme", name: "app" },
    { provider: "gitlab", owner: "beta", name: "svc" },
  ]);
  assert.deepEqual(groups, [
    {
      label: "acme (GitHub)",
      options: [
        { label: "app", value: "acme/app" },
        { label: "infra", value: "acme/infra" },
      ],
    },
    { label: "beta (GitLab)", options: [{ label: "svc", value: "beta/svc" }] },
  ]);
});

if (failures > 0) process.exit(1);

import assert from "node:assert";
import { effectiveStatusFilter, PRS_CAP, pullRequestsQuery, mapPrRow } from "./mqlQueries";

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

test("query joins PRs to repositories per provider, explicit limit", () => {
  const gh = pullRequestsQuery("github");
  const gl = pullRequestsQuery("gitlab");
  assert.match(gh, /from github_pull_requests as pr/);
  assert.match(gh, /inner join github_installation_repositories as r on r\.id = pr\.repository/);
  assert.match(gl, /from gitlab_pull_requests as pr/);
  assert.match(gh, new RegExp(`limit ${PRS_CAP}$`));
  // GitHub has created_at, so its cap means "most recent" and the column is
  // projected for client-side ordering; gitlab_pull_requests has no
  // created_at and falls back to pull_number.
  assert.match(gh, /select pr\.created_at, /);
  assert.match(gh, /order by pr\.created_at desc/);
  assert.doesNotMatch(gl, /created_at/);
  assert.match(gl, /order by pr\.pull_number desc/);
  // The repo id is projected so rows have a collision-free key.
  assert.match(gh, /r\.id as repo_id/);
});

test("mapPrRow tags provider", () => {
  const row = mapPrRow("gitlab", {
    pull_number: 42,
    title: "Add VPC",
    branch: "feat",
    base_branch: "main",
    state: "open",
    username: "sam",
    owner: "acme",
    name: "infra",
    repo_id: 9,
  });
  assert.equal(row.provider, "gitlab");
  assert.equal(row.pullNumber, "42");
  assert.equal(row.createdAt, "");
  assert.equal(row.owner, "acme");
  assert.equal(row.repoId, "9");
});

test("effectiveStatusFilter: absent/empty defaults to open", () => {
  assert.equal(effectiveStatusFilter(""), "open");
});
test("effectiveStatusFilter: explicit all clears the filter", () => {
  assert.equal(effectiveStatusFilter("all"), "");
});
test("effectiveStatusFilter: named states pass through", () => {
  assert.equal(effectiveStatusFilter("closed"), "closed");
  assert.equal(effectiveStatusFilter("merged"), "merged");
  assert.equal(effectiveStatusFilter("open"), "open");
});

if (failures > 0) process.exit(1);

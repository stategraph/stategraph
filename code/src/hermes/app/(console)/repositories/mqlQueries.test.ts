import assert from "node:assert";
import { REPOS_CAP, repositoriesQuery, mapRepoRow } from "./mqlQueries";

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

test("query targets the provider's table; projection avoids created_at", () => {
  const gh = repositoriesQuery("github");
  assert.match(gh, /from github_installation_repositories/);
  assert.match(repositoriesQuery("gitlab"), /from gitlab_installation_repositories/);
  // github_installation_repositories has no created_at — provider-neutral
  // projection must not reference it.
  assert.doesNotMatch(gh, /created_at/);
  assert.match(gh, new RegExp(`limit ${REPOS_CAP}$`));
});

test("mapRepoRow tags provider", () => {
  const row = mapRepoRow("github", {
    id: 7,
    installation_id: 1,
    name: "infra",
    owner: "acme",
    updated_at: "2026-08-01T00:00:00Z",
  });
  assert.equal(row.provider, "github");
  assert.equal(row.id, "7");
  assert.equal(row.installation, "1");
});

if (failures > 0) process.exit(1);

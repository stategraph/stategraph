import assert from "node:assert";
import { AUDIT_CAP, auditQuery, mapAuditRow } from "./mqlQueries";

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

test("query targets the provider's table with an explicit limit", () => {
  const gh = auditQuery("github");
  const gl = auditQuery("gitlab");
  assert.match(gh, /from github_work_manifests/);
  assert.match(gl, /from gitlab_work_manifests/);
  assert.match(gh, new RegExp(`limit ${AUDIT_CAP}$`));
  assert.match(gh, /order by wm\.created_at desc/);
});

test("query reads the runs alone; their failure counts come from a second query", () => {
  const gh = auditQuery("github");
  assert.match(gh, /^select wm\.id as id, /);
  assert.doesNotMatch(gh, /workflow_step_outputs|fail_count|join/);
});

test("mapAuditRow tags provider and keeps owner/name apart", () => {
  const row = mapAuditRow("github", {
    id: "wm1",
    repo_owner: "acme",
    repo_name: "infra",
    run_type: "plan",
    run_kind: "pr",
    state: "completed",
    username: "demo-user",
    branch: "main",
    pull_number: 69,
    created_at: "2026-08-10T00:00:00Z",
    completed_at: null,
    fail_count: 2,
  });
  assert.equal(row.provider, "github");
  assert.equal(row.repoOwner, "acme");
  assert.equal(row.repoName, "infra");
  assert.equal(row.pullNumber, "69");
  assert.equal(row.failCount, 2);
  assert.equal(row.outcome, "failed");
  assert.equal(row.completedAt, "");
});

if (failures > 0) process.exit(1);

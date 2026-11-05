import assert from "node:assert";
import {
  WS_CAP,
  lockKey,
  workspaceLockedQuery,
  workspaceLocksQuery,
  workspacesQuery,
} from "./mqlQueries";

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

test("workspaces query groups by the dirspace, not environment", () => {
  const q = workspacesQuery("github");
  assert.match(q, /^with runs as \(select .* from work_manifest_dirspaceflows as wmds inner join github_work_manifests as wm on wm\.id = wmds\.work_manifest left join work_manifest_results as wmr on wmr\.work_manifest = wmds\.work_manifest and wmr\.path = wmds\.path and wmr\.workspace = wmds\.workspace\), latest as \(select /);
  // The row key is (repo, dir, workspace); environment must be aggregated, not grouped.
  assert.match(q, /from runs group by repo_owner, repo_name, dir, workspace\)/);
  assert.doesNotMatch(q, /group by[^)]*environment/);
  assert.match(q, /max\(environment\)/);
  assert.match(q, new RegExp(`limit ${WS_CAP}$`));
});

test("workspaces query joins the latest run back for every dirspace, without touching the tables again", () => {
  const q = workspacesQuery("gitlab");
  // The hint must come from the grouped max(created_at), not from the newest
  // WS_CAP raw rows, or busy dirspaces would starve the rest of their hint.
  assert.match(
    q,
    /from latest inner join runs on runs\.repo_owner = latest\.repo_owner and runs\.repo_name = latest\.repo_name and runs\.dir = latest\.dir and runs\.workspace = latest\.workspace and runs\.created_at = latest\.last_run/,
  );
  assert.match(q, /runs\.state as state, runs\.run_type as run_type/);
  assert.match(q, /order by latest\.last_run desc/);
  // Each foreign table is scanned exactly once: a join-back against a foreign
  // scan loops one remote fetch per dirspace (see the doc comment).
  assert.equal(q.split("gitlab_work_manifests").length - 1, 1);
  assert.equal(q.split("work_manifest_dirspaceflows").length - 1, 1);
  assert.equal(q.split("work_manifest_results").length - 1, 1);
});

test("workspaces query carries the latest run's dirspace result", () => {
  const q = workspacesQuery("gitlab");
  assert.match(
    q,
    /left join work_manifest_results as wmr on wmr\.work_manifest = wmds\.work_manifest and wmr\.path = wmds\.path and wmr\.workspace = wmds\.workspace/,
  );
  assert.match(q, /wmr\.success as success/);
  assert.match(q, /runs\.success as success/);
});

test("locks query is repository-scoped through the PR map", () => {
  const q = workspaceLocksQuery("github");
  assert.match(q, /from dirspace_pull_request_locks/);
  // Must join to the repo so a lock in repo A does not mark repo B's dirspace.
  assert.match(q, /inner join github_pull_requests_map/);
  assert.match(q, /inner join github_installation_repositories/);
});

test("single-dirspace lock probe is repository-scoped and escapes its inputs", () => {
  const q = workspaceLockedQuery("gitlab", "acme", "infra", "envs/o'brien", "default");
  assert.match(q, /from dirspace_pull_request_locks/);
  assert.match(q, /inner join gitlab_pull_requests_map/);
  assert.match(q, /inner join gitlab_installation_repositories/);
  assert.match(q, /gir\.owner = 'acme' and gir\.name = 'infra'/);
  assert.match(q, /l\.path = 'envs\/o''brien' and l\.workspace = 'default'/);
  assert.match(q, /limit 1$/);
});

test("lockKey includes the repo", () => {
  assert.equal(lockKey("acme", "infra", "dev", "default"), "acme/infra|dev|default");
});

if (failures > 0) process.exit(1);

import assert from "node:assert";
import { MQL_MAX_LIMIT } from "@/lib/mql/providers";
import {
  DRIFT_CAP,
  SCHEDULES_CAP,
  driftMetricQuery,
  driftPlanPayloadsQuery,
  driftScheduleCountQuery,
  driftSchedulesQuery,
  driftStepQuery,
  mapDriftRow,
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

test("per-screen caps clamp to the server's MQL ceiling", () => {
  // Above the ceiling the server would silently return fewer rows than the
  // cap and the `length >= cap` truncation check would never fire.
  assert.ok(DRIFT_CAP <= MQL_MAX_LIMIT);
  assert.ok(SCHEDULES_CAP <= MQL_MAX_LIMIT);
});

const PLAN_TYPES = /wm\.run_type in \('plan', 'autoplan'\)/;
const APPLY_TYPES = /wm\.run_type in \('apply', 'autoapply', 'unsafe-apply'\)/;

test("step query is drift-kind, provider-scoped, and step-filtered", () => {
  const q = driftStepQuery("github", "plan");
  assert.match(q, /inner join github_work_manifests/);
  assert.match(q, /wm\.run_kind = 'drift'/);
  assert.match(q, /wso\.step like '%\/plan'/);
  assert.match(q, new RegExp(`limit ${DRIFT_CAP}$`));
  assert.match(driftStepQuery("gitlab", "apply"), /inner join gitlab_work_manifests/);
});

test("step queries scope by run type as well as step name (legacy aliases included)", () => {
  // A plan op inside an apply workflow must not read as a drift check, and
  // its success must not stand in for the apply's.
  assert.match(driftStepQuery("github", "plan"), PLAN_TYPES);
  assert.doesNotMatch(driftStepQuery("github", "plan"), APPLY_TYPES);
  assert.match(driftStepQuery("github", "apply"), APPLY_TYPES);
  assert.match(driftStepQuery("github", "apply"), /wso\.step like '%\/apply'/);
});

test("schedules query joins through the provider repo map", () => {
  const q = driftSchedulesQuery("gitlab");
  assert.match(q, /from drift_schedules/);
  assert.match(q, /inner join gitlab_repositories_map/);
  assert.match(q, /inner join gitlab_installation_repositories/);
  assert.match(q, new RegExp(`limit ${SCHEDULES_CAP}$`));
});

test("schedule count query groups by mode over the same join", () => {
  const q = driftScheduleCountQuery("github");
  assert.match(q, /^select ds\.reconcile as reconcile, count\(\*\) as c from drift_schedules/);
  assert.match(q, /inner join github_repositories_map/);
  assert.match(q, /inner join github_installation_repositories/);
  assert.match(q, /group by ds\.reconcile$/);
  assert.doesNotMatch(q, /limit/);
  assert.doesNotMatch(q, /where/);
});

test("schedule count query follows the selected owner, escaped", () => {
  const q = driftScheduleCountQuery("gitlab", "o'brien");
  assert.match(q, /inner join gitlab_installation_repositories as gir on gir\.id = rm\.repository_id where gir\.owner = 'o''brien' group by ds\.reconcile$/);
});

test("metric queries share the dirspace (step-output) grain", () => {
  // All three count/sum over workflow_step_outputs so the tiles are comparable.
  const checks = driftMetricQuery("github", "checks", "2026-01-01T00:00:00Z");
  const recon = driftMetricQuery("github", "reconciles", "2026-01-01T00:00:00Z");
  const finds = driftMetricQuery("github", "finds", "2026-01-01T00:00:00Z");
  for (const q of [checks, recon, finds]) {
    assert.match(q, /from workflow_step_outputs/);
    assert.match(q, /wm\.run_kind = 'drift'/);
    // The "(30d)" labels hold only if every metric is bounded by `since`.
    assert.match(q, /wm\.created_at >= '2026-01-01T00:00:00Z'/);
  }
  assert.match(checks, /wso\.step like '%\/plan'/);
  assert.match(checks, PLAN_TYPES);
  assert.match(recon, /wso\.step like '%\/apply'/);
  assert.match(recon, APPLY_TYPES);
  assert.match(recon, /and wso\.success = true$/);
  assert.match(finds, /sum\(\(\(wso\.payload ->> 'has_changes'\)::bool\)::integer\)/);
  assert.match(finds, PLAN_TYPES);
});

test("metric queries follow the selected owner, escaped, only when one is given", () => {
  for (const kind of ["checks", "finds", "reconciles"] as const) {
    assert.match(driftMetricQuery("github", kind, "2026-01-01T00:00:00Z", "o'brien"), /and wm\.repo_owner = 'o''brien'/);
    assert.doesNotMatch(driftMetricQuery("github", kind, "2026-01-01T00:00:00Z"), /repo_owner/);
  }
});

test("plan payloads query targets each (run, dir, workspace) in one round trip", () => {
  const q = driftPlanPayloadsQuery([
    { checkRunId: "wm1", dir: "envs/prod", workspace: "default" },
    { checkRunId: "wm2", dir: "it's", workspace: "default" },
  ]);
  assert.match(q, /^select wso\.work_manifest as work_manifest, .*wso\.payload as payload from workflow_step_outputs/);
  assert.match(q, /wso\.step like '%\/plan'/);
  assert.match(q, /\(wso\.work_manifest = 'wm1' and \(wso\.scope ->> 'dir'\) = 'envs\/prod' and \(wso\.scope ->> 'workspace'\) = 'default'\) or \(wso\.work_manifest = 'wm2'/);
  assert.match(q, /'it''s'/);
  assert.match(q, /limit 2$/);
});

test("mapDriftRow reads the payload has_changes string as a boolean", () => {
  const row = mapDriftRow("github", {
    id: "wm1",
    repo_owner: "acme",
    repo_name: "infra",
    environment: "",
    run_type: "plan",
    dir: "dev",
    workspace: "default",
    has_changes: "true",
    success: true,
    created_at: "2026-08-10T00:00:00Z",
  });
  assert.equal(row.hasChanges, true);
  assert.equal(row.provider, "github");
  assert.equal(row.dir, "dev");
  assert.equal(mapDriftRow("github", { has_changes: "false" }).hasChanges, false);
  // Legacy payloads omit has_changes (SQL NULL on the wire): that is a clean
  // check, never a drifted one.
  assert.equal(mapDriftRow("github", { has_changes: null }).hasChanges, false);
  assert.equal(mapDriftRow("github", {}).hasChanges, false);
  assert.equal(mapDriftRow("github", { success: null }).success, false);
});

if (failures > 0) process.exit(1);

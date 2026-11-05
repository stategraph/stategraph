/**
 * Tests for the split home-dashboard MQL queries (#1072).
 *
 * The whole point of the split is that the scalar query stays cheap (no
 * whole-estate graph traversal) so it can paint before the analytics query
 * returns. These guards lock that in: the expensive markers (`unnest`,
 * `json_agg`) must live ONLY in the analytics query, and each widget's column
 * must come from the correct half.
 *
 * Run with: npx tsx "app/(console)/home/mqlQueries.test.ts"
 */

import {
  homeScalarsQuery,
  homeGraphAnalyticsQuery,
  recentRunsQuery,
  openPullRequestsQuery,
  runsSinceCountQuery,
  mergeRecentRuns,
  RECENT_RUNS_SHOWN,
  resolveWorkManifestPresence,
  resolveHostedHomeDestination,
  stategraphEnginePresenceQuery,
  mapRunRow,
  RECENT_RUNS_CAP,
} from './mqlQueries';

let passed = 0;
let failed = 0;

function check(name: string, cond: boolean): void {
  if (cond) {
    passed++;
  } else {
    failed++;
    console.log(`  ❌ ${name}`);
  }
}

console.log('🧪 Testing split home dashboard MQL queries\n' + '='.repeat(60));

const scalar = homeScalarsQuery();
const analytics = homeGraphAnalyticsQuery();

// --- The scalar query must stay cheap: no graph traversal ----------------
check('scalar query has no unnest(dependencies)', !/unnest/.test(scalar));
check('scalar query has no json_agg', !/json_agg/.test(scalar));
check('scalar query has no anti-join orphan detection (all_deps)', !/all_deps/.test(scalar));

// --- The analytics query owns the expensive work -------------------------
check('analytics query uses unnest(dependencies)', /unnest\(dependencies\)/.test(analytics));
check('analytics query uses json_agg', /json_agg/.test(analytics));
check('analytics query builds the all_deps anti-join set', /all_deps/.test(analytics));

// --- Scalar columns come from the scalar query ---------------------------
for (const col of [
  'total_states',
  'total_resources',
  'total_instances',
  'total_edges',
  'total_providers',
  'total_modules',
  'top_resource_type',
  'largest_module',
]) {
  check(`scalar query projects "${col}"`, scalar.includes(`as ${col}`));
}

// --- Analytics-only columns must NOT leak into the scalar query ----------
for (const col of [
  'graph_roots',
  'graph_leaves',
  'orphaned_count',
  'most_deployed_module',
  'dependency_hotspot',
  'orphaned_by_state',
  'orphaned_top',
  'provider_distribution',
  'resource_type_distribution',
]) {
  check(`analytics query projects "${col}"`, analytics.includes(`as ${col}`));
  check(`scalar query does NOT project "${col}"`, !scalar.includes(`as ${col}`));
}

// --- Each query returns a single cross-joined row ------------------------
check('scalar query cross-joins its count CTEs',
  scalar.includes('from cnt_s, cnt_r, cnt_i, edges, cnt_p, cnt_m'));
check('scalar query left-joins the may-be-empty top-N CTEs',
  scalar.includes('left join top_rt on true') && scalar.includes('left join largest_mod on true'));
check('analytics query left-joins the may-be-empty top-N CTEs',
  analytics.includes('left join most_deployed_mod on true') &&
  analytics.includes('left join dep_hotspot on true'));

// --- State scoping: both filter deleted states and honor a state id ------
check('scalar query filters deleted states', scalar.includes('deleted_at is null'));
check('analytics query filters deleted states', analytics.includes('deleted_at is null'));
check('no-arg scalar query does not pin a state id', !/\bid = '/.test(scalar));
check('no-arg analytics query does not pin a state id', !/deleted_at is null and id = '/.test(analytics));

const STATE = 'abc-123';
check('scalar query embeds the given state id',
  homeScalarsQuery(STATE).includes(`deleted_at is null and id = '${STATE}'`));
check('analytics query embeds the given state id',
  homeGraphAnalyticsQuery(STATE).includes(`deleted_at is null and id = '${STATE}'`));

// --- Orchestration activity queries (home orchestration-first band, #1639) ---
const ghRuns = recentRunsQuery('github');
check('recent-runs query is provider-scoped and newest first',
  ghRuns.includes('from github_work_manifests') && ghRuns.includes('order by created_at desc'));
check('recent-runs query is bounded', ghRuns.endsWith(`limit ${RECENT_RUNS_CAP}`));
check('recent-runs query targets the gitlab twin too',
  recentRunsQuery('gitlab').includes('from gitlab_work_manifests'));
check('open-PR count filters state=open per provider',
  openPullRequestsQuery('github').includes("from github_pull_requests where state = 'open'"));
// (drift step queries are imported from the Drift screen's module and covered
// by its tests — one query, one number everywhere.)
const cnt = runsSinceCountQuery('github', '2026-08-10T00:00:00Z');
check('runs-since count is a true windowed count per provider',
  cnt.includes('select count(*) as c from github_work_manifests') &&
  cnt.includes("created_at >= '2026-08-10T00:00:00Z'"));
check('runs-since escapes the bound it interpolates',
  runsSinceCountQuery('github', "2026-08-10' or '1'='1").includes("'2026-08-10'' or ''1''=''1'"));
const run = mapRunRow('github', { id: 'wm1', state: 'completed', run_type: 'apply', run_kind: 'pr',
  created_at: '2026-08-10T00:00:00Z', repo_owner: 'acme', repo_name: 'infra', pull_number: 69 });
check('mapRunRow tags provider and joins the repo',
  run.provider === 'github' && run.repo === 'acme/infra' && run.pullNumber === '69');
check('mapRunRow leaves the repo empty rather than a bare slash',
  mapRunRow('github', { id: 'wm2', repo_owner: null, repo_name: null }).repo === '');

const mkRun = (id: string, provider: 'github' | 'gitlab', createdAt: string) =>
  mapRunRow(provider, { id, created_at: createdAt, repo_owner: 'acme', repo_name: 'infra' });
const merged = mergeRecentRuns(
  [
    [mkRun('gh1', 'github', '2026-08-10T05:00:00Z'), mkRun('gh2', 'github', '2026-08-10T01:00:00Z')],
    [mkRun('gl1', 'gitlab', '2026-08-10T04:00:00Z'), mkRun('gl2', 'gitlab', '2026-08-10T02:00:00Z')],
  ],
  3,
);
check('mergeRecentRuns interleaves providers newest-first and takes the top N',
  merged.map((r) => r.id).join(',') === 'gh1,gl1,gl2');
const tied = mergeRecentRuns(
  [[mkRun('gh1', 'github', '2026-08-10T05:00:00Z')], [mkRun('gl1', 'gitlab', '2026-08-10T05:00:00Z')]],
  2,
);
check('mergeRecentRuns is stable on a tie',
  tied.map((r) => r.id).join(',') === 'gh1,gl1');
check('mergeRecentRuns sorts an unparseable timestamp last',
  mergeRecentRuns([[mkRun('bad', 'github', ''), mkRun('good', 'github', '2026-08-10T05:00:00Z')]], 2)
    .map((r) => r.id).join(',') === 'good,bad');
check('the per-provider fetch cap covers the rows shown',
  RECENT_RUNS_CAP >= RECENT_RUNS_SHOWN);

// --- Hosted first-run routing --------------------------------------------
check('work-manifest presence accepts any returned provider row',
  resolveWorkManifestPresence([true], ['gitlab']) === true);
check('work-manifest presence treats a partial empty fanout as unknown',
  resolveWorkManifestPresence([], ['gitlab']) === null);
check('work-manifest presence proves absence only when every provider returned',
  resolveWorkManifestPresence([], []) === false);

check('any imported state keeps the user on Home',
  resolveHostedHomeDestination({
    stateCount: 1,
    hasWorkManifest: false,
    linkedInstallation: true,
  }) === 'home');
check('any work manifest keeps a zero-state tenant on Home',
  resolveHostedHomeDestination({
    stateCount: 0,
    hasWorkManifest: true,
    linkedInstallation: false,
  }) === 'home');
check('a linked installation without a run keeps the user on Home',
  resolveHostedHomeDestination({
    stateCount: 0,
    hasWorkManifest: false,
    linkedInstallation: true,
  }) === 'home');
check('an empty installation list starts setup',
  resolveHostedHomeDestination({
    stateCount: 0,
    hasWorkManifest: false,
    linkedInstallation: false,
  }) === 'setup');
check('an unavailable installation list starts setup',
  resolveHostedHomeDestination({
    stateCount: 0,
    hasWorkManifest: false,
    linkedInstallation: null,
  }) === 'setup');

check('the engine presence probe reads the tenant-scoped step outputs for the stategraph plan step',
  stategraphEnginePresenceQuery() ===
    "select work_manifest from workflow_step_outputs where step = 'stategraph/plan' limit 1");

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

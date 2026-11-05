/**
 * Tests for the Stacks tab queries and the ported terrateam state logic
 * (#1647). The derivation and rollup are ports of select_dirspace_stack_states.sql
 * and terrat_vcs_stacks.ml — these guards lock the port to the canonical
 * semantics.
 *
 * Run with: npx tsx "app/(console)/stacks/mqlQueries.test.ts"
 */

import {
  DIRSPACE_FACTS_CAP,
  STACKS_PR_CAP,
  STACK_RUNS_CAP,
  buildStateMap,
  effectiveRules,
  explainerAvailable,
  filterRunsToStack,
  parseStacksConfig,
  pendingReasons,
  deriveDirspaceState,
  dirspaceStatesQuery,
  mapDirspaceFactRow,
  mapPrStacksRow,
  mapStackRunRow,
  mapStacksConfigRow,
  mergeOuterStacks,
  outerPendingReasons,
  overlayStacks,
  sortStacksDefaultLast,
  stackDetailHref,
  stackLeafDirspaces,
  stackRunsQuery,
  stackStateOf,
  stacksConfigQuery,
  stacksQuery,
  lastKnownStacksQuery,
  latestPlanQuery,
  planRunHref,
  stackVersions,
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

console.log('🧪 Testing stacks MQL queries + state port\n' + '='.repeat(60));

// --- Query shape -----------------------------------------------------------
const q1 = stacksQuery('github');
check('stacks query reads pull_request_stacks through the PR map',
  q1.includes('from pull_request_stacks') && q1.includes('github_pull_requests_map'));
check('stacks query filters to open PRs and is bounded',
  q1.includes("pr.state = 'open'") && q1.endsWith(`limit ${STACKS_PR_CAP}`));
check('stacks query targets the gitlab twin too',
  stacksQuery('gitlab').includes('gitlab_pull_requests_map'));
check('stacks query does not depend on repo_configs (only the explainer does)',
  !q1.includes('repo_configs') && !q1.includes('stacks_config'));
const qc = stacksConfigQuery('github');
check('config query inner-joins the derived config row on branch+sha, over the stacks window',
  qc.includes("inner join repo_configs as rc on rc.repo = grm.core_id and rc.kind = 'derived' and rc.branch = pr.branch and rc.sha = pr.sha") &&
  qc.includes("rc.data -> 'stacks' as stacks_config") &&
  qc.includes("pr.state = 'open'") && qc.endsWith(`limit ${STACKS_PR_CAP}`));
const cfgRow = mapStacksConfigRow('github', {
  repository: 42, pull_number: 68, stacks_config: { names: { a: { rules: {} } } },
});
check('mapStacksConfigRow keys like a PR entry and parses the config',
  cfgRow.key === 'github-42-68' && cfgRow.config?.size === 1);
const q1pr = stacksQuery('github', { repoId: 42, pullNumber: 68 });
check('PR-scoped stacks query pins repo + pull number, any PR state',
  q1pr.includes('pm.repository_id = 42 and pm.pull_number = 68') && !q1pr.includes("pr.state = 'open'"));

const q2 = dirspaceStatesQuery('github');
check('facts query replaces row_number with a max() group-by CTE',
  q2.includes('max(wm.created_at)') && q2.includes('group by wm.repository, wm.pull_number, wmr.path, wmr.workspace'));
check('facts query is unlock-aware',
  q2.includes('github_pull_request_latest_unlocks') &&
  q2.includes('lu.unlocked_at is null or lu.unlocked_at < wm.created_at'));
check('facts query pins work manifests to the PR shas',
  q2.includes('pr.base_sha = wm.base_sha') && q2.includes('pr.sha = wm.sha or pr.merged_sha = wm.sha'));
check('facts query enumerates current dirspaces (never-run -> null facts)',
  q2.includes('from github_change_dirspaces as cd') && q2.includes('left join facts as f'));
check('facts query is bounded', q2.endsWith(`limit ${DIRSPACE_FACTS_CAP}`));
// An unordered page that fills the limit is logged as a defect server-side,
// and truncates at an arbitrary end rather than the one stacksQuery uses.
check('facts query is ordered, newest pull number first, so the cap cuts the same end as the stacks query',
  q2.includes('order by pr.pull_number desc, cd.repository, cd.path, cd.workspace'));
check('facts cap never exceeds the server max_limit (silent clamp)', DIRSPACE_FACTS_CAP <= 1000);
const q2pr = dirspaceStatesQuery('github', { repoId: 42, pullNumber: 68 });
check('PR-scoped facts query pins both the latest CTE and the final select',
  q2pr.includes('wm.repository = 42 and wm.pull_number = 68') &&
  q2pr.includes('cd.repository = 42 and pr.pull_number = 68') && !q2pr.includes("pr.state = 'open'"));
check('facts self-join re-applies the completed_at filter',
  q2.includes('wm.created_at = l.created_at and wm.completed_at is not null'));

// --- The 7-way CASE, arm by arm (select_dirspace_stack_states.sql) ---------
check('no work manifest -> plan_pending', deriveDirspaceState(undefined) === 'plan_pending');
check('failed apply -> apply_failed',
  deriveDirspaceState({ runType: 'apply', success: false, hasPlanRow: true, hasChanges: true }) === 'apply_failed');
check('successful apply -> apply_success',
  deriveDirspaceState({ runType: 'apply', success: true, hasPlanRow: false, hasChanges: false }) === 'apply_success');
check('failed plan -> plan_failed',
  deriveDirspaceState({ runType: 'plan', success: false, hasPlanRow: true, hasChanges: true }) === 'plan_failed');
check('successful plan without a plans row -> apply_success',
  deriveDirspaceState({ runType: 'plan', success: true, hasPlanRow: false, hasChanges: false }) === 'apply_success');
check('successful plan without changes -> apply_success',
  deriveDirspaceState({ runType: 'plan', success: true, hasPlanRow: true, hasChanges: false }) === 'apply_success');
check('successful plan with changes -> apply_pending',
  deriveDirspaceState({ runType: 'plan', success: true, hasPlanRow: true, hasChanges: true }) === 'apply_pending');
check('other run types -> plan_pending (the else arm)',
  deriveDirspaceState({ runType: 'build-config', success: true, hasPlanRow: false, hasChanges: false }) === 'plan_pending');

// --- The severity ladder (stack_state_ordering) ----------------------------
check('worst state wins by ladder position',
  stackStateOf(['apply_success', 'plan_failed', 'apply_pending']) === 'plan_failed');
check('plan_pending outranks apply_failed on the ladder',
  stackStateOf(['apply_failed', 'plan_pending']) === 'plan_pending');
check('all no_changes -> no_changes', stackStateOf(['no_changes', 'no_changes']) === 'no_changes');
check('empty -> no_changes', stackStateOf([]) === 'no_changes');
check('no_changes loses to anything on the ladder',
  stackStateOf(['no_changes', 'apply_success']) === 'apply_success');

// --- Mapping + overlay -----------------------------------------------------
const rawStacks = {
  stacks: [
    {
      name: 'default', state: 'no_changes',
      stacks: [
        {
          name: 'default', state: 'no_changes', paths: [['default']],
          dirspaces: [
            { state: 'no_changes', dirspace: { dir: 'dev', workspace: 'default' } },
            { state: 'no_changes', dirspace: { dir: 'prod', workspace: 'default' } },
          ],
        },
      ],
    },
  ],
};
const row = mapPrStacksRow('github', {
  repository: 42, pull_number: 68, title: 'Add thing', owner: 'acme', name: 'infra',
  stacks: rawStacks,
});
check('mapPrStacksRow parses the jsonb into typed stacks',
  row.stacks.length === 1 && row.stacks[0].stacks[0].dirspaces.length === 2 && row.pullNumber === '68');
check('mapPrStacksRow accepts a JSON string too',
  mapPrStacksRow('github', { repository: 42, pull_number: 68, stacks: JSON.stringify(rawStacks) })
    .stacks[0].name === 'default');

const fact = mapDirspaceFactRow('github', {
  repository: 42, pull_number: 68, path: 'dev', workspace: 'default',
  run_type: 'plan', success: true, plan_wm: 'wm-1', has_changes: true,
});
check('mapDirspaceFactRow keys by provider/repo/pr/dirspace and derives',
  fact.key === 'github|42|68|dev|default' && fact.state === 'apply_pending');
check('null run_type maps through the no-work-manifest arm',
  mapDirspaceFactRow('github', {
    repository: 42, pull_number: 68, path: 'x', workspace: 'default',
    run_type: null, success: null, plan_wm: null, has_changes: null,
  }).state === 'plan_pending');

check('buildStateMap folds duplicate keys worst-state-wins',
  buildStateMap([
    { key: 'k', state: 'apply_success' },
    { key: 'k', state: 'plan_failed' },
  ]).get('k') === 'plan_failed');

const overlaid = overlayStacks(row, new Map([[fact.key, fact.state]]));
check('overlay applies the live state to the matching dirspace',
  overlaid[0].stacks[0].dirspaces.find((d) => d.dir === 'dev')?.state === 'apply_pending');
check('overlay defaults missing dirspaces to no_changes (Dirspace_map semantics)',
  overlaid[0].stacks[0].dirspaces.find((d) => d.dir === 'prod')?.state === 'no_changes');
check('overlay rolls inner and outer states up the ladder',
  overlaid[0].stacks[0].state === 'apply_pending' && overlaid[0].state === 'apply_pending');
check('overlay does not mutate the stored skeleton',
  row.stacks[0].stacks[0].dirspaces[0].state === 'no_changes');

// --- Pending-explainer: config parse, rule expansion, reasons ---------------
const CONFIG = parseStacksConfig({
  names: {
    base: { tag_query: 'dir:base', rules: { plan_after: [], apply_after: [], modified_by: [] } },
    web: { tag_query: 'dir:web', rules: { plan_after: ['base'], apply_after: ['base'], modified_by: [] } },
    app: { tag_query: 'dir:app', rules: { plan_after: [], apply_after: ['web'], modified_by: [] } },
    databases: { stacks: ['db1', 'db2'], rules: { plan_after: [], apply_after: ['base'], modified_by: [] } },
    db1: { tag_query: 'dir:db1', rules: { plan_after: [], apply_after: [], modified_by: [] } },
    db2: { tag_query: 'dir:db2', rules: { plan_after: [], apply_after: [], modified_by: [] } },
  },
});
check('parseStacksConfig parses the names map', CONFIG !== null && CONFIG.size === 6);
check('parseStacksConfig accepts a JSON string', parseStacksConfig('{"names":{"a":{"rules":{}}}}')?.size === 1);
check('parseStacksConfig null on missing section (implicit default stack)',
  parseStacksConfig(null) === null && parseStacksConfig({}) === null);
check('parseStacksConfig returns null on malformed JSON instead of throwing',
  parseStacksConfig('not json') === null);
check('parseStacksConfig skips a names entry that is not an object',
  parseStacksConfig({ names: { a: null } }) === null);

const effWeb = effectiveRules(CONFIG!, 'web', []);
check('own rules survive expansion', effWeb.planAfter.includes('base') && effWeb.applyAfter.includes('base'));
const effApp = effectiveRules(CONFIG!, 'app', []);
check('transitive closure pulls indirect blockers (app→web→base)',
  effApp.applyAfter.includes('web') && effApp.applyAfter.includes('base'));
const effDb1 = effectiveRules(CONFIG!, 'db1', ['databases']);
check('container rules are inherited by nested leaves', effDb1.applyAfter.includes('base'));
const CYCLIC = parseStacksConfig({ names: {
  a: { rules: { plan_after: ['b'], apply_after: [], modified_by: [] } },
  b: { rules: { plan_after: ['a'], apply_after: [], modified_by: [] } },
} });
const effCyc = effectiveRules(CYCLIC!, 'a', []);
check('cycles terminate and exclude self', effCyc.planAfter.length === 1 && effCyc.planAfter[0] === 'b');

const unioned = outerPendingReasons(
  {
    name: 'g', state: 'apply_pending' as never,
    stacks: [
      { name: 'a', state: 'apply_pending' as never, paths: [['a']], dirspaces: [] },
      { name: 'b', state: 'plan_pending' as never, paths: [['b']], dirspaces: [] },
    ],
  },
  new Map([['a', { plan: ['x'], apply: ['y'] }], ['b', { plan: ['x'], apply: [] }]]),
);
check("outerPendingReasons unions an outer stack's inner reasons without duplicates",
  unioned.plan.join(',') === 'x' && unioned.apply.join(',') === 'y');
check('outerPendingReasons drops the notes while an inner stack is blocked',
  outerPendingReasons(
    { name: 'g', state: 'apply_pending' as never, stacks: [
      { name: 'a', state: 'apply_pending' as never, paths: [['a']], dirspaces: [] },
      { name: 'b', state: 'apply_pending' as never, paths: [['b']], dirspaces: [] },
    ] },
    new Map([['a', { plan: [], apply: ['y'] }], ['b', { plan: [], apply: [], note: 'Nothing pending' }]]),
  ).note === undefined);
check("outerPendingReasons summarizes its inner stacks' distinct notes when nothing blocks",
  outerPendingReasons(
    { name: 'g', state: 'apply_pending' as never, stacks: [
      { name: 'a', state: 'apply_pending' as never, paths: [['a']], dirspaces: [] },
      { name: 'b', state: 'apply_success' as never, paths: [['b']], dirspaces: [] },
      { name: 'c', state: 'apply_success' as never, paths: [['c']], dirspaces: [] },
    ] },
    new Map([
      ['a', { plan: [], apply: [], note: 'No ordering rules — runs independently' }],
      ['b', { plan: [], apply: [], note: 'Nothing pending' }],
      ['c', { plan: [], apply: [], note: 'Nothing pending' }],
    ]),
  ).note === 'No ordering rules — runs independently · Nothing pending');

/** No "Pending plan of" / "Pending apply of" line for this stack. */
const noLines = (r?: { plan: string[]; apply: string[] }): boolean =>
  !r || (r.plan.length === 0 && r.apply.length === 0);

const inner = (name: string, state: string, paths: string[][] = [[name]]) => ({
  name, state: state as never, paths,
  dirspaces: [{ dir: name, workspace: 'default', state: state as never }],
});
const OUTERS = [
  { name: 'base', state: 'apply_pending' as never, stacks: [inner('base', 'apply_pending')] },
  { name: 'web', state: 'apply_pending' as never, stacks: [inner('web', 'apply_pending')] },
  { name: 'app', state: 'plan_pending' as never, stacks: [inner('app', 'plan_pending')] },
];
const reasons = pendingReasons(OUTERS, CONFIG);
check('apply_pending stack names its outstanding apply_after blocker',
  reasons.get('web')?.apply.join(',') === 'base');
check('a plan_pending stack gets no line from apply_after, and has no plan_after edges',
  noLines(reasons.get('app')));
check('null config yields no reasons', pendingReasons(OUTERS, null).size === 0);
const APPLIED = [
  { name: 'base', state: 'apply_success' as never, stacks: [inner('base', 'apply_success')] },
  { name: 'web', state: 'apply_pending' as never, stacks: [inner('web', 'apply_pending')] },
];
check('an applied blocker no longer blocks (outstanding filter)',
  (pendingReasons(APPLIED, CONFIG).get('web')?.apply ?? ['x']).length === 0);
// Every stack gets an entry so the explainer always renders something: with
// no blockers the entry carries a note instead of a blocker list.
check('an unblocked stack still gets an explanatory note',
  (pendingReasons(APPLIED, CONFIG).get('web')?.note ?? '').length > 0);
check('a stack with no work pending reads as nothing pending',
  pendingReasons(APPLIED, CONFIG).get('base')?.note === 'Nothing pending');
check('a blocker absent from the stored stacks is dropped',
  (pendingReasons([OUTERS[1]], CONFIG).get('web')?.apply ?? []).length === 0);

// Nested stacks: expansion happens once, over the merged own + container rules;
// the transitive walk follows raw rules without expanding container names.
const NESTED_A = parseStacksConfig({ names: {
  app: { rules: { plan_after: [], apply_after: ['databases'] } },
  databases: { stacks: ['db1'], rules: { plan_after: [], apply_after: ['net'] } },
  db1: { rules: { plan_after: [], apply_after: [] } },
  net: { rules: { plan_after: [], apply_after: [] } },
} });
check("a container named in apply_after expands to its leaves, without the container's own rules",
  effectiveRules(NESTED_A!, 'app', []).applyAfter.join(',') === 'db1');
const NESTED_B = parseStacksConfig({ names: {
  app: { rules: { plan_after: [], apply_after: ['databases'] } },
  databases: { stacks: ['db1'], rules: { plan_after: [], apply_after: [] } },
  db1: { rules: { plan_after: [], apply_after: ['net'] } },
  net: { rules: { plan_after: [], apply_after: [] } },
} });
check("the transitive walk follows the expanded leaves' own rules",
  effectiveRules(NESTED_B!, 'app', []).applyAfter.join(',') === 'db1,net');
const NESTED_C = parseStacksConfig({ names: {
  app: { rules: { plan_after: [], apply_after: ['web'] } },
  web: { rules: { plan_after: [], apply_after: ['databases'] } },
  databases: { stacks: ['db1'], rules: { plan_after: [], apply_after: [] } },
  db1: { rules: { plan_after: [], apply_after: [] } },
} });
check('a container name reached transitively is not expanded again',
  effectiveRules(NESTED_C!, 'app', []).applyAfter.join(',') === 'web,databases');
const MULTI = parseStacksConfig({ names: {
  g1: { stacks: ['x'], rules: { plan_after: [], apply_after: [] } },
  g2: { stacks: ['x'], rules: { plan_after: [], apply_after: ['base'] } },
  x: { rules: { plan_after: [], apply_after: [] } },
  base: { rules: { plan_after: [], apply_after: [] } },
} });
check('rules from every container path of a leaf apply',
  pendingReasons([
    { name: 'base', state: 'apply_pending' as never, stacks: [inner('base', 'apply_pending')] },
    { name: 'x', state: 'apply_pending' as never, stacks: [inner('x', 'apply_pending', [['g1', 'x'], ['g2', 'x']])] },
  ], MULTI).get('x')?.apply.join(',') === 'base');

check('plan_pending stack names its outstanding plan_after blocker',
  pendingReasons([
    { name: 'base', state: 'apply_pending' as never, stacks: [inner('base', 'apply_pending')] },
    { name: 'web', state: 'plan_pending' as never, stacks: [inner('web', 'plan_pending')] },
  ], CONFIG).get('web')?.plan.join(',') === 'base');
const PLAN_ONLY = parseStacksConfig({ names: {
  base: { rules: { plan_after: [], apply_after: [] } },
  svc: { rules: { plan_after: ['base'], apply_after: [] } },
} });
check('an apply_pending stack gets no line from plan_after',
  [...pendingReasons([
    { name: 'base', state: 'apply_pending' as never, stacks: [inner('base', 'apply_pending')] },
    { name: 'svc', state: 'apply_pending' as never, stacks: [inner('svc', 'apply_pending')] },
  ], PLAN_ONLY).values()].every(noLines));
check('a no_changes stack is not a blocker',
  [...pendingReasons([
    { name: 'base', state: 'no_changes' as never, stacks: [inner('base', 'no_changes')] },
    { name: 'web', state: 'apply_pending' as never, stacks: [inner('web', 'apply_pending')] },
  ], CONFIG).values()].every(noLines));
check('plan_failed and apply_failed stacks get no lines',
  ['plan_failed', 'apply_failed'].every((st) =>
    noLines(pendingReasons([
      { name: 'base', state: 'apply_pending' as never, stacks: [inner('base', 'apply_pending')] },
      { name: 'web', state: st as never, stacks: [inner('web', st)] },
    ], CONFIG).get('web'))));
check('a failed stack carries no note, not "Nothing pending"',
  ['plan_failed', 'apply_failed'].every((st) =>
    pendingReasons([
      { name: 'base', state: st as never, stacks: [inner('base', st)] },
      { name: 'web', state: 'apply_pending' as never, stacks: [inner('web', 'apply_pending')] },
    ], CONFIG).get('base')?.note === undefined));
check('container rules arrive through a leaf\'s stored paths',
  pendingReasons([
    { name: 'base', state: 'apply_pending' as never, stacks: [inner('base', 'apply_pending')] },
    { name: 'databases', state: 'apply_pending' as never,
      stacks: [inner('db1', 'apply_pending', [['databases', 'db1']])] },
  ], CONFIG).get('db1')?.apply.join(',') === 'base');
check('the explainer is not offered while the facts query is truncated',
  !explainerAvailable([{ config: CONFIG }], true));
check('the explainer is not offered when no PR has a derived config',
  !explainerAvailable([{ config: null }], false));
check('the explainer is offered with a config and complete facts',
  explainerAvailable([{ config: null }, { config: CONFIG }], false));

// ---- default-stack sort (design review #1737) ----
const SORTABLE = [
  { name: 'default', state: 'apply_pending' },
  { name: 'network', state: 'apply_success' },
  { name: 'web', state: 'plan_pending' },
];
{
  const sorted = sortStacksDefaultLast(SORTABLE);
  check('default stack sorts last', sorted[sorted.length - 1].name === 'default');
  check('non-default order is stable', sorted[0].name === 'network' && sorted[1].name === 'web');
  check('input array is not mutated', SORTABLE[0].name === 'default');
}
check('sort is a no-op without a default stack',
  sortStacksDefaultLast([{ name: 'a' }, { name: 'b' }]).map((x) => x.name).join(',') === 'a,b');
check('a default-only list stays put',
  sortStacksDefaultLast([{ name: 'default' }]).map((x) => x.name).join(',') === 'default');


// ---- per-stack detail view (#1737 item 5) ----
{
  const scope = { owner: "o'brien", repoName: 'infra' };
  const sq = stacksQuery('github', scope);
  check('repo-scoped stacks query filters that repository\'s open PRs, escaped, newest first',
    sq.includes("where pr.state = 'open' and r.owner = 'o''brien' and r.name = 'infra' order by pm.pull_number desc") &&
    sq.endsWith(`limit ${STACKS_PR_CAP}`));
  const fq = dirspaceStatesQuery('gitlab', scope);
  check('repo-scoped facts query pins the latest CTE to the repository, escaped',
    fq.includes("wm.repo_owner = 'o''brien' and wm.repo_name = 'infra' and pr.state = 'open'"));
  check('repo-scoped facts query joins the repository into the final select',
    fq.includes('inner join gitlab_installation_repositories as r on r.id = cd.repository') &&
    fq.includes("where r.owner = 'o''brien' and r.name = 'infra' and pr.state = 'open'") &&
    fq.endsWith(`limit ${DIRSPACE_FACTS_CAP}`));
  check('only the repo-scoped facts query joins the repository',
    !dirspaceStatesQuery('gitlab').includes('installation_repositories') &&
    !dirspaceStatesQuery('gitlab', { repoId: 1, pullNumber: 2 }).includes('installation_repositories'));
}
{
  const q = stackRunsQuery('github', "o'brien", 'infra', ['web/a', "web/o'b"]);
  check('stack runs query joins dirspaceflows to the provider table',
    /from work_manifest_dirspaceflows as wmds inner join github_work_manifests as wm on wm\.id = wmds\.work_manifest/.test(q));
  check('stack runs query reads the runs alone; their failure counts come from a second query',
    q.startsWith('select wm.id as id, ') && !/workflow_step_outputs|fail_count|left join/.test(q));
  check('stack runs query escapes owner quotes', q.includes("wm.repo_owner = 'o''brien'"));
  check("stack runs query asks only for the stack's directories, escaped",
    q.includes("and wmds.path in ('web/a', 'web/o''b') order by wm.created_at desc"));
  check('stack runs query is capped', q.endsWith(`limit ${STACK_RUNS_CAP}`));
}
{
  const q = latestPlanQuery('gitlab', { repoId: 7, pullNumber: 68 }, "envs/o'b", 'default');
  check('latest plan query pins the pull request and plan runs',
    q.includes('wm.repository = 7 and wm.pull_number = 68 and wm.run_type = \'plan\''));
  check('latest plan query matches the dirspace, escaped',
    q.includes("wmds.path = 'envs/o''b' and wmds.workspace = 'default'"));
  check('latest plan query reads the provider table', q.includes('inner join gitlab_work_manifests as wm'));
  check('latest plan query takes the newest run', q.endsWith('order by wm.created_at desc limit 1'));
  const href = planRunHref('abc', 'envs/a b&c', 'default');
  const params = new URLSearchParams(href.split('?')[1]);
  check('plan run href opens the changes view of the dirspace',
    href.startsWith('/runs/wm?') && params.get('id') === 'abc' && params.get('view') === 'changes' &&
      params.get('dir') === 'envs/a b&c' && params.get('workspace') === 'default');
}
{
  const outer = {
    name: 'web', state: 'no_changes' as never,
    stacks: [
      { name: 'web', state: 'no_changes' as never, paths: [], dirspaces: [
        { dir: 'web/a', workspace: 'default', state: 'no_changes' as never },
        { dir: 'web/b', workspace: 'prod', state: 'no_changes' as never },
      ] },
    ],
  };
  const leaves = stackLeafDirspaces(outer as never);
  check('leaf set keys dir:workspace', leaves.has('web/a:default') && leaves.has('web/b:prod') && leaves.size === 2);
  const runs = [
    mapStackRunRow({ id: 'wm2', state: 'completed', fail_count: 1, run_type: 'apply', created_at: '2', dir: 'web/a', workspace: 'default' }),
    mapStackRunRow({ id: 'wm2', state: 'completed', fail_count: 1, run_type: 'apply', created_at: '2', dir: 'web/b', workspace: 'prod' }),
    mapStackRunRow({ id: 'wm1', state: 'completed', fail_count: 0, run_type: 'plan', created_at: '1', dir: 'other', workspace: 'default' }),
  ];
  const filtered = filterRunsToStack(runs, leaves);
  check('a text fail_count reads as its number, and no failures row as zero',
    mapStackRunRow({ id: 'wm3', fail_count: '2' }).failCount === 2 &&
    mapStackRunRow({ id: 'wm4', fail_count: null }).failCount === 0);
  check('runs filter to the stack and dedupe by run id',
    filtered.length === 1 && filtered[0].id === 'wm2' && filtered[0].failCount === 1);
}

{
  // Plan order a/x, b/y, a/z: the engine groups successive entries only, so
  // the PR stores two outer groups named `a`.
  const mkInner = (name: string, dir: string, state: string) => ({
    name, state: 'no_changes' as never, paths: [[name]],
    dirspaces: [{ dir, workspace: 'default', state: state as never }],
  });
  const outers = [
    { name: 'a', state: 'no_changes' as never, stacks: [mkInner('x', 'a/x', 'apply_success')] },
    { name: 'b', state: 'no_changes' as never, stacks: [mkInner('y', 'b/y', 'plan_pending')] },
    { name: 'a', state: 'no_changes' as never, stacks: [mkInner('z', 'a/z', 'plan_failed')] },
  ];
  const merged = mergeOuterStacks(outers as never, 'a');
  check('groups sharing a name merge their inner stacks in plan order',
    merged?.stacks.map((i) => i.name).join(',') === 'x,z');
  check('the merged group rolls up to its worst dirspace state', merged?.state === 'plan_failed');
  const mergedLeaves = merged ? stackLeafDirspaces(merged) : new Set<string>();
  check('the leaf set of a merged group covers every group and inner stack',
    mergedLeaves.size === 2 && mergedLeaves.has('a/x:default') && mergedLeaves.has('a/z:default'));
  check('an absent stack name merges to null', mergeOuterStacks(outers as never, 'c') === null);
}

check('stackDetailHref encodes owner, repository and stack name',
  stackDetailHref('github', 'o/x', 'a&b c', 'web/app') ===
    '/stacks/detail?provider=github&owner=o%2Fx&repo=a%26b%20c&stack=web%2Fapp');

// --- last-known shape fallback (#1769) ---------------------------------------
{
  const q = lastKnownStacksQuery('github', { owner: "o'brien", repoName: 'infra' }, "web/o'b");
  check('last-known query scopes by repo, not PR state',
    q.includes("r.owner = 'o''brien'") && q.includes("r.name = 'infra'") && !q.includes("pr.state = 'open'"));
  check('last-known query matches the stack by name inside the stored stacks jsonb, escaped',
    q.includes(`prs.stacks @> '{"stacks":[{"name":"web/o''b"}]}'::jsonb`));
  check('last-known query returns only the newest matching pull request, with its state',
    q.includes('pr.state as pr_state') && q.endsWith('order by pm.pull_number desc limit 1'));
  check('last-known query stays off repo_configs (only the explainer reads it)',
    !q.includes('repo_configs') && !q.includes('stacks_config'));
  check('last-known query joins the same stored-stacks source as the tab',
    q.includes('from pull_request_stacks as prs') && q.includes('github_pull_requests_map'));
  const row = mapPrStacksRow('github', {
    repository: 7, pull_number: '12', title: 't', pr_state: 'merged', owner: 'o', name: 'r',
    stacks: { stacks: [] },
  });
  check('pr_state maps through when selected', row.prState === 'merged');
  const openRow = mapPrStacksRow('github', {
    repository: 7, pull_number: '12', title: 't', owner: 'o', name: 'r',
    stacks: { stacks: [] },
  });
  check('prState stays undefined for open-PR query rows', openRow.prState === undefined);
}

// --- stackVersions: the pull requests carrying a stack (#1769) ---------------
{
  const row = (pull: string, outers: { name: string; inners: string[] }[], prState?: string) =>
    mapPrStacksRow('github', {
      repository: 7, pull_number: pull, title: `t${pull}`, owner: 'o', name: 'r',
      ...(prState ? { pr_state: prState } : {}),
      stacks: {
        stacks: outers.map((o) => ({
          name: o.name,
          stacks: o.inners.map((i) => ({
            name: i, paths: [[o.name, i]], dirspaces: [{ dirspace: { dir: i, workspace: 'default' } }],
          })),
        })),
      },
    });
  const older = stackVersions(
    [row('20', [{ name: 'b', inners: ['y'] }]), row('3', [{ name: 'a', inners: ['x'] }])], new Map(), 'a');
  check('a newer pull request without the stack loses to an older one carrying it',
    older.length === 1 && older[0].pullNumber === '3');
  const numeric = stackVersions(
    [row('9', [{ name: 'a', inners: ['x'] }]), row('10', [{ name: 'a', inners: ['x'] }])], new Map(), 'a');
  check('versions sort by pull number numerically, newest first',
    numeric.map((v) => v.pullNumber).join(',') === '10,9');
  check('the pull request state passes through',
    stackVersions([row('5', [{ name: 'a', inners: ['x'] }], 'merged')], new Map(), 'a')[0]?.prState === 'merged');
  const split = stackVersions(
    [row('6', [{ name: 'a', inners: ['x'] }, { name: 'b', inners: ['y'] }, { name: 'a', inners: ['z'] }])],
    new Map(), 'a');
  check('split groups of the stack are merged into one version',
    split[0]?.outer.stacks.map((i) => i.name).join(',') === 'x,z');
  const live = stackVersions(
    [row('6', [{ name: 'a', inners: ['x'] }])], new Map([['github|7|6|x|default', 'apply_pending' as const]]), 'a');
  check('live states overlay the version, an empty map overlays none',
    live[0]?.outer.state === 'apply_pending' && split[0]?.outer.state === 'no_changes');
}

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

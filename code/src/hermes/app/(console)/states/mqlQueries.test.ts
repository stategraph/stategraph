/**
 * Tests for the state-detail MQL queries (#1087).
 * Run with: npx tsx "app/(console)/states/mqlQueries.test.ts"
 */

import { stateSummaryQuery, stateTransactionsQuery, stateByIdQuery } from './mqlQueries';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing state-detail MQL queries\n' + '='.repeat(60));

const SID = 'abc-123';
const s = stateSummaryQuery(SID);
const t = stateTransactionsQuery(SID);

// --- Summary query: single-row cross-joined counts ---------------------------
check('summary scopes to the given state id', s.includes(`and id = '${SID}'`));
check('summary counts instances via count(*)', /cnt_i as \(select count\(\*\)/.test(s));
check('summary counts resources via count(*)', /cnt_r as \(select count\(\*\)/.test(s));
check('summary counts providers via count(*)', /cnt_p as \(select count\(\*\)/.test(s));
check('summary computes edges from array_length(dependencies)',
  s.includes('sum(array_length(instances.dependencies, 1::integer))'));
check('summary dedups modules before counting (not count(distinct))',
  s.includes('mod_dedup') && !/count\s*\(\s*distinct/i.test(s));
check('summary projects all five state-summary fields',
  ['instances', 'resources', 'providers', 'edges', 'modules'].every((f) => s.includes(`as ${f}`)));
check('summary cross-joins the single-row count CTEs',
  s.includes('from cnt_i, cnt_r, cnt_p, edges, cnt_m'));

// --- Transactions query: associate via transaction_logs, newest first --------
check('tx query joins transactions to transaction_logs on tx_id',
  t.includes('transaction_logs.tx_id = transactions.id'));
check('tx query scopes by transaction_logs.state_id (the correct association)',
  t.includes(`transaction_logs.state_id = '${SID}'`));
check('tx query does NOT filter on transactions.state (the status-vs-id bug)',
  !/transactions\.state\s*=/.test(t));
check('tx query is newest-first', t.includes('order by transactions.created_at desc'));
check('tx query carries a bounded limit', /limit \d+/.test(t));
check('tx query group-by lists the selected transaction columns',
  t.includes('group by transactions.id'));
check('tx query projects the fields the adapter needs',
  ['id', 'state', 'created_at', 'completed_at'].every((f) => t.includes(`as ${f}`)));

// --- SQL literal escaping (state id is URL-derived) --------------------------
const evilS = stateSummaryQuery("x'; drop table states; --");
check('summary escapes single quotes in the state id',
  evilS.includes("and id = 'x''; drop table states; --'"));
const evilT = stateTransactionsQuery("x'; drop table transactions; --");
check('tx query escapes single quotes in the state id',
  evilT.includes("transaction_logs.state_id = 'x''; drop table transactions; --'"));

// --- limit override ----------------------------------------------------------
check('tx query honors an explicit limit', stateTransactionsQuery(SID, 50).includes('limit 50'));

// --- single state by id (#1063 detail-page fix) ------------------------------
const one = stateByIdQuery(SID);
check('by-id query filters on the state id', one.includes(`states.id = '${SID}'`));
check('by-id query excludes deleted states', one.includes('states.deleted_at is null'));
check('by-id query returns at most one row', one.includes('limit 1'));
check('by-id query projects the fields the detail adapter reads',
  ['id', 'name', 'workspace', 'group_id', 'created_at', 'updated_at'].every((f) => one.includes(`as ${f}`)));
check('by-id query escapes single quotes in the state id',
  stateByIdQuery("x'; drop table states; --").includes("states.id = 'x''; drop table states; --'"));

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

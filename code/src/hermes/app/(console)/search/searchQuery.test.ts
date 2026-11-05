/**
 * Tests for the /search tag-DSL -> MQL translator + query builder (#1068).
 * Run with: npx tsx "app/(console)/search/searchQuery.test.ts"
 */

import {
  searchWhereClause,
  searchInstancesQuery,
  searchRowToInstance,
  type SearchRow,
} from './searchQuery';

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean): void {
  if (cond) passed++;
  else { failed++; console.log(`  ❌ ${name}`); }
}

console.log('🧪 Testing /search tag-DSL -> MQL translation\n' + '='.repeat(60));

// --- empty ------------------------------------------------------------------
check('empty query -> null (match everything)', searchWhereClause('') === null);
check('whitespace query -> null', searchWhereClause('   ') === null);

// --- bare term -> substring ILIKE on type/address/module --------------------
const bare = searchWhereClause('bucket')!;
check('bare: ILIKE on type', bare.includes("resources.type ilike '%bucket%'"));
check('bare: ILIKE on address', bare.includes("instances.address ilike '%bucket%'"));
check('bare: ILIKE on module', bare.includes("resources.module ilike '%bucket%'"));
check('bare: OR-combined', bare.includes(' or '));
check('bare: no exact match', !bare.includes(' = '));
check('bare: LIKE metachar _ escaped', searchWhereClause('s3_bucket')!.includes("ilike '%s3\\_bucket%'"));

// --- exact field terms ------------------------------------------------------
check('type: -> exact', searchWhereClause('type:aws_instance') === "(resources.type = 'aws_instance')");
check('provider: -> exact col', searchWhereClause('provider:aws')!.includes("resources.provider = 'aws'"));
check('module: -> exact col', searchWhereClause('module:module.networking')!.includes("resources.module = 'module.networking'"));
check('address: -> instances.address', searchWhereClause('address:aws_vpc.main')!.includes("instances.address = 'aws_vpc.main'"));
check('resource_address: -> instances.resource_address', searchWhereClause('resource_address:aws_vpc.main')!.includes("instances.resource_address = 'aws_vpc.main'"));

// --- attr containment (nested for dotted keys — the #1068 fix) --------------
check('attr:tags.Name -> NESTED jsonb containment',
  searchWhereClause('attr:tags.Name:web')!.includes(`instances.attributes @> '{"tags":{"Name":"web"}}'::jsonb`));
check('attr:name -> flat jsonb containment',
  searchWhereClause('attr:name:foo')!.includes(`instances.attributes @> '{"name":"foo"}'::jsonb`));
check('tag:K:V -> normalized to nested attr:tags.K:V',
  searchWhereClause('tag:Environment:prod')!.includes(`instances.attributes @> '{"tags":{"Environment":"prod"}}'::jsonb`));

// --- boolean + NOT + quoting ------------------------------------------------
check('OR of two terms', searchWhereClause('type:a OR type:b') === "(resources.type = 'a') or (resources.type = 'b')");
check('AND of two terms', searchWhereClause('type:a AND module:m') === "(resources.type = 'a') and (resources.module = 'm')");
check('leading NOT', searchWhereClause('NOT type:x')!.includes("not (resources.type = 'x')"));
check('quoted value stripped', searchWhereClause('type:"aws instance"')!.includes("resources.type = 'aws instance'"));

// --- escaping ---------------------------------------------------------------
check('single quotes doubled in exact value',
  searchWhereClause("type:o'brien")!.includes("resources.type = 'o''brien'"));
check('LIKE metachars escaped in bare term',
  searchWhereClause('50%')!.includes("ilike '%50\\%%'"));
check('injection attempt is escaped, not executed',
  searchWhereClause("type:x'; drop table resources; --")!.includes("resources.type = 'x''; drop table resources; --'"));

// --- query builder ----------------------------------------------------------
const single = searchInstancesQuery('type:aws_instance', 's1', 50);
check('single-state query pins the state', single.includes("states.id = 's1'"));
check('query embeds the translated WHERE', single.includes("resources.type = 'aws_instance'"));
check('query selects full attributes + sensitive', single.includes('instances.attributes as attributes') && single.includes('instances.sensitive_attributes as sensitive_attributes'));
check('query is keyset-ordered', single.includes('order by instances.state_id, instances.address'));
check('query carries the limit', single.includes('limit 50'));

const all = searchInstancesQuery('type:aws_instance', undefined, 50);
check('all-states query has NO single-state filter', !/states\.id = '/.test(all));
check('all-states query still filters deleted states', all.includes('states.deleted_at is null'));

const empty = searchInstancesQuery('', 's1', 50);
check('empty q -> no search filter clause', !empty.includes('and (') || !/and \(.+ilike/.test(empty));

// --- row mapping ------------------------------------------------------------
const row: SearchRow = {
  address: 'aws_vpc.main', type: 'aws_vpc', provider: 'registry.terraform.io/hashicorp/aws',
  module: null, attributes: { region: 'us-east-1' }, sensitive_attributes: null,
  dependencies: null, state_id: 's1', state_name: 'prod',
};
const inst = searchRowToInstance(row);
check('row: null module -> undefined', inst.module === undefined);
check('row: null dependencies -> undefined', inst.dependencies === undefined);
check('row: state_name threaded', inst.state_name === 'prod');
check('row: attributes preserved', inst.attributes?.region === 'us-east-1');

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

/**
 * Tests for the slim Resources-page MQL queries.
 * Run with: npx tsx "app/(console)/instances/mqlQueries.test.ts"
 */

import {
  slimInstancesQuery,
  slimInstancesAllStatesQuery,
  instanceAttributesQuery,
  instanceRowToInstance,
  SLIM_ATTRIBUTE_KEYS,
  PAGE_LIMIT,
  type InstanceRow,
} from './mqlQueries';
import { LOCATION_SOURCE_FIELDS } from '@/lib/instances/metadata';
import { getInstanceTags } from '@/lib/instances/tags';
import { getLocation } from '@/lib/instances/metadata';
import type { Instance } from '@/lib/api/client';

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

console.log('🧪 Testing slim instances MQL queries\n' + '='.repeat(60));

// --- Allowlist stays in sync with the heuristics that consume it ---------
check(
  'slim allowlist includes tags (tag facets)',
  SLIM_ATTRIBUTE_KEYS.includes('tags')
);
for (const field of LOCATION_SOURCE_FIELDS) {
  check(
    `slim allowlist includes region source field "${field}"`,
    SLIM_ATTRIBUTE_KEYS.includes(field)
  );
}

const STATE = 'abc-123';
const q = slimInstancesQuery(STATE);

// --- Query shape ---------------------------------------------------------
check('query keeps a jsonb projection, not the full attributes column',
  q.includes('jsonb_build_object') && !/instances\.attributes as attributes/.test(q));
for (const key of SLIM_ATTRIBUTE_KEYS) {
  check(`query projects attribute key "${key}"`, q.includes(`instances.attributes->'${key}'`));
}
check('query does not select the heavy sensitive_attributes in the list',
  !/sensitive_attributes/.test(q));
check('query selects resource identity columns',
  q.includes('resources.type as type') &&
  q.includes('resources.provider as provider') &&
  q.includes('resources.module as module') &&
  q.includes('instances.dependencies as dependencies'));
check('query is keyset-ordered for cursor pagination',
  q.includes('order by instances.state_id, instances.address'));
check('query carries the page cap', q.includes(`limit ${PAGE_LIMIT}`));
check('query filters out deleted states', q.includes('states.deleted_at is null'));
check('query embeds the state id', q.includes(`states.id = '${STATE}'`));

// --- SQL literal escaping (state id / address are inlined) ---------------
const evil = slimInstancesQuery("x'; drop table instances; --");
check('single quotes in the state id are doubled (escaped)',
  evil.includes("states.id = 'x''; drop table instances; --'"));
const attrQ = instanceAttributesQuery('s1', 'aws_s3_bucket.b[\'weird\']');
check('attributes query escapes quotes in the address',
  attrQ.includes("instances.address = 'aws_s3_bucket.b[''weird'']'"));
check('attributes query returns both attribute maps',
  attrQ.includes('instances.attributes as attributes') &&
  attrQ.includes('instances.sensitive_attributes as sensitive_attributes'));

// --- All-states query: single cross-state cursor (no per-state fan-out) ---
const allQ = slimInstancesAllStatesQuery();
check('all-states query keeps the slim jsonb projection (not full attributes)',
  allQ.includes('jsonb_build_object') && !/instances\.attributes as attributes/.test(allQ));
for (const key of SLIM_ATTRIBUTE_KEYS) {
  check(`all-states query projects attribute key "${key}"`, allQ.includes(`instances.attributes->'${key}'`));
}
check('all-states query joins the state name for per-row labeling',
  allQ.includes('states.name as state_name'));
check('all-states query has NO single-state filter (walks every state)',
  !/states\.id = '/.test(allQ));
check('all-states query still filters out deleted states',
  allQ.includes('states.deleted_at is null'));
check('all-states query is keyset-ordered across states for the cross-state cursor',
  allQ.includes('order by instances.state_id, instances.address'));
check('all-states query carries the page cap', allQ.includes(`limit ${PAGE_LIMIT}`));
check('all-states query does not select the heavy sensitive_attributes',
  !/sensitive_attributes/.test(allQ));

// A row from the all-states query carries state_name; the converter uses it.
const allRow: InstanceRow = {
  address: 'aws_vpc.main', type: 'aws_vpc', provider: 'registry.terraform.io/hashicorp/aws',
  module: null, attributes: { region: 'us-east-1' }, dependencies: null,
  state_id: 's9', state_name: 'prod-us-east-1-core',
};
check('all-states row state_name flows through instanceRowToInstance (no arg needed)',
  instanceRowToInstance(allRow).state_name === 'prod-us-east-1-core');
check('explicit stateName arg still wins when the row omits state_name',
  instanceRowToInstance({ ...allRow, state_name: null }, 'prod').state_name === 'prod');

// --- Row conversion normalizes SQL nulls to undefined --------------------
const row: InstanceRow = {
  address: 'aws_instance.web',
  type: 'aws_instance',
  provider: 'registry.terraform.io/hashicorp/aws',
  module: null,
  attributes: { tags: { Name: 'web' }, region: 'us-east-1' },
  dependencies: null,
  state_id: 's1',
};
const inst = instanceRowToInstance(row, 'prod');
check('null module -> undefined', inst.module === undefined);
check('null dependencies -> undefined', inst.dependencies === undefined);
check('state name threaded through', inst.state_name === 'prod');

// --- The slim projection carries what the heuristics actually need --------
const slim: Instance = instanceRowToInstance(row);
check('slim attributes still yield the region facet', getLocation(slim) === 'us-east-1');
check('slim attributes still yield tag facets',
  getInstanceTags(slim).some((t) => t.key === 'Name' && t.value === 'web'));

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

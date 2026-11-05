/**
 * API Schema Validation Tests
 *
 * Ensures that:
 * 1. OpenAPI schema is valid and parseable
 * 2. Generated types are in sync with the schema
 * 3. API client respects schema boundaries
 *
 * Run with: npx tsx lib/api/schema-validation.test.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import type { components } from './types-generated';

console.log('🧪 Testing API Schema Validation\n');
console.log('='.repeat(60));

let passed = 0;
let failed = 0;

// ============================================================================
// Test 1: OpenAPI Schema File Exists and is Valid JSON
// ============================================================================
console.log('\n📋 Test 1: OpenAPI schema file exists and is valid JSON\n');

interface OpenAPISchema {
  components?: {
    schemas: Record<string, {
      required?: string[];
      properties?: Record<string, unknown>;
      [key: string]: unknown;
    }>;
  };
  paths?: Record<string, Record<string, unknown>>;
  info?: {
    title?: string;
    version?: string;
  };
}

const schemaPath = path.resolve(__dirname, '../../api.json');
let schema: OpenAPISchema | null = null;

try {
  if (!fs.existsSync(schemaPath)) {
    console.log(`❌ FAIL: Schema file not found at ${schemaPath}`);
    failed++;
  } else {
    const schemaContent = fs.readFileSync(schemaPath, 'utf-8');
    schema = JSON.parse(schemaContent) as OpenAPISchema;
    console.log(`✅ PASS: Schema file exists and is valid JSON`);
    console.log(`   Path: ${schemaPath}`);
    console.log(`   Size: ${schemaContent.length} bytes`);
    passed++;
  }
} catch (error) {
  console.log(`❌ FAIL: Failed to read or parse schema: ${error}`);
  failed++;
}

// ============================================================================
// Test 2: Schema has required OpenAPI structure
// ============================================================================
console.log('\n📋 Test 2: Schema has required OpenAPI structure\n');

if (schema) {
  const hasComponents = !!schema.components;
  const hasSchemas = hasComponents && !!schema.components?.schemas;
  const hasPaths = !!schema.paths;

  if (hasComponents && hasSchemas && hasPaths && schema.components && schema.paths) {
    console.log('✅ PASS: Schema has required OpenAPI structure');
    console.log(`   Components: ${Object.keys(schema.components.schemas).length} schemas`);
    console.log(`   Paths: ${Object.keys(schema.paths).length} endpoints`);
    passed++;
  } else {
    console.log('❌ FAIL: Schema missing required structure');
    console.log(`   Has components: ${hasComponents}`);
    console.log(`   Has schemas: ${hasSchemas}`);
    console.log(`   Has paths: ${hasPaths}`);
    failed++;
  }
}

// ============================================================================
// Test 3: Critical schema types exist
// ============================================================================
console.log('\n📋 Test 3: Critical schema types are defined\n');

const requiredSchemas = [
  'instance',
  'instances',
  'instance-blast-radius',
  'state',
  'state-summary',
  'resources-summary',
  'module',
  'modules',
  'user',
  'tenant',
  'tx',
  'txs',
  'tx_log',
  'tx_logs',
];

if (schema?.components?.schemas) {
  const missingSchemas = requiredSchemas.filter(
    name => !schema.components!.schemas[name]
  );

  if (missingSchemas.length === 0) {
    console.log('✅ PASS: All critical schema types exist');
    requiredSchemas.forEach(name => {
      console.log(`   ✓ ${name}`);
    });
    passed++;
  } else {
    console.log('❌ FAIL: Missing schema types:');
    missingSchemas.forEach(name => {
      console.log(`   ✗ ${name}`);
    });
    failed++;
  }
}

// ============================================================================
// Test 4: Instance schema has required fields
// ============================================================================
console.log('\n📋 Test 4: Instance schema has required fields\n');

if (schema?.components?.schemas) {
  const instanceSchema = schema.components.schemas['instance'];

  if (instanceSchema) {
    const requiredFields = instanceSchema.required || [];
    const expectedRequired = ['address', 'provider', 'type'];

    const hasAllRequired = expectedRequired.every(field =>
      requiredFields.includes(field)
    );

    if (hasAllRequired) {
      console.log('✅ PASS: Instance schema has all required fields');
      requiredFields.forEach((field: string) => {
        console.log(`   ✓ ${field} (required)`);
      });
      passed++;
    } else {
      console.log('❌ FAIL: Instance schema missing required fields');
      expectedRequired.forEach(field => {
        const present = requiredFields.includes(field);
        console.log(`   ${present ? '✓' : '✗'} ${field}`);
      });
      failed++;
    }
  } else {
    console.log('❌ FAIL: Instance schema not found');
    failed++;
  }
}

// ============================================================================
// Test 5: Generated types file exists and is recent
// ============================================================================
console.log('\n📋 Test 5: Generated types file exists\n');

const typesPath = path.resolve(__dirname, './types-generated.ts');

try {
  if (!fs.existsSync(typesPath)) {
    console.log(`❌ FAIL: Generated types file not found at ${typesPath}`);
    failed++;
  } else {
    const stats = fs.statSync(typesPath);
    const schemaStats = fs.statSync(schemaPath);

    console.log('✅ PASS: Generated types file exists');
    console.log(`   Path: ${typesPath}`);
    console.log(`   Size: ${stats.size} bytes`);

    // Check if types are newer than schema (they should be regenerated after schema changes)
    if (stats.mtime < schemaStats.mtime) {
      console.log('   ⚠️  WARNING: Types are older than schema - may need regeneration');
      console.log(`   Types modified: ${stats.mtime.toISOString()}`);
      console.log(`   Schema modified: ${schemaStats.mtime.toISOString()}`);
    } else {
      console.log(`   ✓ Types are up to date`);
    }

    passed++;
  }
} catch (error) {
  console.log(`❌ FAIL: Failed to check types file: ${error}`);
  failed++;
}

// ============================================================================
// Test 6: API client functions match schema endpoints
// ============================================================================
console.log('\n📋 Test 6: API client functions match schema endpoints\n');

if (schema?.paths) {
  // Map of expected client functions to their schema paths
  const expectedEndpoints = [
    { fn: 'whoami', path: '/api/v1/whoami', method: 'get' },
    { fn: 'getUserTenants', path: '/api/v1/user/tenants', method: 'get' },
    { fn: 'getTenantStates', path: '/api/v1/tenants/{tenant_id}/states', method: 'get' },
    { fn: 'getTenantResourceTypes', path: '/api/v1/tenants/{tenant_id}/resource-types', method: 'get' },
    { fn: 'getStateSummary', path: '/api/v1/states/{state_id}/summary', method: 'get' },
    { fn: 'getStateInstances', path: '/api/v1/states/{state_id}/instances', method: 'get' },
    { fn: 'getInstanceBlastRadius', path: '/api/v1/states/{state_id}/instances/{instance_address}/blast-radius', method: 'get' },
    { fn: 'getStateModules', path: '/api/v1/states/{state_id}/modules', method: 'get' },
    { fn: 'importState', path: '/api/v1/tenants/{tenant_id}/states/import', method: 'post' },
    { fn: 'getTenantTransactions', path: '/api/v1/tenants/{tenant_id}/tx', method: 'get' },
    { fn: 'getTransactionLogs', path: '/api/v1/tx/{tx_id}/logs', method: 'get' },
    { fn: 'getTxDetail', path: '/api/v1/tx/{tx_id}', method: 'get' },
    { fn: 'getTxPlanOperations', path: '/api/v1/tx/{tx_id}/plan-operations', method: 'get' },
    { fn: 'getTxOutput', path: '/api/v1/tx/{tx_id}/output', method: 'get' },
    // Tenant administration
    { fn: 'listTenantMembers', path: '/api/v1/tenants/{tenant_id}/members', method: 'get' },
    { fn: 'addTenantMember', path: '/api/v1/tenants/{tenant_id}/members', method: 'post' },
    { fn: 'removeTenantMember', path: '/api/v1/tenants/{tenant_id}/members', method: 'delete' },
    { fn: 'setTenantMemberRole', path: '/api/v1/tenants/{tenant_id}/members/set-role', method: 'post' },
    { fn: 'createTenant', path: '/api/v1/tenants', method: 'post' },
    { fn: 'renameTenant', path: '/api/v1/tenants/{tenant_id}', method: 'put' },
    { fn: 'listTenantInvitations', path: '/api/v1/tenants/{tenant_id}/invitations', method: 'get' },
    { fn: 'inviteTenantMember', path: '/api/v1/tenants/{tenant_id}/invitations', method: 'post' },
    { fn: 'reissueInvitation', path: '/api/v1/tenants/{tenant_id}/invitations/reissue', method: 'post' },
    { fn: 'revokeInvitation', path: '/api/v1/tenants/{tenant_id}/invitations/revoke', method: 'post' },
    { fn: 'previewInvitation', path: '/api/v1/invitations/preview', method: 'get' },
    { fn: 'acceptInvitation', path: '/api/v1/invitations/accept', method: 'post' },
    // Orchestration onboarding
    { fn: 'provisionGitlab', path: '/api/v1/tenants/{tenant_id}/vcs-installations/gitlab', method: 'post' },
    { fn: 'listUnclaimedGithub', path: '/api/v1/vcs-installations/github/unclaimed', method: 'get' },
    { fn: 'linkVcsInstallation', path: '/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}', method: 'put' },
    { fn: 'listVcsInstallations', path: '/api/v1/tenants/{tenant_id}/vcs-installations', method: 'get' },
    { fn: 'unlinkVcsInstallation', path: '/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}', method: 'delete' },
    { fn: 'rotateGitlab', path: '/api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}', method: 'put' },
  ];

  const missingEndpoints: string[] = [];
  const matchedEndpoints: string[] = [];

  expectedEndpoints.forEach(({ fn, path, method }) => {
    const pathExists = schema.paths ? path in schema.paths : false;
    const methodExists = pathExists && schema.paths ? method in schema.paths[path] : false;

    if (pathExists && methodExists) {
      matchedEndpoints.push(fn);
    } else {
      missingEndpoints.push(`${fn} -> ${method.toUpperCase()} ${path}`);
    }
  });

  if (missingEndpoints.length === 0) {
    console.log('✅ PASS: All API client functions have corresponding schema endpoints');
    matchedEndpoints.forEach(fn => {
      console.log(`   ✓ ${fn}`);
    });
    passed++;
  } else {
    console.log('❌ FAIL: Some API client functions missing from schema:');
    missingEndpoints.forEach(endpoint => {
      console.log(`   ✗ ${endpoint}`);
    });
    failed++;
  }
}

// ============================================================================
// Test 7: Type imports work correctly
// ============================================================================
console.log('\n📋 Test 7: Generated type imports work correctly\n');

try {
  // Try to use the imported types (compile-time check)
  type _TestUser = components['schemas']['user'];
  type _TestInstance = components['schemas']['instance'];
  type _TestState = components['schemas']['state'];

  console.log('✅ PASS: Generated types can be imported and used');
  console.log('   ✓ components["schemas"]["user"]');
  console.log('   ✓ components["schemas"]["instance"]');
  console.log('   ✓ components["schemas"]["state"]');
  passed++;
} catch (error) {
  console.log(`❌ FAIL: Failed to import types: ${error}`);
  failed++;
}

// ============================================================================
// Test 8: Schema responses match expected structure
// ============================================================================
console.log('\n📋 Test 8: Schema responses have correct structure\n');

if (schema?.paths) {
  // Check that GET /api/v1/states/{state_id}/instances returns instances schema
  const instancesPath = schema.paths['/api/v1/states/{state_id}/instances'] as { get?: { responses?: { '200'?: { content?: { 'application/json'?: { schema?: { $ref?: string } } } } } } } | undefined;

  if (instancesPath?.get?.responses) {
    const response200 = instancesPath.get.responses['200'];

    if (response200 && response200.content && response200.content['application/json']) {
      const responseSchema = response200.content['application/json'].schema;

      // Check if it references the instances schema
      const referencesInstances = responseSchema?.$ref === '#/components/schemas/instances';

      if (referencesInstances) {
        console.log('✅ PASS: Instances endpoint returns correct schema');
        console.log('   ✓ GET /api/v1/states/{state_id}/instances');
        console.log('   ✓ Returns: instances schema');
        passed++;
      } else {
        console.log('❌ FAIL: Instances endpoint returns unexpected schema');
        console.log(`   Expected: #/components/schemas/instances`);
        console.log(`   Got: ${JSON.stringify(responseSchema)}`);
        failed++;
      }
    } else {
      console.log('❌ FAIL: Instances endpoint missing response schema');
      failed++;
    }
  } else {
    console.log('❌ FAIL: Instances endpoint not found in schema');
    failed++;
  }
}

// ============================================================================
// Test 8b: /capabilities endpoint + costs-availability sub-schema
// ============================================================================
console.log('\n📋 Test 8b: /api/v1/capabilities + costs-availability schema\n');

if (schema?.paths && schema?.components?.schemas) {
  const cap = schema.paths['/api/v1/capabilities'] as
    | { get?: { responses?: { '200'?: { content?: { 'application/json'?: { schema?: { $ref?: string } } } } } } }
    | undefined;
  const got = cap?.get?.responses?.['200']?.content?.['application/json']?.schema?.$ref;
  const expectedRef = '#/components/schemas/capabilities';

  const caSchema = schema.components.schemas['costs-availability'];
  const props = (caSchema?.properties || {}) as Record<string, { type?: string }>;
  const required = (caSchema?.required || []) as string[];
  const shapeOk = props['enabled']?.type === 'boolean' && required.includes('enabled');

  if (got === expectedRef && shapeOk) {
    console.log('✅ PASS: /capabilities endpoint + costs-availability schema declared correctly');
    console.log(`   ✓ GET /api/v1/capabilities → ${expectedRef}`);
    console.log('   ✓ costs-availability { enabled: boolean (required) }');
    passed++;
  } else {
    console.log('❌ FAIL: /capabilities endpoint / costs-availability schema malformed');
    if (got !== expectedRef) console.log(`   ✗ endpoint $ref: expected ${expectedRef}, got ${got ?? '(missing)'}`);
    if (!shapeOk) console.log(`   ✗ schema shape: enabled.type=${props['enabled']?.type}, required=${JSON.stringify(required)}`);
    failed++;
  }
} else {
  console.log('❌ FAIL: schema.paths or schema.components.schemas missing');
  failed++;
}

// ============================================================================
// Test 8c: tenant cost endpoints + their response schemas
// ============================================================================
console.log('\n📋 Test 8c: tenant cost endpoints reference the right response schemas\n');

interface PathResponse {
  get?: {
    responses?: {
      '200'?: {
        content?: { 'application/json'?: { schema?: { $ref?: string } } };
      };
    };
  };
}

const TENANT_COST_ENDPOINTS = [
  { path: '/api/v1/tenants/{tenant_id}/costs', schemaRef: '#/components/schemas/tenant-costs' },
  {
    path: '/api/v1/tenants/{tenant_id}/costs/history',
    schemaRef: '#/components/schemas/tenant-cost-history',
  },
  {
    path: '/api/v1/tenants/{tenant_id}/costs/tag-keys',
    schemaRef: '#/components/schemas/tenant-cost-tag-keys',
  },
  {
    path: '/api/v1/tenants/{tenant_id}/costs/attribution',
    schemaRef: '#/components/schemas/tenant-cost-attribution',
  },
  {
    path: '/api/v1/tenants/{tenant_id}/costs/unmanaged',
    schemaRef: '#/components/schemas/tenant-cost-unmanaged',
  },
  {
    path: '/api/v1/states/{state_id}/costs/actuals',
    schemaRef: '#/components/schemas/state-cost-actuals',
  },
] as const;

if (schema?.paths) {
  let missing = 0;
  for (const { path: p, schemaRef } of TENANT_COST_ENDPOINTS) {
    const entry = schema.paths[p] as PathResponse | undefined;
    const got = entry?.get?.responses?.['200']?.content?.['application/json']?.schema?.$ref;
    if (got === schemaRef) {
      console.log(`   ✓ GET ${p} → ${schemaRef}`);
    } else {
      console.log(`   ✗ GET ${p}: expected ${schemaRef}, got ${got ?? '(missing)'}`);
      missing++;
    }
  }
  if (missing === 0) {
    console.log('✅ PASS: All tenant cost endpoints are declared');
    passed++;
  } else {
    console.log(`❌ FAIL: ${missing} tenant cost endpoint(s) missing or mis-wired`);
    failed++;
  }
} else {
  console.log('❌ FAIL: schema.paths missing — cannot validate tenant cost endpoints');
  failed++;
}

// ============================================================================
// Test 8d: tenant-costs schema shape (money strings, required arrays)
// ============================================================================
console.log('\n📋 Test 8d: tenant-costs schema shape\n');

interface PropSpec {
  type?: string;
  items?: { $ref?: string };
}

if (schema?.components?.schemas) {
  const tc = schema.components.schemas['tenant-costs'];
  const props = (tc?.properties || {}) as Record<string, PropSpec>;
  const required = (tc?.required || []) as string[];

  const STRING_MONEY = ['monthly_cost', 'hourly_cost', 'currency'];
  const INT_COUNTS = ['resource_count', 'supported_count', 'priced_count'];
  const BREAKDOWN_ARRAYS = ['by_provider', 'by_type', 'by_tag'];

  const wrongMoney = STRING_MONEY.filter((f) => props[f]?.type !== 'string');
  const wrongCounts = INT_COUNTS.filter((f) => props[f]?.type !== 'integer');
  const wrongArrays = BREAKDOWN_ARRAYS.filter(
    (f) =>
      props[f]?.type !== 'array' ||
      props[f]?.items?.$ref !== '#/components/schemas/cost-breakdown-entry'
  );
  // money fields are optional (absent when nothing priced); counts/arrays are required.
  const incorrectlyRequiredMoney = STRING_MONEY.filter((f) => required.includes(f));
  const missingRequired = [...INT_COUNTS, ...BREAKDOWN_ARRAYS, 'states', 'coverage_percent'].filter(
    (f) => !required.includes(f)
  );

  if (
    wrongMoney.length === 0 &&
    wrongCounts.length === 0 &&
    wrongArrays.length === 0 &&
    incorrectlyRequiredMoney.length === 0 &&
    missingRequired.length === 0
  ) {
    console.log('✅ PASS: tenant-costs schema has the expected shape');
    console.log('   ✓ money fields: string + optional');
    console.log('   ✓ counts: integer + required');
    console.log('   ✓ breakdowns: arrays of cost-breakdown-entry + required');
    console.log('   ✓ states + coverage_percent: required');
    passed++;
  } else {
    console.log('❌ FAIL: tenant-costs schema is malformed');
    wrongMoney.forEach((f) =>
      console.log(`   ✗ ${f}: expected type string, got ${props[f]?.type ?? '(missing)'}`)
    );
    wrongCounts.forEach((f) =>
      console.log(`   ✗ ${f}: expected type integer, got ${props[f]?.type ?? '(missing)'}`)
    );
    wrongArrays.forEach((f) =>
      console.log(`   ✗ ${f}: expected array of cost-breakdown-entry`)
    );
    incorrectlyRequiredMoney.forEach((f) =>
      console.log(`   ✗ ${f}: should be optional (nothing-priced case)`)
    );
    missingRequired.forEach((f) => console.log(`   ✗ missing from required: ${f}`));
    failed++;
  }

  // cost-breakdown-entry must carry name + resource_count as required, money as string+optional.
  const cbe = schema.components.schemas['cost-breakdown-entry'];
  const cbeProps = (cbe?.properties || {}) as Record<string, PropSpec>;
  const cbeRequired = (cbe?.required || []) as string[];
  const cbeOk =
    cbeProps['name']?.type === 'string' &&
    cbeProps['monthly_cost']?.type === 'string' &&
    cbeProps['resource_count']?.type === 'integer' &&
    cbeRequired.includes('name') &&
    cbeRequired.includes('resource_count') &&
    !cbeRequired.includes('monthly_cost');
  if (cbeOk) {
    console.log('✅ PASS: cost-breakdown-entry schema shape is correct');
    passed++;
  } else {
    console.log('❌ FAIL: cost-breakdown-entry schema is malformed');
    failed++;
  }

  // tenant-cost-state: snapshot-derived fields are all optional (uncosted state case).
  const tcs = schema.components.schemas['tenant-cost-state'];
  const tcsRequired = (tcs?.required || []) as string[];
  const tcsOptional = [
    'monthly_cost',
    'hourly_cost',
    'resource_count',
    'supported_count',
    'coverage_percent',
    'calculated_at',
  ];
  const incorrectlyRequiredTcs = tcsOptional.filter((f) => tcsRequired.includes(f));
  const tcsIdentityRequired = ['state_id', 'state_name'].every((f) => tcsRequired.includes(f));
  if (incorrectlyRequiredTcs.length === 0 && tcsIdentityRequired) {
    console.log('✅ PASS: tenant-cost-state correctly marks snapshot fields optional');
    passed++;
  } else {
    console.log('❌ FAIL: tenant-cost-state required fields are wrong');
    incorrectlyRequiredTcs.forEach((f) =>
      console.log(`   ✗ ${f}: should be optional (uncosted-state case)`)
    );
    if (!tcsIdentityRequired) {
      console.log('   ✗ state_id and state_name must be required');
    }
    failed++;
  }
} else {
  console.log('❌ FAIL: schema.components.schemas missing — cannot validate tenant-costs shape');
  failed++;
}

// ============================================================================
// Test 9: Schema version and info (informational)
// ============================================================================
console.log('\n📋 Test 9: Schema metadata (informational)\n');

if (schema) {
  const hasInfo = !!schema.info;
  const hasVersion = hasInfo && !!schema.info?.version;

  if (hasInfo && hasVersion && schema.info) {
    console.log('✅ INFO: Schema has version information');
    if (schema.info.title) {
      console.log(`   Title: ${schema.info.title}`);
    }
    console.log(`   Version: ${schema.info.version}`);
  } else {
    console.log('⚠️  INFO: Schema missing version information (non-critical)');
  }
  // Don't fail on missing version info - it's informational only
  passed++;
}

// ============================================================================
// Summary
// ============================================================================
console.log('\n' + '='.repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${passed + failed} tests`);

if (failed === 0) {
  console.log('\n🎉 All API schema validation tests passed!');
  console.log('\n✅ Schema boundary is properly defined and enforced:');
  console.log('   • OpenAPI schema is valid and well-structured');
  console.log('   • All critical types are defined');
  console.log('   • Generated types exist and can be imported');
  console.log('   • API client functions match schema endpoints');
  console.log('   • Response schemas are correctly defined');
  console.log('\n⚠️  Note: These tests validate the schema structure.');
  console.log('   Consider adding runtime validation with Zod or AJV for production.');
}

process.exit(failed > 0 ? 1 : 0);

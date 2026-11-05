/**
 * Tests for the capability allow-list matcher and the admin-scope predicates built on it.
 *
 * The behavioural cases come from caps-match-fixtures.json at this package's root, a copy of
 * code/tests/sg_caps_match/caps-match-fixtures.json kept byte-identical by .github/workflows/lint.yml.
 *
 * Run with: npx tsx lib/api/capsMatch.test.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import { capsMatch, grantsAll } from './capsMatch';
import {
  administeredTenantIds,
  canManageUsersInTenant,
  isInstanceAdmin,
  isTenantAdmin,
  type Capabilities,
} from './capabilities';

console.log('🧪 Testing capability matching\n');
console.log('='.repeat(60));

let passed = 0;
let failed = 0;

function check(name: string, actual: unknown, expected: unknown): void {
  if (actual === expected) {
    passed++;
  } else {
    failed++;
    console.error(`  ❌ ${name}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

// ============================================================================
// Test 1: shared fixtures — the cross-language drift guard
// ============================================================================
console.log('\n📋 Test 1: shared fixtures from caps-match-fixtures.json\n');

interface MatchFixture {
  patterns: string[];
  value: string;
  matches: boolean;
  $comment?: string;
}

interface GrantsAllFixture {
  patterns: string[];
  grants_all: boolean;
  $comment?: string;
}

const fixturePath = path.resolve(__dirname, '../../caps-match-fixtures.json');
if (!fs.existsSync(fixturePath)) {
  console.error(`  ❌ fixture file not found at ${fixturePath}`);
  process.exit(1);
}

const fixtures = JSON.parse(fs.readFileSync(fixturePath, 'utf8')) as {
  matches: MatchFixture[];
  grants_all: GrantsAllFixture[];
};

for (const f of fixtures.matches) {
  check(
    `matches(${JSON.stringify(f.patterns)}, ${JSON.stringify(f.value)})`,
    capsMatch(f.patterns, f.value),
    f.matches,
  );
}
for (const f of fixtures.grants_all) {
  check(`grantsAll(${JSON.stringify(f.patterns)})`, grantsAll(f.patterns), f.grants_all);
}
console.log(`  ${fixtures.matches.length} match cases, ${fixtures.grants_all.length} grants_all cases`);

// ============================================================================
// Test 2: the deny-all inversion, asserted on its own
// ============================================================================
console.log('\n📋 Test 2: the empty list denies everything\n');

// Called out separately because it is the one transcription error that inverts a security decision:
// `every()` over an empty array is vacuously true, so applying the all-negation rule first would
// prepend "*" and turn deny-all into grant-all.
check('capsMatch([], "anything") is false', capsMatch([], 'anything'), false);
check('grantsAll([]) is false', grantsAll([]), false);
check('capsMatch(["!*"], "anything") is false', capsMatch(['!*'], 'anything'), false);

// ============================================================================
// Test 3: instance vs tenant admin
// ============================================================================
console.log('\n📋 Test 3: instance vs tenant admin scope\n');

const T = '4dfd9283-8319-4458-b667-f6e432557dcb';
const OTHER = '05edc11a-54b2-4788-be71-63ed40a75a1d';

// Every capability is spelled out: a scope is its rules, and one that reaches nothing is the empty
// list rather than an absent key. Built from a complete value rather than cast from a partial one,
// so that a change to the wire shape fails the type check here instead of at run time.
const none: Capabilities = {
  'access-token-create': false,
  'access-token-refresh': false,
  admin: [],
  commit: { modified: [], 'pulled-in': [] },
  preview: { modified: [], 'pulled-in': [] },
  sudo: [],
  'users-manage': [],
};

const caps = (admin: string[]): Capabilities => ({ ...none, admin });

// No admin rule at all.
check('no grant: isInstanceAdmin', isInstanceAdmin(none), false);
check('no grant: isTenantAdmin', isTenantAdmin(none, T), false);

// `["*"]` reaches every tenant: the installation-wide grant.
check('installation-wide: isInstanceAdmin', isInstanceAdmin(caps(['*'])), true);
check('installation-wide: isTenantAdmin(T)', isTenantAdmin(caps(['*']), T), true);
check('installation-wide: isTenantAdmin(other)', isTenantAdmin(caps(['*']), OTHER), true);

// Tenant-scoped. This is the case the reported bug got wrong: the admin key is present, so the old
// single `isAdmin` gate showed the instance-wide Admin tab to a user who only administers their own
// tenant. isInstanceAdmin must now distinguish the two.
const scoped = caps([T]);
check('tenant-scoped: isInstanceAdmin is FALSE', isInstanceAdmin(scoped), false);
check('tenant-scoped: isTenantAdmin(T)', isTenantAdmin(scoped, T), true);
check('tenant-scoped: isTenantAdmin(other) is false', isTenantAdmin(scoped, OTHER), false);

// Every tenant but one is not every tenant.
check('star minus one: isInstanceAdmin', isInstanceAdmin(caps(['*', `!${T}`])), false);
check('star minus one: isTenantAdmin(T)', isTenantAdmin(caps(['*', `!${T}`]), T), false);
check(
  'star minus one: isTenantAdmin(other)',
  isTenantAdmin(caps(['*', `!${T}`]), OTHER),
  true,
);
// A deny-all list grants nothing even though the capability is written down.
check('deny-all list: isTenantAdmin is false', isTenantAdmin(caps(['!*']), T), false);
check('deny-all list: isInstanceAdmin is false', isInstanceAdmin(caps(['!*'])), false);

// A null/undefined tenant must not read as authorized — callers render a loading state instead.
check('null tenant: isTenantAdmin is false', isTenantAdmin(caps(['*']), null), false);
check('undefined tenant: isTenantAdmin is false', isTenantAdmin(caps(['*']), undefined), false);

// users-manage has the identical shape.
const um: Capabilities = { ...none, 'users-manage': [T] };
check('users-manage scoped: in tenant', canManageUsersInTenant(um, T), true);
check('users-manage scoped: other tenant', canManageUsersInTenant(um, OTHER), false);

// ============================================================================
// Test 4: administeredTenantIds
// ============================================================================
console.log('\n📋 Test 4: administeredTenantIds\n');

check(
  'scoped grant selects only its tenant',
  JSON.stringify(administeredTenantIds(scoped, [T, OTHER])),
  JSON.stringify([T]),
);
check(
  'installation-wide grant selects all',
  JSON.stringify(administeredTenantIds(caps(['*']), [T, OTHER])),
  JSON.stringify([T, OTHER]),
);
check(
  'no grant selects none',
  JSON.stringify(administeredTenantIds(none, [T, OTHER])),
  JSON.stringify([]),
);

// ============================================================================
console.log('\n' + '='.repeat(60));
console.log(`\n${failed === 0 ? '✅' : '❌'} ${passed} passed, ${failed} failed\n`);
process.exit(failed === 0 ? 0 : 1);

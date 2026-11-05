/**
 * Tests for first-run tenant naming logic (#1772)
 * Run with: npx tsx lib/tenant-naming.test.ts
 */

import {
  MAX_TENANT_NAME,
  isReservedTenantName,
  isValidTenantName,
  markTenantNamingSeen,
  randomTenantName,
  shouldPromptForTenantName,
} from './tenant-naming';

// Minimal localStorage stand-in so the seen-marker functions exercise their
// real paths under tsx (no DOM).
const store = new Map<string, string>();
(globalThis as { window?: unknown }).window = {
  localStorage: {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
  },
};

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

// A deterministic generator cycling through supplied values.
function cyclingRand(values: number[]): () => number {
  let i = 0;
  return () => values[i++ % values.length];
}

const noReach = { modified: [], 'pulled-in': [] };

/** A capabilities value granting admin over exactly these tenants, and nothing else. */
function adminOf(...tenants: string[]) {
  return {
    'access-token-create': false,
    'access-token-refresh': false,
    admin: tenants,
    commit: noReach,
    preview: noReach,
    sudo: [],
    'users-manage': [],
  };
}

type PromptArgs = Parameters<typeof shouldPromptForTenantName>[0];

// The eligible case, so each test below names only the one thing it changes.
function promptArgs(overrides: Partial<PromptArgs> = {}): PromptArgs {
  return {
    mode: 'COMMUNISM',
    licenseLoading: false,
    tenantLoading: false,
    user: {
      name: 'Jane Doe',
      email: 'jane@example.com',
      capabilities: adminOf('t-1'),
    },
    currentTenant: { id: 't-1', name: 'Jane Doe' },
    tenantCount: 1,
    ...overrides,
  };
}

const tests: TestCase[] = [
  {
    name: 'prompts a fresh admin whose tenant still carries the derived name',
    fn: () => shouldPromptForTenantName(promptArgs()),
  },
  {
    name: 'the derived name is matched after trimming, as the server trims it',
    fn: () =>
      shouldPromptForTenantName(
        promptArgs({
          user: {
            name: '  Jane Doe  ',
            capabilities: adminOf('t-1'),
          },
        }),
      ),
  },
  {
    name: 'the email form of the derived name is matched too',
    fn: () =>
      shouldPromptForTenantName(
        promptArgs({ currentTenant: { id: 't-1', name: 'jane@example.com' } }),
      ),
  },
  {
    name: 'a renamed tenant is never prompted again',
    fn: () =>
      !shouldPromptForTenantName(
        promptArgs({ currentTenant: { id: 't-1', name: 'prod-infra' } }),
      ),
  },
  {
    name: 'a blank display name never counts as the derived name',
    fn: () =>
      !shouldPromptForTenantName(
        promptArgs({
          user: { name: '   ', capabilities: adminOf('t-1') },
          currentTenant: { id: 't-1', name: '' },
        }),
      ),
  },
  {
    name: 'only communism mode prompts',
    fn: () => !shouldPromptForTenantName(promptArgs({ mode: undefined })),
  },
  {
    name: 'never prompts while either fetch is still in flight',
    fn: () =>
      !shouldPromptForTenantName(promptArgs({ licenseLoading: true })) &&
      !shouldPromptForTenantName(promptArgs({ tenantLoading: true })),
  },
  {
    name: 'never prompts without a user or without a tenant',
    fn: () =>
      !shouldPromptForTenantName(promptArgs({ user: null })) &&
      !shouldPromptForTenantName(promptArgs({ currentTenant: null })),
  },
  {
    name: 'a second tenant means the user has moved past the sandbox',
    fn: () => !shouldPromptForTenantName(promptArgs({ tenantCount: 2 })),
  },
  {
    name: 'never prompts without the tenant admin capability the rename needs',
    fn: () =>
      !shouldPromptForTenantName(
        promptArgs({
          user: { name: 'Jane Doe', email: 'jane@example.com', capabilities: adminOf() },
        }),
      ) &&
      !shouldPromptForTenantName(
        promptArgs({
          user: {
            name: 'Jane Doe',
            email: 'jane@example.com',
            capabilities: adminOf('t-other'),
          },
        }),
      ),
  },
  {
    name: 'a display name is a valid tenant name',
    fn: () => isValidTenantName('Acme Platform Team') && isValidTenantName('Jane Doe'),
  },
  {
    name: 'blank and whitespace-only names are invalid',
    fn: () => !isValidTenantName('') && !isValidTenantName('   '),
  },
  {
    name: "the length bound is the server's, applied after trimming",
    fn: () =>
      isValidTenantName('a'.repeat(MAX_TENANT_NAME)) &&
      !isValidTenantName('a'.repeat(MAX_TENANT_NAME + 1)) &&
      isValidTenantName(`  ${'a'.repeat(MAX_TENANT_NAME)}  `),
  },
  {
    name: 'random suggestions are always valid tenant names',
    fn: () => {
      for (let i = 0; i < 500; i++) {
        if (!isValidTenantName(randomTenantName())) return false;
      }
      return true;
    },
  },
  {
    name: 'random suggestion is deterministic under injected rand',
    fn: () => {
      const a = randomTenantName(cyclingRand([0, 0.99]));
      const b = randomTenantName(cyclingRand([0, 0.99]));
      return a === b && isValidTenantName(a);
    },
  },
  {
    name: 'suggestions carry a random tail drawn from the full alphabet',
    fn: () =>
      randomTenantName(() => 0) === 'bold-basalt-aaaa' &&
      randomTenantName(() => 0.999999) === 'vivid-vector-9999',
  },
  {
    name: 'suggestions come from a pool wide enough not to repeat',
    fn: () => {
      const seen = new Set<string>();
      for (let i = 0; i < 1000; i++) seen.add(randomTenantName());
      // One repeat tolerated so the test cannot flake; the pool is ~4.3e8, so
      // even one is already a once-in-a-thousand-runs event.
      return seen.size >= 999;
    },
  },
  {
    name: 'extreme rand values stay in list bounds',
    fn: () =>
      isValidTenantName(randomTenantName(() => 0)) &&
      isValidTenantName(randomTenantName(() => 0.999999)),
  },
  {
    name: 'reserved names match exactly, case-insensitively, trimmed',
    fn: () =>
      isReservedTenantName('stategraph') &&
      isReservedTenantName('Stategraph') &&
      isReservedTenantName('  ADMIN  ') &&
      isReservedTenantName('support'),
  },
  {
    name: 'reserved detection sees through invisible characters',
    fn: () =>
      isReservedTenantName('ad\u200bmin') &&
      isReservedTenantName('\u00a0support\u00a0') &&
      isReservedTenantName('stategraph\ufeff'),
  },
  {
    name: 'variants are not reserved',
    fn: () =>
      !isReservedTenantName('stategraph-hq') &&
      !isReservedTenantName('admin1') &&
      !isReservedTenantName('') &&
      !isReservedTenantName('swift-ember'),
  },
  {
    name: 'random suggestions never collide with the reserved list',
    fn: () => {
      for (let i = 0; i < 500; i++) {
        if (isReservedTenantName(randomTenantName())) return false;
      }
      return true;
    },
  },
  {
    name: 'a dismissal retires the prompt for that tenant',
    fn: () => {
      const args = promptArgs({
        user: {
          name: 'Jane Doe',
          email: 'jane@example.com',
          capabilities: adminOf('t-seen'),
        },
        currentTenant: { id: 't-seen', name: 'Jane Doe' },
      });
      if (!shouldPromptForTenantName(args)) return false;
      markTenantNamingSeen('t-seen');
      return !shouldPromptForTenantName(args);
    },
  },
  {
    name: 'the dismissal marker is per tenant',
    fn: () => {
      markTenantNamingSeen('t-other-tenant');
      return shouldPromptForTenantName(promptArgs());
    },
  },
];

tests.forEach((test) => {
  try {
    if (test.fn()) {
      console.log(`PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`FAIL: ${test.name}`);
      failed++;
    }
  } catch (e) {
    console.log(`FAIL: ${test.name} (threw: ${e})`);
    failed++;
  }
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);

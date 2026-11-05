/**
 * Tests for the login page's auto-forward decision and its per-tab loop guard (#1774)
 * Run with: npx tsx lib/auth/loginAutoForward.test.ts
 */

import assert from 'node:assert';
import { markAutoForwarded, recentlyAutoForwarded, shouldAutoForward } from './loginAutoForward';

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

const setWindow = (sessionStorage: unknown) => {
  (globalThis as { window?: unknown }).window = { sessionStorage };
};

const memoryStorage = () => {
  const store = new Map<string, string>();
  return {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, v),
  };
};

const oidc = { name: 'oidc' };
const google = { name: 'google' };

test('a sole oidc provider forwards', () => {
  assert.equal(shouldAutoForward({ providers: [oidc], promptRequested: false }), true);
});

test('a sole google provider keeps the button', () => {
  assert.equal(shouldAutoForward({ providers: [google], promptRequested: false }), false);
});

test('several providers keep the buttons', () => {
  assert.equal(shouldAutoForward({ providers: [oidc, google], promptRequested: false }), false);
});

test('local auth (no providers) never forwards', () => {
  assert.equal(shouldAutoForward({ providers: [], promptRequested: false }), false);
});

test('prompt=1 holds the forward back', () => {
  assert.equal(shouldAutoForward({ providers: [oidc], promptRequested: true }), false);
});

test('a tab that never forwarded is not recent', () => {
  setWindow(memoryStorage());
  assert.equal(recentlyAutoForwarded(1_000_000), false);
});

test('a forward is recent within 30 s and stops being recent after', () => {
  setWindow(memoryStorage());
  markAutoForwarded(1_000_000);
  assert.equal(recentlyAutoForwarded(1_000_000 + 29_999), true);
  assert.equal(recentlyAutoForwarded(1_000_000 + 30_000), false);
});

test('an unparsable marker is not recent', () => {
  const storage = memoryStorage();
  storage.setItem('sg-login-auto-forwarded', 'garbage');
  setWindow(storage);
  assert.equal(recentlyAutoForwarded(1_000_000), false);
});

test('blocked site data reads as not recent and marking does not throw', () => {
  setWindow({
    getItem: () => {
      throw new Error('SecurityError');
    },
    setItem: () => {
      throw new Error('SecurityError');
    },
  });
  assert.equal(recentlyAutoForwarded(1_000_000), false);
  assert.doesNotThrow(() => markAutoForwarded(1_000_000));
});

if (failures > 0) process.exit(1);

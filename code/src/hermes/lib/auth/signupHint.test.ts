/**
 * Tests for the sign-up hint the login page passes to the identity provider
 * Run with: npx tsx lib/auth/signupHint.test.ts
 */

import assert from 'node:assert';
import { signupRequested, withSignupHint } from './signupHint';

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

const params = (query: string) => new URLSearchParams(query);

test('signup=1 on the login page asks for the sign-up screen', () => {
  assert.equal(signupRequested(params('signup=1')), true);
});

test('signup=1 in the return page asks for the sign-up screen', () => {
  assert.equal(signupRequested(params(`next=${encodeURIComponent('/?start=iaad&signup=1')}`)), true);
});

test('a plain login does not', () => {
  assert.equal(signupRequested(params('')), false);
  assert.equal(signupRequested(params(`next=${encodeURIComponent('/runs/')}`)), false);
  assert.equal(signupRequested(params(`next=${encodeURIComponent('/?start=iaad')}`)), false);
});

test('only the value 1 counts', () => {
  assert.equal(signupRequested(params('signup=0')), false);
  assert.equal(signupRequested(params(`next=${encodeURIComponent('/?signup=yes')}`)), false);
});

test('the hint follows the return path on the start URL', () => {
  assert.equal(
    withSignupHint('/api/v1/oauth2/oidc/start?rd=%2F'),
    '/api/v1/oauth2/oidc/start?rd=%2F&screen_hint=signup',
  );
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed`);
  process.exit(1);
}

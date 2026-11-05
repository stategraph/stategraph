/**
 * Tests for the message the login page shows after a failed OAuth sign-in
 * Run with: npx tsx lib/auth/loginError.test.ts
 */

import assert from 'node:assert';
import { loginErrorMessage } from './loginError';

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

test('an identity provider error shows its reason', () => {
  assert.equal(
    loginErrorMessage('idp', 'User is blocked'),
    'Sign-in failed. Your identity provider returned: User is blocked',
  );
});

test('an identity provider error without a reason still shows', () => {
  assert.equal(
    loginErrorMessage('idp', null),
    'Sign-in failed. Your identity provider returned an error.',
  );
});

test('an expired sign-in asks for a retry', () => {
  assert.equal(loginErrorMessage('expired', null), 'Sign-in expired. Try again.');
});

test('a refused account is told so', () => {
  assert.equal(loginErrorMessage('denied', null), 'This account is not allowed to sign in.');
});

test('no error or an unknown one shows nothing', () => {
  assert.equal(loginErrorMessage(null, null), null);
  assert.equal(loginErrorMessage('other', 'text'), null);
});

if (failures > 0) process.exit(1);

/**
 * Tests for carrying the website visitor id through the login page
 * Run with: npx tsx lib/auth/websiteVisitor.test.ts
 */

import assert from 'node:assert';
import { withWebsiteVisitor } from './websiteVisitor';

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

test('ph_did on the login page goes into the return path', () => {
  assert.equal(withWebsiteVisitor('/', params('ph_did=0199abcd-1234')), '/?ph_did=0199abcd-1234');
});

test('the return path keeps its own query and hash', () => {
  assert.equal(
    withWebsiteVisitor('/invite?token=t#top', params('ph_did=0199abcd-1234')),
    '/invite?token=t&ph_did=0199abcd-1234#top'
  );
});

test('an id already in the return path wins', () => {
  const next = '/?signup=1&ph_did=from-start-link';
  assert.equal(withWebsiteVisitor(next, params('ph_did=from-login-link')), next);
});

test('no ph_did leaves the return path unchanged', () => {
  assert.equal(withWebsiteVisitor('/states?x=1', params('prompt=1')), '/states?x=1');
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed`);
  process.exit(1);
}

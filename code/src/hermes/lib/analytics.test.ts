/**
 * Tests for the analytics URL scrubber and the self-hosted off switch.
 * Run with: npx tsx lib/analytics.test.ts
 */

import type { CaptureResult } from 'posthog-js';
import { scrubUrls, startAnalytics, track } from './analytics';

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean | Promise<boolean>;
}

function event(
  properties: Record<string, unknown>,
  setOnce?: Record<string, unknown>
): CaptureResult {
  return { uuid: 'u-1', event: '$pageview', properties, $set_once: setOnce };
}

const tests: TestCase[] = [
  {
    name: 'drops the session id from the current URL',
    fn: () =>
      scrubUrls(event({ $current_url: 'https://app.example/?session=eyJhbGc&tenant=t-1' }))!
        .properties.$current_url === 'https://app.example/',
  },
  {
    name: 'drops the query and fragment from the referrer',
    fn: () =>
      scrubUrls(event({ $referrer: 'https://github.com/login/oauth?code=abc#top' }))!
        .properties.$referrer === 'https://github.com/login/oauth',
  },
  {
    name: 'scrubs set-once person properties',
    fn: () =>
      scrubUrls(event({}, { $initial_current_url: 'https://app.example/invite/?token=secret' }))!
        .$set_once!.$initial_current_url === 'https://app.example/invite/',
  },
  {
    name: 'keeps paths, numbers and non-URL strings',
    fn: () => {
      const props = scrubUrls(
        event({ $pathname: '/query/', count: 3, note: 'see ?session=x' })
      )!.properties;
      return props.$pathname === '/query/' && props.count === 3 && props.note === 'see ?session=x';
    },
  },
  {
    name: 'passes a dropped event through',
    fn: () => scrubUrls(null) === null,
  },
  {
    name: 'outside COMMUNISM mode, events are dropped and a later start is ignored',
    fn: async () => {
      track('queued_before_decision');
      await startAnalytics(undefined);
      track('after_off');
      await startAnalytics('COMMUNISM');
      return true;
    },
  },
];

(async () => {
  for (const test of tests) {
    try {
      if (await test.fn()) {
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
  }

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
})();

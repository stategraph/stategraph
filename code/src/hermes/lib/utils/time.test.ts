/**
 * Tests for time utilities
 * Run with: npx tsx lib/utils/time.test.ts
 */

import { formatRelativeTime, formatAbsoluteTime, formatDuration } from './time';

console.log('🧪 Testing Time Utilities\n');
console.log('='.repeat(60));

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: 'formatRelativeTime - Just now (< 1 minute)',
    fn: () => {
      const now = new Date();
      const thirtySecondsAgo = new Date(now.getTime() - 30 * 1000);
      const result = formatRelativeTime(thirtySecondsAgo.toISOString());
      return result === 'Just now';
    },
  },
  {
    name: 'formatRelativeTime - Minutes ago',
    fn: () => {
      const now = new Date();
      const fiveMinutesAgo = new Date(now.getTime() - 5 * 60 * 1000);
      const result = formatRelativeTime(fiveMinutesAgo.toISOString());
      return result === '5 minutes ago';
    },
  },
  {
    name: 'formatRelativeTime - 1 minute ago (singular)',
    fn: () => {
      const now = new Date();
      const oneMinuteAgo = new Date(now.getTime() - 60 * 1000);
      const result = formatRelativeTime(oneMinuteAgo.toISOString());
      return result === '1 minute ago';
    },
  },
  {
    name: 'formatRelativeTime - Hours ago',
    fn: () => {
      const now = new Date();
      const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
      const result = formatRelativeTime(twoHoursAgo.toISOString());
      return result === '2 hours ago';
    },
  },
  {
    name: 'formatRelativeTime - 1 hour ago (singular)',
    fn: () => {
      const now = new Date();
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      const result = formatRelativeTime(oneHourAgo.toISOString());
      return result === '1 hour ago';
    },
  },
  {
    name: 'formatRelativeTime - Days ago',
    fn: () => {
      const now = new Date();
      const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);
      const result = formatRelativeTime(threeDaysAgo.toISOString());
      return result === '3 days ago';
    },
  },
  {
    name: 'formatRelativeTime - Months ago',
    fn: () => {
      const now = new Date();
      const twoMonthsAgo = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
      const result = formatRelativeTime(twoMonthsAgo.toISOString());
      return result === '2 months ago';
    },
  },
  {
    name: 'formatRelativeTime - Years ago',
    fn: () => {
      const now = new Date();
      const twoYearsAgo = new Date(now.getTime() - 730 * 24 * 60 * 60 * 1000);
      const result = formatRelativeTime(twoYearsAgo.toISOString());
      return result === '2 years ago';
    },
  },
  {
    name: 'formatRelativeTime - Invalid date',
    fn: () => {
      const result = formatRelativeTime('invalid-date');
      return result === 'Unknown time';
    },
  },
  {
    name: 'formatRelativeTime - Clock skew (small future)',
    fn: () => {
      const now = new Date();
      const fiveMinutesInFuture = new Date(now.getTime() + 5 * 60 * 1000);
      const result = formatRelativeTime(fiveMinutesInFuture.toISOString());
      // Should treat as "5 minutes ago" due to clock skew handling
      return result === '5 minutes ago';
    },
  },
  {
    name: 'formatRelativeTime - Large clock skew',
    fn: () => {
      const now = new Date();
      const twoHoursInFuture = new Date(now.getTime() + 2 * 60 * 60 * 1000);
      const result = formatRelativeTime(twoHoursInFuture.toISOString());
      return result === 'Clock sync issue';
    },
  },
  {
    name: 'formatAbsoluteTime - Valid timestamp',
    fn: () => {
      const timestamp = '2025-12-15T14:30:00.000Z';
      const result = formatAbsoluteTime(timestamp);
      // Result includes date and time
      return result.includes('Dec') && result.includes('2025') && result.includes('at');
    },
  },
  {
    name: 'formatDuration - Seconds only',
    fn: () => {
      const start = new Date('2025-12-16T10:00:00.000Z');
      const end = new Date('2025-12-16T10:00:30.000Z');
      const result = formatDuration(start.toISOString(), end.toISOString());
      return result === '30s';
    },
  },
  {
    name: 'formatDuration - Minutes only',
    fn: () => {
      const start = new Date('2025-12-16T10:00:00.000Z');
      const end = new Date('2025-12-16T10:05:00.000Z');
      const result = formatDuration(start.toISOString(), end.toISOString());
      return result === '5m';
    },
  },
  {
    name: 'formatDuration - Minutes and seconds',
    fn: () => {
      const start = new Date('2025-12-16T10:00:00.000Z');
      const end = new Date('2025-12-16T10:02:30.000Z');
      const result = formatDuration(start.toISOString(), end.toISOString());
      return result === '2m 30s';
    },
  },
  {
    name: 'formatDuration - Hours only',
    fn: () => {
      const start = new Date('2025-12-16T10:00:00.000Z');
      const end = new Date('2025-12-16T13:00:00.000Z');
      const result = formatDuration(start.toISOString(), end.toISOString());
      return result === '3h';
    },
  },
  {
    name: 'formatDuration - Hours and minutes',
    fn: () => {
      const start = new Date('2025-12-16T10:00:00.000Z');
      const end = new Date('2025-12-16T12:15:00.000Z');
      const result = formatDuration(start.toISOString(), end.toISOString());
      return result === '2h 15m';
    },
  },
  {
    name: 'formatDuration - No end time (uses current time)',
    fn: () => {
      const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
      const result = formatDuration(oneMinuteAgo.toISOString());
      // Should be approximately "1m" or "1m Xs"
      return result.startsWith('1m') || result.startsWith('59s');
    },
  },
];

// Run all tests
tests.forEach((test) => {
  try {
    if (test.fn()) {
      console.log(`✅ PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`❌ FAIL: ${test.name}`);
      failed++;
    }
  } catch (error) {
    console.log(`❌ FAIL: ${test.name} (threw error: ${error})`);
    failed++;
  }
});

console.log('\n' + '='.repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${tests.length} tests`);

if (failed === 0) {
  console.log('\n🎉 All time utility tests passed!');
  console.log('\n✅ Features verified:');
  console.log('   • Relative time formatting (just now, minutes, hours, days, months, years)');
  console.log('   • Singular/plural handling');
  console.log('   • Invalid date handling');
  console.log('   • Clock skew handling (future timestamps)');
  console.log('   • Absolute time formatting');
  console.log('   • Duration formatting (seconds, minutes, hours)');
  console.log('   • Duration with optional end time');
}

process.exit(failed > 0 ? 1 : 0);

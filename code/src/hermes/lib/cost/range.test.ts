/**
 * Tests for cost-range utilities.
 * Run with: npx tsx lib/cost/range.test.ts
 */

import {
  autoRangeForSpan,
  COST_RANGES,
  CostRange,
  DEFAULT_COST_RANGE,
  isCostRange,
  rangeToFromTo,
  spanDaysSince,
} from "./range";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const now = new Date("2026-05-22T12:00:00Z");
const DAY_MS = 24 * 60 * 60 * 1000;

function expectedFrom(daysAgo: number): string {
  return new Date(now.getTime() - daysAgo * DAY_MS).toISOString();
}

const tests: TestCase[] = [
  {
    name: "7d -> from is 7 days before now",
    fn: () => rangeToFromTo("7d", now).from === expectedFrom(7),
  },
  {
    name: "1m -> from is 30 days before now",
    fn: () => rangeToFromTo("1m", now).from === expectedFrom(30),
  },
  {
    name: "1q -> from is 90 days before now",
    fn: () => rangeToFromTo("1q", now).from === expectedFrom(90),
  },
  {
    name: "6m -> from is 180 days before now",
    fn: () => rangeToFromTo("6m", now).from === expectedFrom(180),
  },
  {
    name: "1y -> from is 365 days before now",
    fn: () => rangeToFromTo("1y", now).from === expectedFrom(365),
  },
  {
    name: "all -> from is a fixed sentinel predating any plausible snapshot",
    fn: () => {
      const { from } = rangeToFromTo("all", now);
      // Stable per run — same value regardless of `now`.
      if (rangeToFromTo("all", new Date("2030-01-01T00:00:00Z")).from !== from) {
        return false;
      }
      // Far enough back to escape the backend's default 30-day window.
      return new Date(from).getTime() < now.getTime() - 60 * DAY_MS;
    },
  },
  {
    name: "to is always now (ISO)",
    fn: () => rangeToFromTo("1m", now).to === now.toISOString(),
  },
  {
    name: "COST_RANGES order matches user spec (7d, 1m, 1q, 6m, 1y, all)",
    fn: () => {
      const ids = COST_RANGES.map((r) => r.id).join(",");
      return ids === "7d,1m,1q,6m,1y,all";
    },
  },
  {
    name: "DEFAULT_COST_RANGE is 1m",
    fn: () => DEFAULT_COST_RANGE === "1m",
  },
  {
    name: "isCostRange accepts valid id",
    fn: () => isCostRange("1q") === true,
  },
  {
    name: "isCostRange rejects garbage",
    fn: () => isCostRange("nope") === false,
  },
  {
    name: "isCostRange handles null",
    fn: () => isCostRange(null) === false,
  },
  {
    name: "every COST_RANGES entry has a valid id",
    fn: () => COST_RANGES.every((r) => isCostRange(r.id as CostRange)),
  },

  // autoRangeForSpan: smallest preset whose window contains the span. The
  // threshold for each bucket is that range's own length, tested on both
  // sides of every boundary.
  {
    name: "autoRangeForSpan: 0 days -> 7d",
    fn: () => autoRangeForSpan(0) === "7d",
  },
  {
    name: "autoRangeForSpan: just under a week -> 7d",
    fn: () => autoRangeForSpan(6.99) === "7d",
  },
  {
    name: "autoRangeForSpan: exactly 7 days -> 1m (a week of data needs a wider window)",
    fn: () => autoRangeForSpan(7) === "1m",
  },
  {
    name: "autoRangeForSpan: just under a month -> 1m",
    fn: () => autoRangeForSpan(29.99) === "1m",
  },
  {
    name: "autoRangeForSpan: exactly 30 days -> 1q",
    fn: () => autoRangeForSpan(30) === "1q",
  },
  {
    name: "autoRangeForSpan: just under a quarter -> 1q",
    fn: () => autoRangeForSpan(89.99) === "1q",
  },
  {
    name: "autoRangeForSpan: exactly 90 days -> 6m",
    fn: () => autoRangeForSpan(90) === "6m",
  },
  {
    name: "autoRangeForSpan: just under 6 months -> 6m",
    fn: () => autoRangeForSpan(179.99) === "6m",
  },
  {
    name: "autoRangeForSpan: exactly 180 days -> 1y",
    fn: () => autoRangeForSpan(180) === "1y",
  },
  {
    name: "autoRangeForSpan: just under a year -> 1y",
    fn: () => autoRangeForSpan(364.99) === "1y",
  },
  {
    name: "autoRangeForSpan: exactly 365 days -> all",
    fn: () => autoRangeForSpan(365) === "all",
  },
  {
    name: "autoRangeForSpan: well over a year -> all",
    fn: () => autoRangeForSpan(400) === "all",
  },

  // spanDaysSince: day span from an ISO start to `now`, floored at 0.
  {
    name: "spanDaysSince: 7 days before now -> 7",
    fn: () => spanDaysSince(expectedFrom(7), now) === 7,
  },
  {
    name: "spanDaysSince: fractional days are preserved",
    fn: () =>
      spanDaysSince(new Date(now.getTime() - 1.5 * DAY_MS).toISOString(), now) === 1.5,
  },
  {
    name: "spanDaysSince: same instant -> 0",
    fn: () => spanDaysSince(now.toISOString(), now) === 0,
  },
  {
    name: "spanDaysSince: a start after now is floored to 0",
    fn: () =>
      spanDaysSince(new Date(now.getTime() + 5 * DAY_MS).toISOString(), now) === 0,
  },
  {
    name: "spanDaysSince: unparseable timestamp -> 0",
    fn: () => spanDaysSince("not-a-date", now) === 0,
  },
  {
    name: "autoRangeForSpan(spanDaysSince(...)): a 4-day-old series picks 7d",
    fn: () =>
      autoRangeForSpan(
        spanDaysSince(new Date(now.getTime() - 4 * DAY_MS).toISOString(), now)
      ) === "7d",
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
  } catch (error) {
    console.log(`FAIL: ${test.name} (threw: ${error})`);
    failed++;
  }
});

console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
process.exit(failed > 0 ? 1 : 0);

/**
 * Tests for the actuals (FOCUS billing) helpers: window spans, the monthly
 * run-rate normalisation, and its "too short to compare" gate.
 *
 * Run with: npx tsx lib/cost/actuals.test.ts
 */

import {
  DAYS_PER_MONTH,
  MIN_COMPARE_WINDOW_DAYS,
  formatWindow,
  monthlyRunRate,
  windowDays,
} from "./actuals";

let failures = 0;

function check(name: string, condition: boolean): void {
  if (condition) {
    console.log(`  ✓ ${name}`);
  } else {
    failures += 1;
    console.error(`  ✗ ${name}`);
  }
}

function approx(a: number | null, b: number, epsilon = 1e-9): boolean {
  return a !== null && Math.abs(a - b) < epsilon;
}

console.log("windowDays");
check(
  "full span in days",
  approx(windowDays("2026-05-12T00:00:00Z", "2026-06-11T00:00:00Z"), 30)
);
check(
  "fractional days survive",
  approx(windowDays("2026-06-01T00:00:00Z", "2026-06-01T12:00:00Z"), 0.5)
);
check("zero span is 0, not null", approx(windowDays("2026-06-01T00:00:00Z", "2026-06-01T00:00:00Z"), 0));
check("missing start is null", windowDays(undefined, "2026-06-11T00:00:00Z") === null);
check("missing end is null", windowDays("2026-06-11T00:00:00Z", undefined) === null);
check("unparseable bound is null", windowDays("not-a-date", "2026-06-11T00:00:00Z") === null);
check(
  "inverted window is null",
  windowDays("2026-06-11T00:00:00Z", "2026-05-12T00:00:00Z") === null
);

console.log("monthlyRunRate");
check(
  "30 billed over 30 days ≈ one month's worth",
  approx(monthlyRunRate("30.00", "2026-05-12T00:00:00Z", "2026-06-11T00:00:00Z"), DAYS_PER_MONTH)
);
check(
  "decimal-string cost parses",
  approx(
    monthlyRunRate("60.500000", "2026-04-12T00:00:00Z", "2026-06-11T00:00:00Z"),
    (60.5 / 60) * DAYS_PER_MONTH
  )
);
check(
  `window below ${MIN_COMPARE_WINDOW_DAYS}d is not comparable`,
  monthlyRunRate("10.00", "2026-06-01T00:00:00Z", "2026-06-10T00:00:00Z") === null
);
check(
  "window exactly at the gate is comparable",
  monthlyRunRate("28.00", "2026-05-14T00:00:00Z", "2026-06-11T00:00:00Z") !== null
);
check("missing window is null", monthlyRunRate("10.00", undefined, undefined) === null);
check(
  "unparseable cost is null",
  monthlyRunRate("abc", "2026-05-12T00:00:00Z", "2026-06-11T00:00:00Z") === null
);

console.log("formatWindow");
check(
  "labels both bounds",
  (() => {
    const label = formatWindow("2026-05-12T00:00:00Z", "2026-06-11T00:00:00Z");
    return label !== null && label.includes("–");
  })()
);
check("missing bound yields null", formatWindow(undefined, "2026-06-11T00:00:00Z") === null);
check("unparseable bound yields null", formatWindow("nope", "2026-06-11T00:00:00Z") === null);

if (failures > 0) {
  console.error(`\n${failures} failure(s)`);
  process.exit(1);
}
console.log("\nAll actuals tests passed");
process.exit(0);

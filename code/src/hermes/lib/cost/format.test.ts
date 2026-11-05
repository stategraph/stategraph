/**
 * Tests for cost-format utilities.
 * Run with: npx tsx lib/cost/format.test.ts
 */

import type { TenantCosts } from "@/lib/api/client";

import { formatCurrency, parseCost, tenantCurrencyFor } from "./format";

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  // parseCost
  {
    name: "parseCost: null -> null",
    fn: () => parseCost(null) === null,
  },
  {
    name: "parseCost: undefined -> null",
    fn: () => parseCost(undefined) === null,
  },
  {
    name: "parseCost: numeric string is parsed",
    fn: () => parseCost("7.592000") === 7.592,
  },
  {
    name: "parseCost: plain number passes through",
    fn: () => parseCost(42.5) === 42.5,
  },
  {
    name: "parseCost: unparseable string -> null (not 0)",
    fn: () => parseCost("not-a-number") === null,
  },
  {
    // Number("") === 0, and the current parseCost treats "isFinite" as "valid",
    // so the empty-string lands on 0. Documenting the existing behaviour here so
    // a change to it shows up as a test failure rather than a silent UI regression.
    name: "parseCost: empty string -> 0 (Number('') === 0; documents current behaviour)",
    fn: () => parseCost("") === 0,
  },
  // formatCurrency
  {
    name: "formatCurrency: USD renders a $-prefixed amount",
    fn: () => {
      const out = formatCurrency(7.59, "USD");
      // Different locales format slightly differently; just check that the
      // amount and currency symbol both appear.
      return out.includes("7.59") && (out.includes("$") || out.includes("USD"));
    },
  },
  {
    name: "formatCurrency: EUR renders something currency-ish",
    fn: () => {
      const out = formatCurrency(10, "EUR");
      return out.includes("10") && (out.includes("€") || out.includes("EUR"));
    },
  },
  {
    name: "formatCurrency: empty currency -> bare two-decimal number",
    fn: () => formatCurrency(3.4, "") === "3.40",
  },
  {
    name: "formatCurrency: unknown ISO code falls back to '<value> <code>'",
    fn: () => {
      const out = formatCurrency(2.5, "ZZZNOTACURRENCY");
      return out === "2.50 ZZZNOTACURRENCY";
    },
  },
  // tenantCurrencyFor
  {
    name: "tenantCurrencyFor: null rollup -> USD, not mixed",
    fn: () => {
      const out = tenantCurrencyFor(null);
      return out.currency === "USD" && out.isMixedCurrency === false;
    },
  },
  {
    name: "tenantCurrencyFor: empty (no priced data) rollup -> USD, not mixed",
    fn: () => {
      const rollup = {
        states: [],
        priced_count: 0,
        resource_count: 0,
        supported_count: 0,
        coverage_percent: 0,
        by_provider: [],
        by_type: [],
        by_tag: [],
      } as unknown as TenantCosts;
      const out = tenantCurrencyFor(rollup);
      return out.currency === "USD" && out.isMixedCurrency === false;
    },
  },
  {
    name: "tenantCurrencyFor: single-currency rollup passes the currency through",
    fn: () => {
      const rollup = {
        states: [],
        priced_count: 3,
        resource_count: 5,
        supported_count: 5,
        coverage_percent: 60,
        currency: "EUR",
        monthly_cost: "12.00",
        by_provider: [],
        by_type: [],
        by_tag: [],
      } as unknown as TenantCosts;
      const out = tenantCurrencyFor(rollup);
      return out.currency === "EUR" && out.isMixedCurrency === false;
    },
  },
  {
    name: "tenantCurrencyFor: currency absent + priced_count>0 -> mixed",
    fn: () => {
      const rollup = {
        states: [],
        priced_count: 4,
        resource_count: 4,
        supported_count: 4,
        coverage_percent: 100,
        by_provider: [],
        by_type: [],
        by_tag: [],
      } as unknown as TenantCosts;
      const out = tenantCurrencyFor(rollup);
      return out.currency === "" && out.isMixedCurrency === true;
    },
  },
  {
    name: "tenantCurrencyFor: currency absent + non-empty monthly_cost -> mixed",
    fn: () => {
      const rollup = {
        states: [],
        priced_count: 0,
        resource_count: 0,
        supported_count: 0,
        coverage_percent: 0,
        monthly_cost: "9.99",
        by_provider: [],
        by_type: [],
        by_tag: [],
      } as unknown as TenantCosts;
      const out = tenantCurrencyFor(rollup);
      return out.currency === "" && out.isMixedCurrency === true;
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
  } catch (error) {
    console.log(`FAIL: ${test.name} (threw: ${error})`);
    failed++;
  }
});

console.log(`\n${passed} passed, ${failed} failed (${tests.length} total)`);
process.exit(failed > 0 ? 1 : 0);

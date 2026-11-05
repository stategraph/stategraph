/**
 * Tests for MQL error description helpers.
 * Run with: npx tsx 'app/(console)/query/mqlErrors.test.ts'
 */

import { describeMqlError, describePaginationError } from "./mqlErrors";

console.log("🧪 Testing MQL Error Helpers\n");
console.log("=".repeat(60));

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

/** Build an error shaped like the one thrown by `fetchAPICore`. */
function apiError(status: number, body: unknown): unknown {
  return Object.assign(new Error("API error"), { status, body });
}

const tests: TestCase[] = [
  {
    name: "UNKNOWN_COLUMN_ERR — friendly message, id and detail",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "UNKNOWN_COLUMN_ERR", data: "foo" }));
      return (
        r.message === 'Unknown column "foo". Check the name against the Schema panel.' &&
        r.errorId === "UNKNOWN_COLUMN_ERR" &&
        r.detail === "foo"
      );
    },
  },
  {
    name: "AMBIGUOUS_COLUMN_ERR — interpolates a qualified-name example",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "AMBIGUOUS_COLUMN_ERR", data: "id" }));
      return r.message.includes('"id" is ambiguous') && r.message.includes("instances.id");
    },
  },
  {
    name: "TABLE_ACCESS_ERR — points at the Schema panel",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "TABLE_ACCESS_ERR", data: "secrets" }));
      return r.message.includes('"secrets"') && r.message.includes("Schema panel");
    },
  },
  {
    name: "FUNC_ACCESS_ERR — names the disallowed function",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "FUNC_ACCESS_ERR", data: "pg_sleep" }));
      return r.message.includes('"pg_sleep"') && r.message.includes("isn't allowed");
    },
  },
  {
    name: "CAST_ERR — names the type",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "CAST_ERR", data: "regclass" }));
      return r.message.includes('"regclass"') && r.message.includes("cast");
    },
  },
  {
    name: "INVALID_IDENTIFIER_ERR — explains the charset",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "INVALID_IDENTIFIER_ERR", data: "1bad" }));
      return r.message.includes('"1bad"') && r.message.includes("letters, digits");
    },
  },
  {
    name: "TYPE_MISMATCH_ERR — generic message, raw detail preserved",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "TYPE_MISMATCH_ERR", data: "raw type info" }));
      return r.message.includes("wrong type") && r.detail === "raw type info";
    },
  },
  {
    name: "QUERY_ERR — syntax hint, raw parser detail preserved",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "QUERY_ERR", data: "syntax error at line 1" }));
      return r.message.includes("syntax") && r.detail === "syntax error at line 1";
    },
  },
  {
    name: "APPLY_PAGE_ERR — suggests re-running",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "APPLY_PAGE_ERR", data: "bad page" }));
      return r.message.includes("Re-run the query");
    },
  },
  {
    name: "TIMEOUT_ERR — actionable, no detail (no data field)",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "TIMEOUT_ERR" }));
      return (
        r.message.includes("too long") &&
        r.message.includes("WHERE") &&
        r.errorId === "TIMEOUT_ERR" &&
        r.detail === undefined
      );
    },
  },
  {
    name: "Unknown error id — generic fallback, id still surfaced",
    fn: () => {
      const r = describeMqlError(apiError(400, { id: "SOMETHING_NEW", data: "x" }));
      return r.message === "The query couldn't be run. See details below." && r.errorId === "SOMETHING_NEW";
    },
  },
  {
    name: "HTTP 500 with no body — server error message, HTTP status detail",
    fn: () => {
      const r = describeMqlError(apiError(500, null));
      return r.message.includes("unexpected error") && r.detail === "HTTP 500";
    },
  },
  {
    name: "Network failure (no status, no body) — connectivity message",
    fn: () => {
      const r = describeMqlError(new TypeError("Failed to fetch"));
      return r.message.includes("Couldn't reach the server") && r.detail === "Failed to fetch";
    },
  },
  {
    name: "describePaginationError — null header returns null",
    fn: () => describePaginationError(null) === null,
  },
  {
    name: "describePaginationError — ORDER_BY_MISSING",
    fn: () => {
      const r = describePaginationError("ORDER_BY_MISSING");
      return r !== null && r.includes("ORDER BY") && r.includes("truncated");
    },
  },
  {
    name: "describePaginationError — COLUMN_NOT_IN_ROW extracts the column",
    fn: () => {
      const r = describePaginationError("COLUMN_NOT_IN_ROW created_at");
      return r !== null && r.includes('"created_at"') && r.includes("SELECT list");
    },
  },
  {
    name: "describePaginationError — ORDER_BY_COL_NOT_IDENTIFIER",
    fn: () => {
      const r = describePaginationError("ORDER_BY_COL_NOT_IDENTIFIER count(*)");
      return r !== null && r.includes("plain columns");
    },
  },
  {
    name: "describePaginationError — unknown code falls back gracefully",
    fn: () => {
      const r = describePaginationError("SOMETHING_ELSE");
      return r !== null && r.includes("can't be paginated");
    },
  },
];

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

console.log("\n" + "=".repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed out of ${tests.length} tests`);

if (failed === 0) {
  console.log("\n🎉 All MQL error helper tests passed!");
}

process.exit(failed > 0 ? 1 : 0);

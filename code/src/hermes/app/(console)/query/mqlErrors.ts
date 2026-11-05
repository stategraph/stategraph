/**
 * Maps raw MQL endpoint errors into clear, actionable messages for the Query page.
 *
 * The backend reports problems two ways:
 *  - HTTP 400 with a `Bad_request_err` body `{ id, data? }`.
 *  - HTTP 200 with an `mql-pagination-error` response header when results are
 *    truncated but cannot be paginated.
 * It can also return HTTP 500 (no usable body), and the request can fail before
 * any response (network error). This module turns all of those into friendly
 * text, keeping the raw id/detail available for a "Show details" disclosure.
 */

import type { components } from "@/lib/api/types-generated";

type BadRequestErr = components["schemas"]["bad-request-err"];

export interface MqlErrorInfo {
  /** Human-readable, actionable message shown prominently. */
  message: string;
  /** Raw backend error id (e.g. UNKNOWN_COLUMN_ERR); shown under "Show details". */
  errorId?: string;
  /** Raw backend detail (parser/PostgreSQL text or HTTP status); shown under "Show details". */
  detail?: string;
}

/** Narrow an arbitrary thrown-error `body` to a `Bad_request_err`. */
function asBadRequestErr(body: unknown): BadRequestErr | null {
  if (
    body !== null &&
    typeof body === "object" &&
    "id" in body &&
    typeof (body as { id: unknown }).id === "string"
  ) {
    return body as BadRequestErr;
  }
  return null;
}

/** Wrap a name in quotes, with a fallback when the backend omitted it. */
function quote(value: string | undefined): string {
  return value ? `"${value}"` : "the value";
}

/** Build the message for a structured HTTP 400 `Bad_request_err`. */
function describeBadRequest(body: BadRequestErr): MqlErrorInfo {
  const { id, data } = body;

  let message: string;
  switch (id) {
    case "UNKNOWN_COLUMN_ERR":
      message = `Unknown column ${quote(data)}. Check the name against the Schema panel.`;
      break;
    case "AMBIGUOUS_COLUMN_ERR":
      message = data
        ? `Column "${data}" is ambiguous — qualify it with a table name (e.g. instances.${data}).`
        : "A column in the query is ambiguous — qualify it with a table name.";
      break;
    case "TABLE_ACCESS_ERR":
      message = `The table ${quote(data)} can't be queried. Open the Schema panel to see queryable tables.`;
      break;
    case "FUNC_ACCESS_ERR":
      message = `The function ${quote(data)} isn't allowed in SQL queries.`;
      break;
    case "CAST_ERR":
      message = `Can't cast to type ${quote(data)}. Supported types include text, integer, bigint, boolean, jsonb, timestamptz and uuid.`;
      break;
    case "INVALID_IDENTIFIER_ERR":
      message = `${quote(data)} is not a valid identifier — identifiers may use only letters, digits and underscores.`;
      break;
    case "TYPE_MISMATCH_ERR":
      message = "A value in the query has the wrong type for this operation. See details below.";
      break;
    case "QUERY_ERR":
      message = "The query couldn't be run — check the query syntax. See details below.";
      break;
    case "APPLY_PAGE_ERR":
      message = "Couldn't apply pagination to this query. Re-run the query from the start.";
      break;
    case "TIMEOUT_ERR":
      message =
        "The query took too long and was stopped. Add a WHERE filter or a smaller LIMIT, then try again.";
      break;
    default:
      message = "The query couldn't be run. See details below.";
      break;
  }

  return { message, errorId: id, detail: data || undefined };
}

/**
 * Describe an error thrown while executing an MQL query. Accepts the error
 * thrown by the API client, which carries `status` and `body` (see
 * `fetchAPICore` in `lib/api/client.ts`), as well as plain network errors.
 */
export function describeMqlError(err: unknown): MqlErrorInfo {
  const e = err as { status?: unknown; body?: unknown; message?: unknown } | null;
  const status = typeof e?.status === "number" ? e.status : undefined;
  const body = asBadRequestErr(e?.body);

  // A structured Bad_request_err from the MQL endpoint (HTTP 400).
  if (body) {
    return describeBadRequest(body);
  }

  // No HTTP status and no body: fetch failed before a response was received.
  if (status === undefined) {
    return {
      message: "Couldn't reach the server. Check your connection and try again.",
      detail: typeof e?.message === "string" ? e.message : undefined,
    };
  }

  // An HTTP error with no usable body — typically a 500 (infrastructure failure).
  return {
    message:
      "The server hit an unexpected error running this query. Try again; if it keeps happening, contact support.",
    detail: `HTTP ${status}`,
  };
}

/**
 * Describe the `mql-pagination-error` response header (returned with HTTP 200).
 * Returns `null` when the header is absent — i.e. pagination is fine.
 */
export function describePaginationError(header: string | null): string | null {
  if (!header) return null;

  const sep = header.indexOf(" ");
  const code = sep === -1 ? header : header.slice(0, sep);
  const arg = sep === -1 ? "" : header.slice(sep + 1);

  switch (code) {
    case "ORDER_BY_MISSING":
      return "Results may be truncated. Add an ORDER BY clause to page through all rows.";
    case "COLUMN_NOT_IN_ROW":
      return `Results may be truncated. The ORDER BY column "${arg}" isn't in the SELECT list — add it to enable pagination.`;
    case "ORDER_BY_COL_NOT_IDENTIFIER":
      return "Results may be truncated. ORDER BY must use plain columns, not expressions, to enable pagination.";
    default:
      return "Results may be truncated and can't be paginated.";
  }
}

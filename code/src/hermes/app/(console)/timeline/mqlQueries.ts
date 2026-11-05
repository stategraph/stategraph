// MQL queries for the Activity Timeline page.
//
// The timeline previously fetched a window of transactions
// (`getTenantTransactions`, 50 at a time) and applied the status / text /
// resource filters CLIENT-SIDE. Any transaction beyond the loaded window was
// invisible to those filters, so searches and status tabs silently missed
// matches. These queries push the filters into the MQL engine so every filter
// runs against the full transaction set, server-side, with cursor pagination.
//
// They also fix a status bug: the old UI derived status from `completed_at`
// plus a dead `completed_by === "abort"` check, so aborted/failed transactions
// rendered as "completed". Status here comes from the real `transactions.state`
// column (open/previewing/committing/aborted/failed/failed-committed/committed).
//
// Engine notes: scoped tables are referenced by BARE NAME; uuid/jsonb cast to
// text with `::text`; user-supplied text is escaped for both the SQL literal
// and ILIKE before interpolation; ORDER BY is on plain field-selects so the
// endpoint can auto-paginate (pass the returned cursor to executeMQL).

import type { TimelineStatusFilter } from "@/lib/timeline/types";

export type {
  TimelineStatusFilter,
  TransactionRow,
  TransactionLogRow,
} from "@/lib/timeline/types";

// The endpoint hard-caps results at 1000 rows. "Load more" grows the limit up
// to this ceiling; beyond it the user narrows the filters.
export const MAX_PAGE_LIMIT = 1000;

function clampLimit(limit?: number): number {
  if (!limit || limit < 1) return 50;
  return Math.min(limit, MAX_PAGE_LIMIT);
}

/** Escape single quotes in a user string; callers supply the surrounding
 *  quotes. NOT the same contract as lib/mql/escape's sqlLiteral, which
 *  returns a complete quoted literal. */
function escapeQuotes(s: string): string {
  return s.replace(/'/g, "''");
}

/** Build a `'%term%'` ILIKE pattern literal, escaping LIKE metachars and quotes. */
function likePattern(s: string): string {
  const escaped = s.replace(/([\\%_])/g, "\\$1").replace(/'/g, "''");
  return `'%${escaped}%'`;
}

function statusCondition(status: TimelineStatusFilter): string | null {
  switch (status) {
    case "completed":
      return "transactions.state = 'committed'";
    case "aborted":
      return "transactions.state in ('aborted', 'failed', 'failed-committed')";
    case "pending":
      return "transactions.completed_at is null";
    default:
      return null;
  }
}

/**
 * Mirror of the old client-side `txMatchesSearch`: match the query against the
 * id, creator/completer, status, created/completed timestamps (raw and a
 * human-formatted form), and the tags blob.
 */
function txSearchCondition(search: string): string {
  const p = likePattern(search);
  return `(
    transactions.id::text ilike ${p}
    or transactions.created_by::text ilike ${p}
    or transactions.completed_by::text ilike ${p}
    or transactions.state ilike ${p}
    or transactions.created_at::text ilike ${p}
    or transactions.completed_at::text ilike ${p}
    or to_char(transactions.created_at, 'Mon DD, HH24:MI:SS') ilike ${p}
    or transactions.tags::text ilike ${p}
  )`;
}

/** Transactions whose logs reference the resource (matches old `logMatchesResource`). */
function resourceCondition(resource: string): string {
  return `transactions.id in (
    select transaction_logs.tx_id from transaction_logs
    where transaction_logs.data::text ilike ${likePattern(resource)}
    group by transaction_logs.tx_id
  )`;
}

/**
 * Transactions for a tenant, newest first, with the status / search / resource
 * filters applied server-side. Paginate by passing the endpoint's cursor to
 * executeMQL.
 */
export function transactionsQuery(opts: {
  tenantId: string;
  status?: TimelineStatusFilter;
  search?: string;
  resource?: string | null;
  limit?: number;
}): string {
  const where: string[] = [`transactions.tenant_id = '${escapeQuotes(opts.tenantId)}'`];
  const status = statusCondition(opts.status ?? "all");
  if (status) where.push(status);
  if (opts.search && opts.search.trim()) where.push(txSearchCondition(opts.search.trim()));
  if (opts.resource && opts.resource.trim()) where.push(resourceCondition(opts.resource.trim()));

  return `select
  transactions.id as id,
  transactions.created_at as created_at,
  transactions.completed_at as completed_at,
  transactions.created_by as created_by,
  transactions.completed_by as completed_by,
  transactions.state as state,
  transactions.tags as tags
from transactions
where ${where.join("\n  and ")}
order by transactions.created_at desc, transactions.id
limit ${clampLimit(opts.limit)}`;
}

/**
 * A single transaction by id (tenant-scoped by the endpoint). Replaces the
 * detail page's old "fetch 200 and find by id client-side" lookup, which could
 * not find transactions beyond the window.
 */
export function transactionByIdQuery(txId: string): string {
  return `select
  transactions.id as id,
  transactions.created_at as created_at,
  transactions.completed_at as completed_at,
  transactions.created_by as created_by,
  transactions.completed_by as completed_by,
  transactions.state as state,
  transactions.tags as tags
from transactions
where transactions.id = '${escapeQuotes(txId)}'
order by transactions.id
limit 1`;
}

/**
 * Logs for one transaction, oldest first, with optional search / resource
 * filters applied server-side. Paginate via the endpoint cursor.
 */
export function transactionLogsQuery(
  txId: string,
  opts?: { search?: string; resource?: string | null; limit?: number }
): string {
  const where: string[] = [`transaction_logs.tx_id = '${escapeQuotes(txId)}'`];
  if (opts?.search && opts.search.trim()) {
    const p = likePattern(opts.search.trim());
    where.push(
      `(transaction_logs.action ilike ${p} or transaction_logs.object_type ilike ${p} or transaction_logs.data::text ilike ${p})`
    );
  }
  if (opts?.resource && opts.resource.trim()) {
    where.push(`transaction_logs.data::text ilike ${likePattern(opts.resource.trim())}`);
  }

  return `select
  transaction_logs.id as id,
  transaction_logs.tx_id as tx_id,
  transaction_logs.state_id as state_id,
  transaction_logs.action as action,
  transaction_logs.object_type as object_type,
  transaction_logs.created_at as created_at,
  transaction_logs.user_id as user_id,
  transaction_logs.data as data
from transaction_logs
where ${where.join("\n  and ")}
order by transaction_logs.created_at, transaction_logs.id
limit ${clampLimit(opts?.limit)}`;
}

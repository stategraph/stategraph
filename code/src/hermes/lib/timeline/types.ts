// Shared row/types for the Activity Timeline, which now reads transactions and
// transaction logs through MQL (`app/(console)/timeline/mqlQueries.ts`) rather
// than the windowed REST endpoints. These row shapes mirror exactly the columns
// those queries select.

/** The status filter exposed by the timeline filter bar. */
export type TimelineStatusFilter = "all" | "completed" | "pending" | "aborted";

/** One transaction row, as selected by `transactionsQuery` / `transactionByIdQuery`. */
export interface TransactionRow {
  id: string;
  created_at: string;
  completed_at: string | null;
  created_by: string;
  completed_by: string | null;
  state: string;
  tags: unknown;
}

/** One transaction-log row, as selected by `transactionLogsQuery`. */
export interface TransactionLogRow {
  id: string;
  tx_id: string;
  state_id: string;
  action: string;
  object_type: string;
  created_at: string;
  user_id: string | null;
  data: unknown;
}

/**
 * Display status for a transaction, derived from the real `transactions.state`
 * column. The old UI keyed off `completed_at` plus a dead
 * `completed_by === "abort"` check, so aborted/failed transactions rendered as
 * "completed". This mirrors the server-side status filter in `mqlQueries.ts`:
 * committed -> completed, aborted/failed/failed-committed -> aborted, everything still open
 * (open/previewing/committing, i.e. no completion) -> pending.
 */
export function getTxStatus(
  tx: Pick<TransactionRow, "state" | "completed_at">
): "completed" | "pending" | "aborted" {
  if (
    tx.state === "aborted" ||
    tx.state === "failed" ||
    tx.state === "failed-committed"
  )
    return "aborted";
  if (tx.state === "committed") return "completed";
  return "pending";
}

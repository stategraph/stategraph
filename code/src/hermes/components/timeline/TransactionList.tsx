"use client";

import type { TransactionRow as TxRow } from "@/lib/timeline/types";
import { getTxStatus } from "@/lib/timeline/types";
import { formatDistanceToNow, format } from "date-fns";

interface TransactionListProps {
  transactions: TxRow[];
  selectedTxId: string | null;
  onSelectTransaction: (tx: TxRow) => void;
  isLoading?: boolean;
  hasMore?: boolean;
  onLoadMore?: () => void;
  isLoadingMore?: boolean;
}

const STATUS_STYLES: Record<"completed" | "pending" | "aborted", string> = {
  completed: "bg-[var(--sg-success)]/10 text-[var(--sg-success)]",
  pending: "bg-[var(--sg-warning)]/10 text-[var(--sg-warning)]",
  aborted: "bg-[var(--sg-error)]/10 text-[var(--sg-error)]",
};

function TransactionRow({
  transaction,
  isSelected,
  onClick,
}: {
  transaction: TxRow;
  isSelected: boolean;
  onClick: () => void;
}) {
  const createdDate = new Date(transaction.created_at);
  const status = getTxStatus(transaction);

  return (
    <button
      onClick={onClick}
      className={`
        flex flex-col gap-2 px-4 py-3 border-b border-[var(--sg-border)]
        hover:bg-[var(--sg-bg-2)] transition-colors cursor-pointer text-left w-full
        ${isSelected ? "bg-[var(--sg-accent-bg)] border-l-2 border-l-[var(--sg-accent)]" : ""}
      `}
    >
      {/* Header row: timestamp + status */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex flex-col gap-0.5 flex-1 min-w-0">
          <time
            className="text-xs font-mono text-[var(--sg-text)]"
            dateTime={transaction.created_at}
          >
            {format(createdDate, "yyyy-MM-dd HH:mm:ss")}
          </time>
          <span className="text-xs text-[var(--sg-text-dim)]">
            {formatDistanceToNow(createdDate, { addSuffix: true })}
          </span>
        </div>
        <span
          className={`text-xs px-2 py-0.5 rounded shrink-0 ${STATUS_STYLES[status]}`}
        >
          {status}
        </span>
      </div>

      {/* Metadata grid */}
      <div className="grid grid-cols-[auto,1fr] gap-x-3 gap-y-1 text-xs">
        <span className="text-[var(--sg-text-dim)]">User:</span>
        <span className="text-[var(--sg-text-muted)] truncate font-mono">
          {transaction.created_by}
        </span>

        <span className="text-[var(--sg-text-dim)]">State:</span>
        <span className="text-[var(--sg-text-muted)] truncate">
          {transaction.state}
        </span>

        <span className="text-[var(--sg-text-dim)]">TX ID:</span>
        <span className="text-[var(--sg-text-muted)] truncate font-mono">
          {transaction.id}
        </span>
      </div>
    </button>
  );
}

export function TransactionList({
  transactions,
  selectedTxId,
  onSelectTransaction,
  isLoading,
  hasMore,
  onLoadMore,
  isLoadingMore,
}: TransactionListProps) {
  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-[var(--sg-text-muted)] text-sm">
          Loading transactions...
        </div>
      </div>
    );
  }

  if (transactions.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-[var(--sg-text-muted)] text-sm">
          No transactions found
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Scrollable transaction list */}
      <div className="flex-1 overflow-y-auto">
        {transactions.map((tx) => (
          <TransactionRow
            key={tx.id}
            transaction={tx}
            isSelected={tx.id === selectedTxId}
            onClick={() => onSelectTransaction(tx)}
          />
        ))}
      </div>

      {/* Load More button */}
      {hasMore && onLoadMore && (
        <div className="border-t border-[var(--sg-border)] p-3 bg-[var(--sg-bg-0)]">
          <button
            onClick={onLoadMore}
            disabled={isLoadingMore}
            className={`
              w-full px-4 py-2 text-sm rounded
              bg-[var(--sg-bg-2)] text-[var(--sg-text)]
              hover:bg-[var(--sg-accent-bg)] hover:text-[var(--sg-accent)]
              border border-[var(--sg-border)]
              transition-colors
              disabled:opacity-50 disabled:cursor-not-allowed
            `}
          >
            {isLoadingMore ? "Loading..." : "Load More"}
          </button>
        </div>
      )}
    </div>
  );
}

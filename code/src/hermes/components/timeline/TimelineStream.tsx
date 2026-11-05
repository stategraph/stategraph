"use client";

import { useState, useEffect } from "react";
import { format } from "date-fns";
import { ChevronRight, Eye } from "lucide-react";
import { executeMQL } from "@/lib/api/client";
import { transactionLogsQuery } from "@/app/(console)/timeline/mqlQueries";
import type { TransactionRow, TransactionLogRow } from "@/lib/timeline/types";
import { getTxStatus } from "@/lib/timeline/types";

interface TimelineStreamProps {
  transactions: TransactionRow[];
  isLoading: boolean;
  hasMore: boolean;
  onLoadMore: () => void;
  isLoadingMore: boolean;
  // Debounced search + resource filter, forwarded to the per-transaction log
  // query so expanded logs are filtered server-side, in step with the list.
  searchQuery: string;
  resourceFilter: string | null;
  onInspectLog: (log: TransactionLogRow) => void;
  onSelectTransaction: (tx: TransactionRow) => void;
}

/** Extract a short resource address from log data if possible */
function extractResourceAddress(data: unknown): string | null {
  if (!data || typeof data !== "object") return null;
  const record = data as Record<string, unknown>;
  // Common patterns in Terraform state log data
  if (typeof record.address === "string") return record.address;
  if (typeof record.name === "string" && typeof record.type === "string") {
    return `${record.type}.${record.name}`;
  }
  return null;
}

/** Get tag entries from transaction tags */
function getTagEntries(tags: unknown): [string, string][] {
  if (!tags || typeof tags !== "object") return [];
  return Object.entries(tags as Record<string, unknown>)
    .filter(
      ([, v]) => typeof v === "string" || typeof v === "number" || typeof v === "boolean"
    )
    .map(([k, v]) => [k, String(v)]);
}

/** Status badge component */
function StatusBadge({ status }: { status: "completed" | "pending" | "aborted" }) {
  const styles = {
    completed: "bg-[var(--sg-success)]/10 text-[var(--sg-success)]",
    pending: "bg-[var(--sg-warning)]/10 text-[var(--sg-warning)]",
    aborted: "bg-[var(--sg-error)]/10 text-[var(--sg-error)]",
  };

  return (
    <span className={`text-xs px-2 py-0.5 rounded font-medium ${styles[status]}`}>
      {status}
    </span>
  );
}

/** Action badge for log entries */
function ActionBadge({ action }: { action: string }) {
  const isSet = action === "state_set";
  return (
    <span
      className={`text-xs px-2 py-0.5 rounded font-mono ${
        isSet
          ? "bg-[var(--sg-success)]/10 text-[var(--sg-success)]"
          : "bg-[var(--sg-error)]/10 text-[var(--sg-error)]"
      }`}
    >
      {action}
    </span>
  );
}

/** Object type badge for log entries */
function ObjectTypeBadge({ objectType }: { objectType: string }) {
  return (
    <span className="text-xs px-2 py-0.5 rounded font-mono bg-[var(--sg-accent)]/10 text-[var(--sg-accent)]">
      {objectType}
    </span>
  );
}

/** Tag pill component */
function TagPill({ label, value }: { label: string; value: string }) {
  return (
    <span className="inline-flex items-center text-xs px-2 py-0.5 rounded-full bg-[var(--sg-bg-2)] border border-[var(--sg-border)] text-[var(--sg-text-muted)] font-mono max-w-[200px] truncate">
      {label}={value}
    </span>
  );
}

/** Expanded log row */
function LogRow({
  log,
  onInspect,
}: {
  log: TransactionLogRow;
  onInspect: (log: TransactionLogRow) => void;
}) {
  const address = extractResourceAddress(log.data);
  const createdDate = new Date(log.created_at);

  return (
    <div className="flex flex-wrap lg:flex-nowrap items-center gap-2 px-4 py-2 text-xs hover:bg-[var(--sg-bg-2)] transition-colors group">
      <span className="text-[var(--sg-text-dim)] font-mono shrink-0 w-[120px]">
        {format(createdDate, "HH:mm:ss.SSS")}
      </span>
      <ActionBadge action={log.action} />
      <ObjectTypeBadge objectType={log.object_type} />
      {address && (
        <span className="font-mono text-[var(--sg-text)] truncate min-w-0">
          {address}
        </span>
      )}
      <div className="flex-1" />
      <button
        onClick={(e) => {
          e.stopPropagation();
          onInspect(log);
        }}
        className="opacity-100 lg:opacity-0 lg:group-hover:opacity-100 shrink-0 flex items-center gap-1 px-2 py-1 rounded text-[var(--sg-text-muted)] hover:text-[var(--sg-accent)] hover:bg-[var(--sg-accent-bg)] transition-all"
        title="Inspect log entry"
      >
        <Eye className="h-3 w-3" />
        <span>Inspect</span>
      </button>
    </div>
  );
}

/** Single transaction stream row with expandable logs */
function StreamRow({
  transaction,
  searchQuery,
  resourceFilter,
  onInspectLog,
  onSelect,
}: {
  transaction: TransactionRow;
  searchQuery: string;
  resourceFilter: string | null;
  onInspectLog: (log: TransactionLogRow) => void;
  onSelect: (tx: TransactionRow) => void;
}) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [logs, setLogs] = useState<TransactionLogRow[] | null>(null);
  const [isLoadingLogs, setIsLoadingLogs] = useState(false);
  const [logError, setLogError] = useState<string | null>(null);

  const status = getTxStatus(transaction);
  const tags = getTagEntries(transaction.tags);
  const displayTags = tags.slice(0, 3);
  const overflowCount = tags.length - 3;
  const createdDate = new Date(transaction.created_at);

  // Load logs while expanded, re-fetching when the search / resource filters
  // change so the log filtering runs server-side against the full log set.
  useEffect(() => {
    if (!isExpanded) return;

    let cancelled = false;

    const loadLogs = async () => {
      setIsLoadingLogs(true);
      setLogError(null);
      try {
        const result = await executeMQL(
          transactionLogsQuery(transaction.id, {
            search: searchQuery,
            resource: resourceFilter,
            limit: 100,
          })
        );
        if (!cancelled) setLogs(result.data as TransactionLogRow[]);
      } catch (err) {
        if (!cancelled) {
          setLogError(err instanceof Error ? err.message : "Failed to load logs");
        }
      } finally {
        if (!cancelled) setIsLoadingLogs(false);
      }
    };

    loadLogs();

    return () => {
      cancelled = true;
    };
  }, [isExpanded, searchQuery, resourceFilter, transaction.id]);

  const handleToggle = (e: React.SyntheticEvent) => {
    e.stopPropagation();
    setIsExpanded((prev) => !prev);
  };

  return (
    <div className="border-b border-[var(--sg-border)]">
      {/* Transaction row */}
      <button
        onClick={() => onSelect(transaction)}
        className="flex flex-wrap lg:flex-nowrap items-center gap-2 lg:gap-3 w-full px-4 py-3 text-left hover:bg-[var(--sg-bg-1)] transition-colors"
      >
        <span
          role="button"
          tabIndex={0}
          onClick={handleToggle}
          onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleToggle(e); }}
          className="shrink-0 p-0.5 rounded hover:bg-[var(--sg-bg-2)] transition-colors"
        >
          <ChevronRight
            className={`h-4 w-4 text-[var(--sg-text-dim)] transition-transform ${
              isExpanded ? "rotate-90" : ""
            }`}
          />
        </span>
        <span className="text-xs font-mono text-[var(--sg-text-dim)] shrink-0 w-[140px]">
          {format(createdDate, "MMM d, HH:mm:ss")}
        </span>
        <StatusBadge status={status} />
        <span className="text-xs text-[var(--sg-text)] truncate min-w-0 font-mono">
          {transaction.created_by}
        </span>
        <div className="flex flex-wrap items-center gap-1.5 w-full lg:w-auto lg:flex-1 min-w-0 overflow-hidden">
          {displayTags.map(([k, v]) => (
            <TagPill key={k} label={k} value={v} />
          ))}
          {overflowCount > 0 && (
            <span className="text-xs text-[var(--sg-text-dim)] shrink-0">
              +{overflowCount}
            </span>
          )}
        </div>
      </button>

      {/* Expanded log entries */}
      {isExpanded && (
        <div className="border-t border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
          <div className="ml-4 border-l-2 border-[var(--sg-accent)]/30">
            {isLoadingLogs && (
              <div className="px-4 py-3 text-xs text-[var(--sg-text-dim)]">
                Loading logs...
              </div>
            )}
            {logError && (
              <div className="px-4 py-3 text-xs text-[var(--sg-error)]">
                {logError}
              </div>
            )}
            {!isLoadingLogs && logs && logs.length === 0 && (
              <div className="px-4 py-3 text-xs text-[var(--sg-text-dim)]">
                No matching log entries
              </div>
            )}
            {logs &&
              logs.map((log) => (
                <LogRow key={log.id} log={log} onInspect={onInspectLog} />
              ))}
          </div>
        </div>
      )}
    </div>
  );
}

/** Loading skeleton */
function StreamSkeleton() {
  return (
    <div className="space-y-0">
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          className="flex flex-wrap lg:flex-nowrap items-center gap-3 px-4 py-3 border-b border-[var(--sg-border)] animate-pulse"
        >
          <div className="h-4 w-4 bg-[var(--sg-bg-2)] rounded" />
          <div className="h-4 w-[140px] bg-[var(--sg-bg-2)] rounded" />
          <div className="h-5 w-[70px] bg-[var(--sg-bg-2)] rounded" />
          <div className="h-4 w-[120px] bg-[var(--sg-bg-2)] rounded" />
          <div className="h-5 w-[100px] bg-[var(--sg-bg-2)] rounded-full" />
        </div>
      ))}
    </div>
  );
}

export function TimelineStream({
  transactions,
  isLoading,
  hasMore,
  onLoadMore,
  isLoadingMore,
  searchQuery,
  resourceFilter,
  onInspectLog,
  onSelectTransaction,
}: TimelineStreamProps) {
  if (isLoading) {
    return <StreamSkeleton />;
  }

  if (transactions.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <p className="text-sm text-[var(--sg-text-muted)]">
            No transactions match the current filters
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto">
        {transactions.map((tx) => (
          <StreamRow
            key={tx.id}
            transaction={tx}
            searchQuery={searchQuery}
            resourceFilter={resourceFilter}
            onInspectLog={onInspectLog}
            onSelect={onSelectTransaction}
          />
        ))}
      </div>

      {/* Load More */}
      {hasMore && (
        <div className="border-t border-[var(--sg-border)] p-3 bg-[var(--sg-bg-0)]">
          <button
            onClick={onLoadMore}
            disabled={isLoadingMore}
            className="w-full px-4 py-2 text-sm rounded bg-[var(--sg-bg-2)] text-[var(--sg-text)] hover:bg-[var(--sg-accent-bg)] hover:text-[var(--sg-accent)] border border-[var(--sg-border)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoadingMore ? "Loading..." : "Load More"}
          </button>
        </div>
      )}
    </div>
  );
}

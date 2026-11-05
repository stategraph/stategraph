"use client";

import type { TransactionLogRow } from "@/lib/timeline/types";
import { useState, useEffect, useCallback } from "react";
import { executeMQL } from "@/lib/api/client";
import {
  transactionLogsQuery,
  MAX_PAGE_LIMIT,
} from "@/app/(console)/timeline/mqlQueries";
import { CopyButton } from "@/components/ui/copy-button";

interface TransactionLogsProps {
  txId: string;
  resourceFilter?: string;
}

const INITIAL_LOG_LIMIT = 50;
const LOAD_MORE_INCREMENT = 50;

// Log entry component - renders raw log data
function LogEntry({ log, index }: { log: TransactionLogRow; index: number }) {
  const logJson = JSON.stringify(log, null, 2);

  return (
    <div className="bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded min-w-0">
      {/* Log header */}
      <div className="flex items-center justify-between gap-2 px-3 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-xs text-[var(--sg-text-dim)] font-medium">
            #{index + 1}
          </span>
          <span
            className={`text-xs px-2 py-0.5 rounded font-mono ${
              log.action === "state_set"
                ? "bg-[var(--sg-success)]/10 text-[var(--sg-success)]"
                : "bg-[var(--sg-error)]/10 text-[var(--sg-error)]"
            }`}
          >
            {log.action}
          </span>
          <span className="text-xs px-2 py-0.5 rounded font-mono bg-[var(--sg-accent)]/10 text-[var(--sg-accent)]">
            {log.object_type}
          </span>
        </div>
        <CopyButton text={logJson} title="Copy log as JSON" />
      </div>

      {/* Log body - all fields in deterministic order */}
      <div className="p-3 space-y-3 min-w-0">
        {/* Core fields */}
        <div className="grid grid-cols-1 sm:grid-cols-[120px,1fr] gap-x-3 gap-y-1 sm:gap-y-2 text-xs min-w-0">
          <div className="text-[var(--sg-text-dim)]">log_id</div>
          <div className="text-[var(--sg-text)] font-mono break-all">
            {log.id}
          </div>

          <div className="text-[var(--sg-text-dim)]">created_at</div>
          <div className="text-[var(--sg-text)] font-mono">
            {log.created_at}
          </div>

          <div className="text-[var(--sg-text-dim)]">action</div>
          <div className="text-[var(--sg-text)] font-mono">{log.action}</div>

          <div className="text-[var(--sg-text-dim)]">object_type</div>
          <div className="text-[var(--sg-text)] font-mono">
            {log.object_type}
          </div>

          <div className="text-[var(--sg-text-dim)]">state_id</div>
          <div className="text-[var(--sg-text)] font-mono break-all">
            {log.state_id}
          </div>
        </div>

        {/* Data payload - raw JSON */}
        {log.data !== null && log.data !== undefined && (
          <div className="min-w-0">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-medium text-[var(--sg-text-dim)]">
                data (raw JSON payload)
              </span>
              <CopyButton
                text={JSON.stringify(log.data, null, 2)}
                title="Copy data payload"
              />
            </div>
            <pre className="text-xs font-mono text-[var(--sg-text)] bg-[var(--sg-bg-0)] p-3 rounded border border-[var(--sg-border)] overflow-x-auto max-h-80 overflow-y-auto min-w-0 w-full">
              {JSON.stringify(log.data, null, 2)}
            </pre>
          </div>
        )}
      </div>
    </div>
  );
}

export function TransactionLogs({ txId, resourceFilter }: TransactionLogsProps) {
  const [logs, setLogs] = useState<TransactionLogRow[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentLimit, setCurrentLimit] = useState(INITIAL_LOG_LIMIT);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  // Fetch logs for this transaction. The resource filter is applied
  // server-side by the query, so the whole log set is searched — not just the
  // rows already loaded.
  const fetchLogs = useCallback(
    async (limit: number) => {
      try {
        const isInitialLoad = limit === INITIAL_LOG_LIMIT;
        if (isInitialLoad) {
          setIsLoading(true);
        } else {
          setIsLoadingMore(true);
        }
        setError(null);

        // The query orders oldest-first, so no client-side sort is needed.
        const result = await executeMQL(
          transactionLogsQuery(txId, { resource: resourceFilter, limit })
        );
        const rows = result.data as TransactionLogRow[];

        setLogs(rows);
        setHasMore(rows.length === limit && limit < MAX_PAGE_LIMIT);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load logs");
      } finally {
        setIsLoading(false);
        setIsLoadingMore(false);
      }
    },
    [txId, resourceFilter]
  );

  // Reset pagination whenever the transaction or resource filter changes.
  useEffect(() => {
    setCurrentLimit(INITIAL_LOG_LIMIT);
  }, [txId, resourceFilter]);

  useEffect(() => {
    fetchLogs(currentLimit);
  }, [currentLimit, fetchLogs]);

  // Handle load more
  const handleLoadMore = () => {
    setCurrentLimit((prev) => prev + LOAD_MORE_INCREMENT);
  };

  // Copy all logs as JSON
  const allLogsJson = JSON.stringify(logs, null, 2);

  // Loading state
  if (isLoading) {
    return (
      <div className="pb-4">
        <div className="flex items-center justify-between mb-3 pb-2 border-b border-[var(--sg-border)]">
          <h3 className="text-sm font-semibold text-[var(--sg-text)]">
            Transaction Logs
          </h3>
        </div>
        <div className="text-xs text-[var(--sg-text-dim)]">Loading logs...</div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="pb-4">
        <div className="flex items-center justify-between mb-3 pb-2 border-b border-[var(--sg-border)]">
          <h3 className="text-sm font-semibold text-[var(--sg-text)]">
            Transaction Logs
          </h3>
        </div>
        <div className="text-xs text-[var(--sg-error)] bg-[var(--sg-error)]/10 p-3 rounded">
          {error}
        </div>
      </div>
    );
  }

  // Empty state (filtered or not)
  if (logs.length === 0) {
    return (
      <div className="pb-4">
        <div className="flex items-center justify-between mb-3 pb-2 border-b border-[var(--sg-border)]">
          <h3 className="text-sm font-semibold text-[var(--sg-text)]">
            Transaction Logs
          </h3>
          <CopyButton text="[]" title="Copy empty array" />
        </div>
        <div className="text-xs text-[var(--sg-text-dim)] bg-[var(--sg-bg-2)] p-3 rounded border border-[var(--sg-border)]">
          {resourceFilter ? (
            <>
              No logs match the resource filter:{" "}
              <code className="font-mono text-[var(--sg-accent)]">
                {resourceFilter}
              </code>
            </>
          ) : (
            "No logs found"
          )}
        </div>
      </div>
    );
  }

  // Render logs
  return (
    <div className="pb-4 min-w-0">
      {/* Section header */}
      <div className="flex items-center justify-between mb-3 pb-2 border-b border-[var(--sg-border)]">
        <div>
          <h3 className="text-sm font-semibold text-[var(--sg-text)]">
            Transaction Logs
          </h3>
          <p className="text-xs text-[var(--sg-text-dim)] mt-1">
            {logs.length} log{logs.length !== 1 ? "s" : ""}
            {resourceFilter ? " matching filter" : ""} (chronological order)
          </p>
        </div>
        <CopyButton text={allLogsJson} title="Copy all logs as JSON" />
      </div>

      {/* Log entries */}
      <div className="space-y-3 min-w-0">
        {logs.map((log, index) => (
          <LogEntry key={log.id} log={log} index={index} />
        ))}
      </div>

      {/* Load more button */}
      {hasMore && (
        <div className="mt-4">
          <button
            onClick={handleLoadMore}
            disabled={isLoadingMore}
            className="w-full px-4 py-2 text-sm rounded bg-[var(--sg-bg-2)] text-[var(--sg-text)] hover:bg-[var(--sg-accent-bg)] hover:text-[var(--sg-accent)] border border-[var(--sg-border)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoadingMore ? "Loading..." : `Load More Logs (${LOAD_MORE_INCREMENT} at a time)`}
          </button>
        </div>
      )}

      {/* Footer info */}
      <div className="mt-4 pt-3 border-t border-[var(--sg-border)] text-xs text-[var(--sg-text-dim)]">
        Logs rendered in chronological order. No grouping or deduplication
        applied.
      </div>
    </div>
  );
}

"use client";

import { useState, useEffect, useCallback } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { PageHeader } from "@/components/page";
import { useDeepLinkRouter } from "@/hooks";
import {
  TransactionList,
  TransactionDetail,
  TimelineStream,
  TimelineFilterBar,
  LogInspectPanel,
} from "@/components/timeline";
import { useTenant } from "@/contexts/TenantContext";
import { executeMQL } from "@/lib/api/client";
import { transactionsQuery, MAX_PAGE_LIMIT } from "./mqlQueries";
import type {
  TransactionRow,
  TransactionLogRow,
  TimelineStatusFilter,
} from "@/lib/timeline/types";
import { List, Rows3 } from "lucide-react";
import { Button } from "@/components/ui/button";

type ViewMode = "stream" | "split";

const INITIAL_LIMIT = 50;
const LOAD_MORE_INCREMENT = 50;
const SEARCH_DEBOUNCE_MS = 300;

export function TimelineContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const { currentTenant } = useTenant();

  const [transactions, setTransactions] = useState<TransactionRow[]>([]);
  const [selectedTransaction, setSelectedTransaction] =
    useState<TransactionRow | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentLimit, setCurrentLimit] = useState(INITIAL_LIMIT);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  // View mode and filter state
  const [viewMode, setViewMode] = useState<ViewMode>("stream");
  const [statusFilter, setStatusFilter] = useState<TimelineStatusFilter>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [inspectedLog, setInspectedLog] = useState<TransactionLogRow | null>(null);

  const resourceFilter = searchParams.get("resource");

  // Debounce the search box so we query once the user pauses, not per keystroke.
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchQuery), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  // Stream view: navigate to the dedicated detail page
  const handleSelectTransaction = useCallback(
    (tx: TransactionRow) => {
      router.push(`/timeline/detail?tx=${tx.id}`);
    },
    [router]
  );

  // Split view: select inline (no navigation)
  const handleSelectTransactionInline = useCallback(
    (tx: TransactionRow) => {
      setSelectedTransaction(tx);
    },
    []
  );

  // Any filter change resets pagination back to the first page.
  useEffect(() => {
    setCurrentLimit(INITIAL_LIMIT);
  }, [statusFilter, debouncedSearch, resourceFilter]);

  // Fetch transactions. Status / search / resource filters are applied
  // server-side by the query, so they run against the full transaction set
  // rather than the currently-loaded window.
  useEffect(() => {
    if (!currentTenant) {
      setIsLoading(false);
      return;
    }

    let cancelled = false;
    const loadTransactions = async () => {
      try {
        const isInitialLoad = currentLimit === INITIAL_LIMIT;
        if (isInitialLoad) {
          setIsLoading(true);
        } else {
          setIsLoadingMore(true);
        }
        setError(null);

        // The query orders newest-first, so no client-side sort is needed.
        const response = await executeMQL(
          transactionsQuery({
            tenantId: currentTenant.id,
            status: statusFilter,
            search: debouncedSearch,
            resource: resourceFilter,
            limit: currentLimit,
          })
        );

        if (cancelled) return;

        const rows = response.data as TransactionRow[];
        setTransactions(rows);
        setHasMore(rows.length === currentLimit && currentLimit < MAX_PAGE_LIMIT);

        // Auto-select the first transaction for split view
        if (isInitialLoad && rows.length > 0) {
          setSelectedTransaction((prev) => prev ?? rows[0]);
        }
      } catch (err) {
        if (cancelled) return;
        setError(
          err instanceof Error ? err.message : "Failed to load transactions"
        );
      } finally {
        if (!cancelled) {
          setIsLoading(false);
          setIsLoadingMore(false);
        }
      }
    };

    loadTransactions();

    return () => {
      cancelled = true;
    };
  }, [currentTenant, currentLimit, statusFilter, debouncedSearch, resourceFilter]);

  // Handle Load More — bumping currentLimit triggers the fetch effect
  const handleLoadMore = useCallback(() => {
    setCurrentLimit((prev) => Math.min(prev + LOAD_MORE_INCREMENT, MAX_PAGE_LIMIT));
  }, []);

  // Clear resource filter — stay on the current pathname and keep the other
  // query params.
  const handleClearResourceFilter = useCallback(() => {
    const params = new URLSearchParams(searchParams.toString());
    params.delete("resource");
    router.push(
      `${pathname}${params.toString() ? `?${params.toString()}` : ""}`,
      { scroll: false }
    );
  }, [searchParams, router, pathname]);

  // Handle log inspection (stream view)
  const handleInspectLog = useCallback((log: TransactionLogRow) => {
    setInspectedLog(log);
  }, []);

  const handleCloseInspect = useCallback(() => {
    setInspectedLog(null);
  }, []);

  if (!currentTenant) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Activity Timeline"
          subtitle="Forensic timeline of state mutations"
        />
        <div className="flex items-center justify-center flex-1">
          <div className="text-center max-w-md px-6">
            <p className="text-sm text-[var(--sg-text-muted)]">
              Please select a tenant to view activity timeline
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col w-full h-full">
        <PageHeader
          title="Activity Timeline"
          subtitle="Forensic timeline of state mutations"
        />
        <div className="flex items-center justify-center flex-1">
          <div className="text-center max-w-md px-6">
            <p className="text-sm text-[var(--sg-error)] mb-2">Error</p>
            <p className="text-xs text-[var(--sg-text-muted)]">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col w-full h-full">
      <PageHeader
        title="Activity Timeline"
        subtitle="Forensic timeline of state mutations"
      >
        <div className="flex items-center gap-2">
          {/* View Mode Toggle */}
          <div className="flex items-center gap-0.5 bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-1">
            <Button
              variant={viewMode === "stream" ? "default" : "ghost"}
              size="sm"
              onClick={() => setViewMode("stream")}
              className="h-8 px-3"
              title="Stream view"
            >
              <Rows3 className="h-4 w-4" />
            </Button>
            <Button
              variant={viewMode === "split" ? "default" : "ghost"}
              size="sm"
              onClick={() => setViewMode("split")}
              className="h-8 px-3"
              title="Split view"
            >
              <List className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </PageHeader>

      {/* Filter Bar (shared across both views) */}
      <TimelineFilterBar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        statusFilter={statusFilter}
        onStatusFilterChange={setStatusFilter}
        resourceFilter={resourceFilter}
        onClearResourceFilter={handleClearResourceFilter}
      />

      {/* View Content */}
      {viewMode === "stream" ? (
        <div className="flex flex-1 overflow-hidden">
          <div className="flex-1 min-w-0">
            <TimelineStream
              transactions={transactions}
              isLoading={isLoading}
              hasMore={hasMore}
              onLoadMore={handleLoadMore}
              isLoadingMore={isLoadingMore}
              searchQuery={debouncedSearch}
              resourceFilter={resourceFilter}
              onInspectLog={handleInspectLog}
              onSelectTransaction={handleSelectTransaction}
            />
          </div>
          <LogInspectPanel log={inspectedLog} onClose={handleCloseInspect} />
        </div>
      ) : (
        /* Split View Layout — side-by-side on lg+, stacked on mobile/tablet */
        <div className="flex flex-col lg:flex-row flex-1 overflow-hidden min-h-0">
          {/* Left Panel - Transaction List */}
          <div className="w-full lg:w-[520px] flex-1 lg:flex-none min-h-0 border-b lg:border-b-0 lg:border-r border-[var(--sg-border)] bg-[var(--sg-bg-1)] flex flex-col">
            <div className="px-4 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <h2 className="text-sm font-semibold text-[var(--sg-text)]">
                Transactions
              </h2>
              {!isLoading && (
                <p className="text-xs text-[var(--sg-text-dim)] mt-1">
                  {transactions.length} transaction
                  {transactions.length !== 1 ? "s" : ""} (newest first)
                </p>
              )}
            </div>
            <div className="flex-1 min-h-0 overflow-hidden">
              <TransactionList
                transactions={transactions}
                selectedTxId={selectedTransaction?.id || null}
                onSelectTransaction={handleSelectTransactionInline}
                isLoading={isLoading}
                hasMore={hasMore}
                onLoadMore={handleLoadMore}
                isLoadingMore={isLoadingMore}
              />
            </div>
          </div>

          {/* Right Panel - Transaction Detail */}
          <div className="flex-1 min-w-0 min-h-0 bg-[var(--sg-bg-0)] flex flex-col">
            <div className="px-4 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
              <h2 className="text-sm font-semibold text-[var(--sg-text)]">
                Transaction Detail
              </h2>
              {selectedTransaction && (
                <p className="text-xs text-[var(--sg-text-dim)] mt-1 font-mono break-all">
                  {selectedTransaction.id}
                </p>
              )}
            </div>
            <div className="flex-1 min-w-0 min-h-0 overflow-hidden">
              {selectedTransaction ? (
                <TransactionDetail
                  transaction={selectedTransaction}
                  resourceFilter={resourceFilter || undefined}
                />
              ) : (
                <div className="flex items-center justify-center h-full">
                  <p className="text-sm text-[var(--sg-text-dim)]">
                    Select a transaction to view details
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/**
 * Query Results Viewer
 *
 * Main container for displaying query results with view toggle.
 * Supports Table (Curated) and Raw (JSON) views.
 */

import { useState } from 'react';
import { Table, FileJson } from 'lucide-react';
import { CuratedTable } from './CuratedTable';
import { RawJsonView } from './RawJsonView';
import { isSelectAllQuery } from '@/lib/query/columnRanking';

export type ViewMode = 'table' | 'json';

export interface QueryResultsViewerProps {
  results: Record<string, unknown>[];
  query: string;
  /** Threshold for showing wide-result hint (default: 12) */
  wideColumnThreshold?: number;
  /** Callback to load more paginated results */
  onLoadMore?: () => void;
  /** Whether more results are currently being loaded */
  isLoadingMore?: boolean;
  /** Whether there are more results to load */
  hasMore?: boolean;
  /** Hint text for pagination (e.g. missing ORDER BY) */
  paginationHint?: string | null;
}

export function QueryResultsViewer({
  results,
  query,
  wideColumnThreshold = 12,
  onLoadMore,
  isLoadingMore,
  hasMore,
  paginationHint,
}: QueryResultsViewerProps) {
  const [viewMode, setViewMode] = useState<ViewMode>('table');

  if (results.length === 0) {
    return null;
  }

  const columnCount = Object.keys(results[0]).length;
  const isWideResult = columnCount > wideColumnThreshold;
  const isSelectAll = isSelectAllQuery(query);
  const showHint = isWideResult && isSelectAll;

  return (
    <div className="flex-1 flex flex-col min-h-0">
      {/* View Toggle Header */}
      <div className="flex-shrink-0 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
        <div className="flex items-center justify-between px-4 py-1.5">
          <div className="flex items-center gap-1">
            <button
              onClick={() => setViewMode('table')}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-colors ${
                viewMode === 'table'
                  ? 'bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-1)]'
              }`}
            >
              <Table className="w-3.5 h-3.5" />
              Table
            </button>
            <button
              onClick={() => setViewMode('json')}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-colors ${
                viewMode === 'json'
                  ? 'bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]'
                  : 'text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-1)]'
              }`}
            >
              <FileJson className="w-3.5 h-3.5" />
              JSON
            </button>
          </div>

          <div className="text-xs text-[var(--sg-text-dim)]">
            {columnCount} {columnCount === 1 ? 'col' : 'cols'}
            {showHint && viewMode === 'table' && (
              <span className="ml-2 text-[var(--sg-accent)]">
                — try SELECT columns instead of *
              </span>
            )}
          </div>
        </div>
      </div>

      {/* View Content */}
      <div className="flex-1 overflow-hidden">
        {viewMode === 'table' && (
          <CuratedTable
            results={results}
            onViewRaw={() => setViewMode('json')}
            onLoadMore={onLoadMore}
            isLoadingMore={isLoadingMore}
            hasMore={hasMore}
            paginationHint={paginationHint}
          />
        )}
        {viewMode === 'json' && (
          <RawJsonView
            results={results}
            onLoadMore={onLoadMore}
            isLoadingMore={isLoadingMore}
            hasMore={hasMore}
            paginationHint={paginationHint}
          />
        )}
      </div>
    </div>
  );
}

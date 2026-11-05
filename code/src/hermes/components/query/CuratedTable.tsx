/**
 * Curated Table View
 *
 * Shows a smart subset of columns for wide result sets.
 * Displays a banner indicating hidden columns with affordances to show all.
 */

import { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { ChevronRight, Eye } from 'lucide-react';
import { rankColumns } from '@/lib/query/columnRanking';

export interface CuratedTableProps {
  results: Record<string, unknown>[];
  onViewRaw: () => void;
  /** Max columns to show in curated mode (default: 7) */
  maxColumns?: number;
  /** Callback to load more paginated results */
  onLoadMore?: () => void;
  /** Whether more results are currently being loaded */
  isLoadingMore?: boolean;
  /** Whether there are more results to load */
  hasMore?: boolean;
  /** Hint text for pagination (e.g. missing ORDER BY) */
  paginationHint?: string | null;
}

export function CuratedTable({ results, onViewRaw, maxColumns = 7, onLoadMore, isLoadingMore, hasMore, paginationHint }: CuratedTableProps) {
  const [showAllColumns, setShowAllColumns] = useState(false);

  // Extract all columns from first row
  const allColumns = useMemo(() => {
    if (results.length === 0) return [];
    return Object.keys(results[0]);
  }, [results]);

  // Rank and select top columns
  const curatedColumns = useMemo(() => {
    return rankColumns(allColumns, results, maxColumns);
  }, [allColumns, results, maxColumns]);

  // Determine which columns to display
  const displayColumns = showAllColumns ? allColumns : curatedColumns;
  const hasHiddenColumns = allColumns.length > curatedColumns.length;

  // Identify sticky column (first column if it's an identity column)
  const stickyColumn = useMemo(() => {
    if (displayColumns.length === 0) return null;
    const firstCol = displayColumns[0].toLowerCase();
    if (['address', 'name', 'id', 'arn'].includes(firstCol)) {
      return displayColumns[0];
    }
    return null;
  }, [displayColumns]);

  if (results.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-col h-full">
      {/* Banner for hidden columns */}
      {hasHiddenColumns && !showAllColumns && (
        <div className="flex-shrink-0 px-4 py-2 bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] flex items-center justify-between text-sm">
          <div className="flex items-center gap-2">
            <Eye className="w-4 h-4 text-[var(--sg-text-muted)]" />
            <span className="text-[var(--sg-text-muted)]">
              Showing <span className="font-semibold text-[var(--sg-text)]">{curatedColumns.length}</span> of{' '}
              <span className="font-semibold text-[var(--sg-text)]">{allColumns.length}</span> columns
            </span>
          </div>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowAllColumns(true)}
            >
              Show all columns
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={onViewRaw}
            >
              View raw
              <ChevronRight className="w-4 h-4 ml-1" />
            </Button>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="flex-1 overflow-auto">
        <table className="w-full border-collapse">
          <thead className="sticky top-0 bg-[var(--sg-bg-0)] z-10">
            <tr className="border-b border-[var(--sg-border)]">
              {displayColumns.map((column, idx) => (
                <th
                  key={column}
                  className={`text-left py-3 px-4 text-xs font-semibold text-[var(--sg-text-muted)] uppercase whitespace-nowrap ${
                    column === stickyColumn && idx === 0
                      ? 'sticky left-0 bg-[var(--sg-bg-0)] z-20 border-r border-[var(--sg-border)]'
                      : ''
                  }`}
                >
                  {column}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {results.map((row, rowIdx) => (
              <tr
                key={rowIdx}
                className="border-b border-[var(--sg-border)] group hover:bg-[var(--sg-bg-1)] transition-colors"
              >
                {displayColumns.map((column, colIdx) => {
                  const value = row[column];
                  return (
                    <td
                      key={column}
                      className={`py-3 px-4 text-sm font-mono text-[var(--sg-text)] ${
                        column === stickyColumn && colIdx === 0
                          ? 'sticky left-0 bg-[var(--sg-bg-0)] group-hover:bg-[var(--sg-bg-1)] z-10 border-r border-[var(--sg-border)]'
                          : ''
                      }`}
                    >
                      {renderCellValue(value)}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>

        {/* Load More / Pagination Hint */}
        {(hasMore || paginationHint) && (
          <div className="px-4 py-3 border-t border-[var(--sg-border)] flex items-center justify-center gap-3">
            {hasMore && onLoadMore && (
              <Button
                variant="outline"
                size="sm"
                onClick={onLoadMore}
                disabled={isLoadingMore}
              >
                {isLoadingMore ? "Loading..." : "Load More"}
              </Button>
            )}
            {paginationHint && (
              <span className="text-xs text-[var(--sg-warning)]">{paginationHint}</span>
            )}
          </div>
        )}
      </div>

      {/* Footer showing all columns if expanded */}
      {showAllColumns && hasHiddenColumns && (
        <div className="flex-shrink-0 px-4 py-2 bg-[var(--sg-bg-1)] border-t border-[var(--sg-border)] flex items-center justify-between text-sm">
          <span className="text-[var(--sg-text-dim)] text-xs">
            Showing all {allColumns.length} columns
          </span>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setShowAllColumns(false)}
          >
            Show curated columns
          </Button>
        </div>
      )}
    </div>
  );
}

/**
 * Render a cell value with appropriate formatting.
 */
function renderCellValue(value: unknown): React.ReactNode {
  if (value === null || value === undefined) {
    return <span className="text-[var(--sg-text-dim)] italic">null</span>;
  }

  if (typeof value === 'boolean') {
    return <span className="text-[var(--sg-accent)]">{String(value)}</span>;
  }

  if (typeof value === 'object') {
    // Render objects/arrays compactly
    const json = JSON.stringify(value);
    if (json.length > 50) {
      return (
        <span className="text-[var(--sg-text-dim)]" title={json}>
          {json.substring(0, 47)}...
        </span>
      );
    }
    return <span className="text-[var(--sg-text-dim)]">{json}</span>;
  }

  const stringValue = String(value);

  // Truncate very long strings
  if (stringValue.length > 100) {
    return (
      <span title={stringValue}>
        {stringValue.substring(0, 97)}...
      </span>
    );
  }

  return stringValue;
}

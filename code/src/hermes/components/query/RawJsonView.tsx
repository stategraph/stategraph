/**
 * Raw JSON View
 *
 * Pretty-printed JSON view with collapsible structures and search.
 * Shows complete data without horizontal scrolling.
 */

import { useState, useMemo } from 'react';
import { Search, X, ChevronDown, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';

export interface RawJsonViewProps {
  results: Record<string, unknown>[];
  /** Callback to load more paginated results */
  onLoadMore?: () => void;
  /** Whether more results are currently being loaded */
  isLoadingMore?: boolean;
  /** Whether there are more results to load */
  hasMore?: boolean;
  /** Hint text for pagination (e.g. missing ORDER BY) */
  paginationHint?: string | null;
}

export function RawJsonView({ results, onLoadMore, isLoadingMore, hasMore, paginationHint }: RawJsonViewProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [collapsedPaths, setCollapsedPaths] = useState<Set<string>>(new Set());

  // Filter results based on search term
  const filteredResults = useMemo(() => {
    if (!searchTerm.trim()) return results;

    const term = searchTerm.toLowerCase();
    return results.filter(row => {
      const json = JSON.stringify(row).toLowerCase();
      return json.includes(term);
    });
  }, [results, searchTerm]);

  const toggleCollapse = (path: string) => {
    setCollapsedPaths(prev => {
      const next = new Set(prev);
      if (next.has(path)) {
        next.delete(path);
      } else {
        next.add(path);
      }
      return next;
    });
  };

  const collapseAll = () => {
    const allPaths = new Set<string>();
    results.forEach((_, idx) => {
      allPaths.add(`row-${idx}`);
    });
    setCollapsedPaths(allPaths);
  };

  const expandAll = () => {
    setCollapsedPaths(new Set());
  };

  return (
    <div className="flex flex-col h-full bg-[var(--sg-bg-0)]">
      {/* Search and Controls */}
      <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)] space-y-3">
        {/* Search input */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--sg-text-muted)]" />
          <input
            type="text"
            placeholder="Search in JSON..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-10 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent"
          />
          {searchTerm && (
            <button
              onClick={() => setSearchTerm('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Controls */}
        <div className="flex items-center justify-between">
          <div className="text-sm text-[var(--sg-text-muted)]">
            {searchTerm && (
              <span>
                Showing {filteredResults.length} of {results.length} rows
              </span>
            )}
            {!searchTerm && (
              <span>{results.length} rows</span>
            )}
          </div>
          <div className="flex gap-2">
            <Button variant="ghost" size="sm" onClick={collapseAll}>
              Collapse all
            </Button>
            <Button variant="ghost" size="sm" onClick={expandAll}>
              Expand all
            </Button>
          </div>
        </div>
      </div>

      {/* JSON Content */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {filteredResults.length === 0 && searchTerm && (
          <div className="text-center py-8 text-[var(--sg-text-dim)]">
            No results match &ldquo;{searchTerm}&rdquo;
          </div>
        )}

        {filteredResults.map((row, idx) => {
          const path = `row-${idx}`;
          const isCollapsed = collapsedPaths.has(path);

          return (
            <div
              key={idx}
              className="bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg overflow-hidden"
            >
              {/* Row header */}
              <button
                onClick={() => toggleCollapse(path)}
                className="w-full flex items-center justify-between p-3 hover:bg-[var(--sg-bg-2)] transition-colors text-left"
              >
                <div className="flex items-center gap-2">
                  {isCollapsed ? (
                    <ChevronRight className="w-4 h-4 text-[var(--sg-text-muted)]" />
                  ) : (
                    <ChevronDown className="w-4 h-4 text-[var(--sg-text-muted)]" />
                  )}
                  <span className="text-sm font-semibold text-[var(--sg-text)]">
                    Row {idx + 1}
                  </span>
                </div>
                <span className="text-xs text-[var(--sg-text-dim)]">
                  {Object.keys(row).length} fields
                </span>
              </button>

              {/* Row content */}
              {!isCollapsed && (
                <div className="border-t border-[var(--sg-border)] p-4">
                  <JsonObject
                    data={row}
                    searchTerm={searchTerm}
                    level={0}
                  />
                </div>
              )}
            </div>
          );
        })}

        {/* Load More / Pagination Hint */}
        {(hasMore || paginationHint) && (
          <div className="flex items-center justify-center gap-3 py-2">
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
    </div>
  );
}

/**
 * Recursive component for rendering JSON objects with collapsible structure.
 */
function JsonObject({
  data,
  searchTerm,
  level,
}: {
  data: unknown;
  searchTerm: string;
  level: number;
}) {
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  if (data === null || data === undefined) {
    return <span className="text-[var(--sg-text-dim)] italic">null</span>;
  }

  if (typeof data === 'boolean') {
    return <span className="text-[var(--sg-accent)]">{String(data)}</span>;
  }

  if (typeof data === 'number') {
    return <span className="text-[var(--sg-accent)]">{data}</span>;
  }

  if (typeof data === 'string') {
    const highlighted = searchTerm && data.toLowerCase().includes(searchTerm.toLowerCase());
    return (
      <span
        className={`${highlighted ? 'bg-yellow-500/20 text-[var(--sg-text)]' : 'text-[var(--sg-text-dim)]'}`}
      >
        &quot;{data}&quot;
      </span>
    );
  }

  if (Array.isArray(data)) {
    if (data.length === 0) {
      return <span className="text-[var(--sg-text-dim)]">[]</span>;
    }

    return (
      <div className="font-mono text-sm">
        <span className="text-[var(--sg-text-dim)]">[</span>
        <div className="ml-4">
          {data.map((item, idx) => (
            <div key={idx} className="my-1">
              <JsonObject data={item} searchTerm={searchTerm} level={level + 1} />
              {idx < data.length - 1 && <span className="text-[var(--sg-text-dim)]">,</span>}
            </div>
          ))}
        </div>
        <span className="text-[var(--sg-text-dim)]">]</span>
      </div>
    );
  }

  if (typeof data === 'object') {
    const entries = Object.entries(data as Record<string, unknown>);

    if (entries.length === 0) {
      return <span className="text-[var(--sg-text-dim)]">{'{}'}</span>;
    }

    return (
      <div className="font-mono text-sm">
        <span className="text-[var(--sg-text-dim)]">{'{'}</span>
        <div className="ml-4">
          {entries.map(([key, value], idx) => {
            const keyPath = `${level}-${key}`;
            const isCollapsed = collapsed[keyPath];
            const canCollapse = typeof value === 'object' && value !== null;

            return (
              <div key={key} className="my-1 flex items-start gap-2">
                {canCollapse && (
                  <button
                    onClick={() => setCollapsed(prev => ({ ...prev, [keyPath]: !prev[keyPath] }))}
                    className="mt-0.5 hover:text-[var(--sg-accent)] transition-colors"
                  >
                    {isCollapsed ? (
                      <ChevronRight className="w-3 h-3" />
                    ) : (
                      <ChevronDown className="w-3 h-3" />
                    )}
                  </button>
                )}
                {!canCollapse && <span className="w-3" />}
                <div className="flex-1">
                  <span className="text-[var(--sg-text)]">&quot;{key}&quot;</span>
                  <span className="text-[var(--sg-text-dim)]">: </span>
                  {isCollapsed ? (
                    <span className="text-[var(--sg-text-dim)] italic">
                      {Array.isArray(value) ? `[${value.length}]` : '{...}'}
                    </span>
                  ) : (
                    <JsonObject data={value} searchTerm={searchTerm} level={level + 1} />
                  )}
                  {idx < entries.length - 1 && <span className="text-[var(--sg-text-dim)]">,</span>}
                </div>
              </div>
            );
          })}
        </div>
        <span className="text-[var(--sg-text-dim)]">{'}'}</span>
      </div>
    );
  }

  return <span>{String(data)}</span>;
}

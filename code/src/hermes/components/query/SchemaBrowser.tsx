/**
 * MQL Schema Browser
 *
 * Shows available tables and their columns for reference.
 * Fetches schema dynamically from the API.
 */

import { useState, useEffect } from 'react';
import { ChevronDown, ChevronRight, Table, Database, Copy, Check, Loader2 } from 'lucide-react';
import { fetchMQLSchema, type MQLTable } from '@/lib/query/mqlSchema';

export interface SchemaBrowserProps {
  onTableClick?: (tableName: string) => void;
  onColumnClick?: (tableName: string, columnName: string) => void;
}

export function SchemaBrowser({ onTableClick, onColumnClick }: SchemaBrowserProps) {
  const [schema, setSchema] = useState<MQLTable[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedTables, setExpandedTables] = useState<Set<string>>(new Set());
  const [copiedText, setCopiedText] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadSchema() {
      try {
        const data = await fetchMQLSchema();
        if (!cancelled) {
          setSchema(data);
          setLoading(false);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Failed to load schema');
          setLoading(false);
        }
      }
    }

    loadSchema();

    return () => {
      cancelled = true;
    };
  }, []);

  const toggleTable = (tableName: string) => {
    setExpandedTables(prev => {
      const next = new Set(prev);
      if (next.has(tableName)) {
        next.delete(tableName);
      } else {
        next.add(tableName);
      }
      return next;
    });
  };

  const handleCopy = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    setCopiedText(label);
    setTimeout(() => setCopiedText(null), 2000);
  };

  if (loading) {
    return (
      <div className="h-full flex flex-col bg-[var(--sg-bg-0)]">
        <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)]">
          <div className="flex items-center gap-2 mb-2">
            <Database className="w-4 h-4 text-[var(--sg-accent)]" />
            <h3 className="text-sm font-semibold text-[var(--sg-text)]">SQL Schema</h3>
          </div>
        </div>
        <div className="flex-1 flex items-center justify-center">
          <div className="flex items-center gap-2 text-[var(--sg-text-dim)]">
            <Loader2 className="w-4 h-4 animate-spin" />
            <span className="text-sm">Loading schema...</span>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-full flex flex-col bg-[var(--sg-bg-0)]">
        <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)]">
          <div className="flex items-center gap-2 mb-2">
            <Database className="w-4 h-4 text-[var(--sg-accent)]" />
            <h3 className="text-sm font-semibold text-[var(--sg-text)]">SQL Schema</h3>
          </div>
        </div>
        <div className="flex-1 flex items-center justify-center p-4">
          <p className="text-sm text-red-500">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col bg-[var(--sg-bg-0)]">
      {/* Header */}
      <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-2 mb-2">
          <Database className="w-4 h-4 text-[var(--sg-accent)]" />
          <h3 className="text-sm font-semibold text-[var(--sg-text)]">SQL Schema</h3>
        </div>
        <p className="text-xs text-[var(--sg-text-dim)]">
          {schema.length} tables available
        </p>
      </div>

      {/* Tables List */}
      <div className="flex-1 overflow-y-auto p-2">
        {schema.map((table) => (
          <TableItem
            key={table.name}
            table={table}
            isExpanded={expandedTables.has(table.name)}
            onToggle={() => toggleTable(table.name)}
            onTableClick={onTableClick}
            onColumnClick={onColumnClick}
            onCopy={handleCopy}
            copiedText={copiedText}
          />
        ))}
      </div>

      {/* Footer */}
      <div className="flex-shrink-0 p-3 border-t border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
        <p className="text-xs text-[var(--sg-text-dim)]">
          Click to insert table/column names
        </p>
      </div>
    </div>
  );
}

interface TableItemProps {
  table: MQLTable;
  isExpanded: boolean;
  onToggle: () => void;
  onTableClick?: (tableName: string) => void;
  onColumnClick?: (tableName: string, columnName: string) => void;
  onCopy: (text: string, label: string) => void;
  copiedText: string | null;
}

function TableItem({
  table,
  isExpanded,
  onToggle,
  onTableClick,
  onColumnClick,
  onCopy,
  copiedText,
}: TableItemProps) {
  const isCopied = copiedText === table.name;

  return (
    <div className="mb-1">
      {/* Table Header */}
      <div className="group flex items-center gap-1 px-2 py-1.5 hover:bg-[var(--sg-bg-1)] rounded-md transition-colors">
        <button
          onClick={onToggle}
          className="flex items-center gap-1 flex-1 min-w-0"
        >
          {isExpanded ? (
            <ChevronDown className="w-3.5 h-3.5 text-[var(--sg-text-muted)] flex-shrink-0" />
          ) : (
            <ChevronRight className="w-3.5 h-3.5 text-[var(--sg-text-muted)] flex-shrink-0" />
          )}
          <Table className="w-3.5 h-3.5 text-[var(--sg-accent)] flex-shrink-0" />
          <span
            className="text-sm font-medium text-[var(--sg-text)] truncate cursor-pointer hover:text-[var(--sg-accent)] transition-colors"
            onClick={(e) => {
              e.stopPropagation();
              onTableClick?.(table.name);
            }}
            title={table.name}
          >
            {table.name}
          </span>
        </button>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onCopy(table.name, table.name);
          }}
          className="opacity-0 group-hover:opacity-100 p-1 hover:bg-[var(--sg-bg-2)] rounded transition-opacity"
          title="Copy table name"
        >
          {isCopied ? (
            <Check className="w-3 h-3 text-green-500" />
          ) : (
            <Copy className="w-3 h-3 text-[var(--sg-text-dim)]" />
          )}
        </button>
      </div>

      {/* Columns */}
      {isExpanded && (
        <div className="ml-9 space-y-0.5 mb-2">
          {table.columns.map((column) => {
            const columnLabel = `${table.name}.${column.name}`;
            const isColumnCopied = copiedText === columnLabel;

            return (
              <div
                key={column.name}
                className="group flex items-center gap-2 px-2 py-1 hover:bg-[var(--sg-bg-2)] rounded-md transition-colors"
              >
                <span
                  className="text-xs font-mono text-[var(--sg-text-muted)] cursor-pointer hover:text-[var(--sg-text)] transition-colors flex-1 min-w-0 truncate"
                  onClick={() => onColumnClick?.(table.name, column.name)}
                  title={column.name}
                >
                  {column.name}
                </span>
                <span className="text-xs text-[var(--sg-text-dim)] flex-shrink-0">
                  {column.type}
                </span>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onCopy(column.name, columnLabel);
                  }}
                  className="opacity-0 group-hover:opacity-100 p-0.5 hover:bg-[var(--sg-bg-1)] rounded transition-opacity flex-shrink-0"
                  title="Copy column name"
                >
                  {isColumnCopied ? (
                    <Check className="w-3 h-3 text-green-500" />
                  ) : (
                    <Copy className="w-3 h-3 text-[var(--sg-text-dim)]" />
                  )}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

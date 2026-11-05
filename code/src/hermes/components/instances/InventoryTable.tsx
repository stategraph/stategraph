"use client";

import { Instance } from '@/lib/api/client';
import { useState, useMemo } from 'react';
import {
  getInstanceDisplayName,
  getTagValue,
  resolveColumns,
  type ColumnConfig,
  type ColumnDefinition,
} from '@/lib/instances';
import { Badge } from '@/components/ui/badge';
import { Checkbox } from '@/components/ui/checkbox';
import { Copy, CheckCircle2, Layers } from 'lucide-react';

interface InventoryTableProps {
  instances: Instance[];
  selectedInstances: Set<string>;
  onSelectionChange: (selected: Set<string>) => void;
  onInstanceClick: (instance: Instance) => void;
  isLoading?: boolean;
  searchScope?: 'current_state' | 'all_states';
  columnConfig: ColumnConfig;
}

/**
 * Pinned tag keys to display as inline chips under resource name.
 * Only tags that exist will be shown (no empty UI).
 */
const PINNED_TAG_KEYS = ['Environment', 'Env', 'Service', 'Owner', 'Team'];

/**
 * Get pinned tags for an instance (max 3 to avoid clutter).
 * Returns array of {key, value} for tags that exist.
 */
function getPinnedTags(instance: Instance): Array<{ key: string; value: string }> {
  const tags: Array<{ key: string; value: string }> = [];

  for (const key of PINNED_TAG_KEYS) {
    if (tags.length >= 3) break; // Max 3 tags for density

    const value = getTagValue(instance, key);
    if (value) {
      tags.push({ key, value });
    }
  }

  return tags;
}

/**
 * Format a column value based on its format type
 */
function formatColumnValue(
  value: string | undefined,
  format?: ColumnDefinition['format']
): React.ReactNode {
  if (!value) {
    return <span className="text-[var(--sg-text-dim)]">—</span>;
  }

  switch (format) {
    case 'badge':
      return (
        <Badge variant="secondary" className="text-xs">
          {value}
        </Badge>
      );
    case 'mono':
    case 'code':
      return <span className="text-xs font-mono text-[var(--sg-text-muted)]">{value}</span>;
    case 'text':
    default:
      return <span className="text-xs text-[var(--sg-text-muted)]">{value}</span>;
  }
}

/**
 * Dense inventory table for Firefly-style asset view
 */
export function InventoryTable({
  instances,
  selectedInstances,
  onSelectionChange,
  onInstanceClick,
  isLoading = false,
  searchScope = 'current_state',
  columnConfig,
}: InventoryTableProps) {
  const [copiedAddress, setCopiedAddress] = useState<string | null>(null);

  // Resolve columns from config, auto-inject state column in all-states mode
  const columns = useMemo(() => {
    const resolved = resolveColumns(columnConfig, instances);
    if (searchScope === 'all_states' && !columnConfig.visibleColumns.includes('state_name')) {
      const stateCol = resolveColumns({ visibleColumns: ['state_name'], tagColumns: [] }, instances);
      // Insert after 'resource' column (index 0) if it exists, otherwise prepend
      const resourceIdx = resolved.findIndex(c => c.id === 'resource');
      if (resourceIdx >= 0) {
        resolved.splice(resourceIdx + 1, 0, ...stateCol);
      } else {
        resolved.unshift(...stateCol);
      }
    }
    return resolved;
  }, [columnConfig, instances, searchScope]);

  if (isLoading) {
    return <InventoryTableSkeleton columns={columns} />;
  }

  if (instances.length === 0) {
    return <InventoryTableEmpty />;
  }

  const allSelected = instances.length > 0 && instances.every(i => selectedInstances.has(i.address));

  const toggleAll = () => {
    if (allSelected) {
      onSelectionChange(new Set());
    } else {
      onSelectionChange(new Set(instances.map(i => i.address)));
    }
  };

  const toggleInstance = (address: string) => {
    const next = new Set(selectedInstances);
    if (next.has(address)) {
      next.delete(address);
    } else {
      next.add(address);
    }
    onSelectionChange(next);
  };

  const copyAddress = async (address: string, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await navigator.clipboard.writeText(address);
      setCopiedAddress(address);
      setTimeout(() => setCopiedAddress(null), 2000);
    } catch (error) {
      console.error('Failed to copy address:', error);
      // Fallback: try using execCommand for older browsers
      try {
        const textArea = document.createElement('textarea');
        textArea.value = address;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        setCopiedAddress(address);
        setTimeout(() => setCopiedAddress(null), 2000);
      } catch (fallbackError) {
        console.error('Fallback copy also failed:', fallbackError);
      }
    }
  };

  return (
    <>
    {/* Desktop / tablet table (lg+) */}
    <div className="hidden lg:block border border-[var(--sg-border)] rounded-lg overflow-hidden bg-[var(--sg-bg-0)]">
      <div className="overflow-x-auto">
        <table className="w-full">
          {/* Header */}
          <thead className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)] sticky top-0 z-10">
            <tr>
              {/* Selection Column */}
              <th className="w-10 px-3 py-2.5" scope="col">
                <Checkbox
                  checked={allSelected}
                  onCheckedChange={toggleAll}
                  aria-label="Select all resources"
                />
              </th>

              {/* Dynamic Columns */}
              {columns.map((column) => (
                <th
                  key={column.id}
                  scope="col"
                  className={`text-left px-3 py-2.5 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide ${column.width || ''}`}
                >
                  {column.label}
                </th>
              ))}

            </tr>
          </thead>

          {/* Body */}
          <tbody>
            {instances.map((instance) => {
              const displayName = getInstanceDisplayName(instance);
              const isSelected = selectedInstances.has(instance.address);
              const pinnedTags = getPinnedTags(instance);

              return (
                <tr
                  key={instance.state_id ? `${instance.state_id}:${instance.address}` : instance.address}
                  className={`
                    group
                    border-b border-[var(--sg-border)]
                    transition-colors duration-150 ease-in-out
                    hover:bg-[var(--sg-bg-1)] hover:shadow-sm
                    cursor-pointer
                    ${isSelected ? 'bg-[var(--sg-accent-bg)] shadow-sm' : ''}
                  `}
                  onClick={() => onInstanceClick(instance)}
                  role="row"
                  aria-selected={isSelected}
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      onInstanceClick(instance);
                    }
                  }}
                >
                  {/* Selection */}
                  <td className="px-3 py-3" role="cell">
                    <Checkbox
                      checked={isSelected}
                      onCheckedChange={() => toggleInstance(instance.address)}
                      onClick={(e) => e.stopPropagation()}
                      aria-label={`Select ${displayName}`}
                    />
                  </td>

                  {/* Dynamic Columns */}
                  {columns.map((column) => {
                    // Special case: Resource column with inline tags
                    if (column.id === 'resource') {
                      return (
                        <td
                          key={column.id}
                          className="px-3 py-3"
                          title={instance.address}
                          role="cell"
                        >
                          <div className="flex flex-col gap-2">
                            {/* Resource Name */}
                            <div className="flex items-center gap-2">
                              <span className="text-sm font-medium text-[var(--sg-text)] leading-tight">
                                {displayName}
                              </span>
                              <button
                                onClick={(e) => copyAddress(instance.address, e)}
                                className="opacity-0 group-hover:opacity-100 hover:opacity-100 transition-opacity duration-150"
                                title="Copy address"
                                aria-label={`Copy address for ${displayName}`}
                              >
                                {copiedAddress === instance.address ? (
                                  <CheckCircle2 className="h-3 w-3 text-[var(--sg-success)]" aria-label="Copied" />
                                ) : (
                                  <Copy className="h-3 w-3 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors" />
                                )}
                              </button>
                            </div>

                            {/* Inline Tag Chips (only if tags exist) */}
                            {pinnedTags.length > 0 && (
                              <div className="flex flex-wrap gap-1.5 animate-in fade-in duration-200">
                                {pinnedTags.map((tag, index) => (
                                  <span
                                    key={tag.key}
                                    className="inline-flex items-center px-2 py-1 rounded text-[10px] bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border border-[var(--sg-border)] transition-colors hover:bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)] hover:text-[var(--sg-text)]"
                                    title={`${tag.key}: ${tag.value}`}
                                    style={{ animationDelay: `${index * 50}ms` }}
                                  >
                                    <span className="font-semibold">{tag.key}:</span>
                                    <span className="ml-1">{tag.value}</span>
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        </td>
                      );
                    }

                    // Standard column
                    const value = column.getValue(instance);
                    return (
                      <td key={column.id} className="px-3 py-3" role="cell">
                        {formatColumnValue(value, column.format)}
                      </td>
                    );
                  })}

                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>

    {/* Mobile / small-screen card list (below lg) */}
    <div className="lg:hidden space-y-3">
      {instances.map((instance) => {
        const displayName = getInstanceDisplayName(instance);
        const isSelected = selectedInstances.has(instance.address);
        const pinnedTags = getPinnedTags(instance);
        const detailColumns = columns.filter((c) => c.id !== 'resource');

        return (
          <div
            key={instance.state_id ? `${instance.state_id}:${instance.address}` : instance.address}
            onClick={() => onInstanceClick(instance)}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                onInstanceClick(instance);
              }
            }}
            className={`rounded-lg border p-3 cursor-pointer transition-colors ${
              isSelected
                ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                : 'border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:bg-[var(--sg-bg-2)]'
            }`}
          >
            <div className="flex items-start gap-3">
              <div className="pt-0.5" onClick={(e) => e.stopPropagation()}>
                <Checkbox
                  checked={isSelected}
                  onCheckedChange={() => toggleInstance(instance.address)}
                  aria-label={`Select ${displayName}`}
                />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start gap-2">
                  <span className="text-sm font-medium text-[var(--sg-text)] break-all min-w-0">
                    {displayName}
                  </span>
                  <button
                    onClick={(e) => copyAddress(instance.address, e)}
                    className="flex-shrink-0 mt-0.5"
                    title="Copy address"
                    aria-label={`Copy address for ${displayName}`}
                  >
                    {copiedAddress === instance.address ? (
                      <CheckCircle2 className="h-3 w-3 text-[var(--sg-success)]" />
                    ) : (
                      <Copy className="h-3 w-3 text-[var(--sg-text-dim)]" />
                    )}
                  </button>
                </div>

                {pinnedTags.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 mt-2">
                    {pinnedTags.map((tag) => (
                      <span
                        key={tag.key}
                        className="inline-flex items-center px-2 py-1 rounded text-[10px] bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border border-[var(--sg-border)]"
                        title={`${tag.key}: ${tag.value}`}
                      >
                        <span className="font-semibold">{tag.key}:</span>
                        <span className="ml-1">{tag.value}</span>
                      </span>
                    ))}
                  </div>
                )}

                {detailColumns.length > 0 && (
                  <dl className="mt-3 space-y-1.5">
                    {detailColumns.map((column) => (
                      <div
                        key={column.id}
                        className="flex items-baseline justify-between gap-3"
                      >
                        <dt className="text-[11px] uppercase tracking-wide text-[var(--sg-text-dim)] flex-shrink-0">
                          {column.label}
                        </dt>
                        <dd className="min-w-0 text-right break-all">
                          {formatColumnValue(column.getValue(instance), column.format)}
                        </dd>
                      </div>
                    ))}
                  </dl>
                )}
              </div>
            </div>
          </div>
        );
      })}
    </div>
    </>
  );
}

/**
 * Loading skeleton with exact layout matching
 */
function InventoryTableSkeleton({ columns }: { columns: ColumnDefinition[] }) {
  return (
    <>
    {/* Mobile skeleton (below lg) */}
    <div className="lg:hidden space-y-3">
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-0)] p-3 space-y-2 animate-pulse"
          style={{ animationDuration: '2s' }}
        >
          <div className="h-3 w-2/3 bg-[var(--sg-bg-2)] rounded" />
          <div className="h-3 w-1/3 bg-[var(--sg-bg-2)] rounded" />
        </div>
      ))}
    </div>

    {/* Desktop / tablet skeleton (lg+) */}
    <div className="hidden lg:block border border-[var(--sg-border)] rounded-lg overflow-hidden bg-[var(--sg-bg-0)]">
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)]">
            <tr>
              {/* Selection */}
              <th className="w-10 px-3 py-2.5" scope="col"></th>

              {/* Dynamic Columns */}
              {columns.map((column) => (
                <th
                  key={column.id}
                  scope="col"
                  className={`text-left px-3 py-2.5 text-xs font-medium text-[var(--sg-text-muted)] uppercase tracking-wide ${column.width || ''}`}
                >
                  {column.label}
                </th>
              ))}

            </tr>
          </thead>
          <tbody>
            {Array.from({ length: 15 }).map((_, i) => (
              <tr key={i} className="border-b border-[var(--sg-border)] animate-in fade-in duration-200" style={{ animationDelay: `${i * 30}ms` }}>
                {/* Selection skeleton */}
                <td className="px-3 py-3">
                  <div className="h-4 w-4 bg-[var(--sg-bg-2)] rounded animate-pulse" style={{ animationDuration: '2s' }}></div>
                </td>

                {/* Dynamic column skeletons */}
                {columns.map((column, colIndex) => (
                  <td key={column.id} className="px-3 py-3">
                    <div
                      className="h-3 bg-[var(--sg-bg-2)] rounded animate-pulse"
                      style={{
                        width: column.id === 'resource' ? '60%' : '80%',
                        animationDuration: '2s',
                        animationDelay: `${colIndex * 100}ms`
                      }}
                    ></div>
                  </td>
                ))}

              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
    </>
  );
}

/**
 * Empty state with improved visual hierarchy
 */
function InventoryTableEmpty() {
  return (
    <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-0)] overflow-hidden animate-in fade-in duration-300">
      <div className="px-12 py-16 text-center space-y-4">
        {/* Icon */}
        <div className="flex justify-center">
          <div className="w-16 h-16 rounded-full bg-[var(--sg-bg-2)] flex items-center justify-center">
            <Layers className="h-8 w-8 text-[var(--sg-text-dim)]" />
          </div>
        </div>

        {/* Message */}
        <div className="space-y-2">
          <h3 className="text-base font-semibold text-[var(--sg-text)]">
            No resources found
          </h3>
          <p className="text-sm text-[var(--sg-text-muted)] max-w-md mx-auto">
            Try adjusting your filters, search query, or view selection to see resources
          </p>
        </div>

        {/* Suggestions */}
        <div className="pt-2">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-[var(--sg-bg-1)] border border-[var(--sg-border)]">
            <span className="text-xs text-[var(--sg-text-dim)]">Tip: Clear all filters to see all resources</span>
          </div>
        </div>
      </div>
    </div>
  );
}

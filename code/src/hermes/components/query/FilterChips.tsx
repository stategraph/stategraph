"use client";

import { X } from 'lucide-react';

interface FilterChipsProps {
  filters: Array<{
    type: 'provider' | 'type' | 'module';
    value: string;
  }>;
  onRemove: (type: string, value: string) => void;
}

/**
 * FilterChips - Display active filters as removable chips
 */
export function FilterChips({ filters, onRemove }: FilterChipsProps) {
  if (filters.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      {filters.map((filter, index) => (
        <button
          key={`${filter.type}-${filter.value}-${index}`}
          onClick={() => onRemove(filter.type, filter.value)}
          className="inline-flex items-center gap-1.5 px-2 py-1 rounded bg-[var(--sg-accent-bg)] border border-[var(--sg-accent)]/20 text-[var(--sg-accent)] hover:bg-[var(--sg-accent)]/20 transition-colors sg-metadata"
        >
          <span className="font-medium capitalize">{filter.type}:</span>
          <span>{filter.value}</span>
          <X className="h-3 w-3" />
        </button>
      ))}
    </div>
  );
}

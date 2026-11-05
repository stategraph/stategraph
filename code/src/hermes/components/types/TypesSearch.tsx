"use client";

import { Input } from '@/components/ui/input';
import { Search, X } from 'lucide-react';

interface TypesSearchProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}

/**
 * TypesSearch - Search input for filtering resource types
 */
export function TypesSearch({
  value,
  onChange,
  placeholder = 'Search resource types or providers...',
}: TypesSearchProps) {
  return (
    <div className="relative flex-1">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
      <Input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="pl-10 pr-10 bg-[var(--sg-bg-1)] border-[var(--sg-border)] text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)]"
      />
      {value && (
        <button
          type="button"
          onClick={() => onChange('')}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
        >
          <X className="h-4 w-4" />
        </button>
      )}
    </div>
  );
}

"use client";

import { useState, useEffect } from 'react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Search, X } from 'lucide-react';

interface InstanceQueryBarProps {
  value: string;
  onChange: (value: string) => void;
  onSearch: () => void;
  placeholder?: string;
}

/**
 * InstanceQueryBar - Search input with query suggestions
 */
export function InstanceQueryBar({
  value,
  onChange,
  onSearch,
  placeholder = 'Search resources (e.g., provider:aws type:aws_s3_bucket)',
}: InstanceQueryBarProps) {
  const [localValue, setLocalValue] = useState(value);

  useEffect(() => {
    setLocalValue(value);
  }, [value]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onChange(localValue);
    onSearch();
  };

  const handleClear = () => {
    setLocalValue('');
    onChange('');
    onSearch();
  };

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-2">
      <div className="relative flex-1">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
        <Input
          type="text"
          value={localValue}
          onChange={(e) => setLocalValue(e.target.value)}
          placeholder={placeholder}
          className="pl-10 pr-10 bg-[var(--sg-bg-1)] border-[var(--sg-border)] text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)]"
        />
        {localValue && (
          <button
            type="button"
            onClick={handleClear}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>
      <Button type="submit" variant="default" size="sm">
        Search
      </Button>
    </form>
  );
}

/**
 * QuerySuggestions - Display common query patterns
 */
export function QuerySuggestions({ onSelectQuery }: { onSelectQuery: (query: string) => void }) {
  const suggestions = [
    { label: 'AWS Resources', query: 'provider:aws' },
    { label: 'S3 Buckets', query: 'type:aws_s3_bucket' },
    { label: 'GCP Resources', query: 'provider:google' },
    { label: 'Kubernetes', query: 'provider:kubernetes' },
  ];

  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="sg-metadata text-[var(--sg-text-dim)]">Quick filters:</span>
      {suggestions.map((suggestion) => (
        <button
          key={suggestion.query}
          onClick={() => onSelectQuery(suggestion.query)}
          className="px-2 py-1 rounded sg-metadata bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] hover:bg-[var(--sg-accent-bg)] hover:text-[var(--sg-accent)] transition-colors border border-[var(--sg-border)]"
        >
          {suggestion.label}
        </button>
      ))}
    </div>
  );
}

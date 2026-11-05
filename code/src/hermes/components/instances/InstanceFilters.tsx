"use client";

import { Button } from '@/components/ui/button';
import { X } from 'lucide-react';

interface InstanceFiltersProps {
  providers: string[];
  types: string[];
  selectedProvider?: string;
  selectedType?: string;
  onProviderChange: (provider: string | undefined) => void;
  onTypeChange: (type: string | undefined) => void;
  onClearAll: () => void;
}

/**
 * InstanceFilters - Quick filter dropdown for providers and types
 */
export function InstanceFilters({
  providers,
  types,
  selectedProvider,
  selectedType,
  onProviderChange,
  onTypeChange,
  onClearAll,
}: InstanceFiltersProps) {
  const hasActiveFilters = selectedProvider || selectedType;

  return (
    <div className="flex items-center gap-3 p-4 bg-[var(--sg-bg-1)] border-b border-[var(--sg-border)]">
      <span className="sg-metadata text-[var(--sg-text-dim)] flex-shrink-0">
        Filters:
      </span>

      {/* Provider Filter */}
      <select
        value={selectedProvider || ''}
        onChange={(e) => onProviderChange(e.target.value || undefined)}
        className="sg-input h-8 text-sm"
      >
        <option value="">All Providers</option>
        {providers.map((provider) => (
          <option key={provider} value={provider}>
            {provider.toUpperCase()}
          </option>
        ))}
      </select>

      {/* Type Filter */}
      <select
        value={selectedType || ''}
        onChange={(e) => onTypeChange(e.target.value || undefined)}
        className="sg-input h-8 text-sm"
      >
        <option value="">All Types</option>
        {types.map((type) => (
          <option key={type} value={type}>
            {type}
          </option>
        ))}
      </select>

      {/* Clear All Button */}
      {hasActiveFilters && (
        <Button
          variant="ghost"
          size="sm"
          onClick={onClearAll}
          className="h-8 px-2"
        >
          <X className="h-3 w-3 mr-1" />
          Clear
        </Button>
      )}
    </div>
  );
}

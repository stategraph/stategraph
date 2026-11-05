"use client";

import React from "react";
import { Filter, X } from "lucide-react";
import { Button } from "@/components/ui/button";

interface FilterBarProps {
  q: string;
  onChange: (q: string) => void;
  providers: string[];
  types: string[];
  modules: string[];
}

export function FilterBar({
  q,
  onChange,
  providers,
  types,
  modules,
}: FilterBarProps) {
  // Parse current filters from query string
  const parseFilters = (query: string) => {
    const filters = {
      provider: [] as string[],
      type: [] as string[],
      module: [] as string[],
      freeText: [] as string[],
    };

    const parts = query.split(/\s+/).filter(Boolean);
    parts.forEach((part) => {
      const match = part.match(/^(provider|type|module):(.+)$/);
      if (match) {
        const [, key, value] = match;
        filters[key as keyof typeof filters].push(value);
      } else {
        filters.freeText.push(part);
      }
    });

    return filters;
  };

  const currentFilters = parseFilters(q);

  // Add a filter
  const addFilter = (key: "provider" | "type" | "module", value: string) => {
    const newQuery = q
      ? `${q} ${key}:${value}`.trim()
      : `${key}:${value}`;
    onChange(newQuery);
  };

  // Remove a filter
  const removeFilter = (key: "provider" | "type" | "module", value: string) => {
    const parts = q.split(/\s+/).filter(Boolean);
    const filtered = parts.filter((part) => part !== `${key}:${value}`);
    onChange(filtered.join(" "));
  };

  // Clear all filters
  const clearAllFilters = () => {
    onChange("");
  };

  const hasActiveFilters =
    currentFilters.provider.length > 0 ||
    currentFilters.type.length > 0 ||
    currentFilters.module.length > 0;

  return (
    <div className="space-y-3">
      {/* Filter Controls */}
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 text-sm text-[var(--sg-text-muted)]">
          <Filter className="h-3.5 w-3.5" />
          <span className="sg-metadata font-medium">Filters:</span>
        </div>

        {/* Provider Filter */}
        <FilterDropdown
          label="Provider"
          options={providers}
          selected={currentFilters.provider}
          onAdd={(value) => addFilter("provider", value)}
          onRemove={(value) => removeFilter("provider", value)}
        />

        {/* Type Filter */}
        <FilterDropdown
          label="Type"
          options={types}
          selected={currentFilters.type}
          onAdd={(value) => addFilter("type", value)}
          onRemove={(value) => removeFilter("type", value)}
        />

        {/* Module Filter */}
        <FilterDropdown
          label="Module"
          options={modules}
          selected={currentFilters.module}
          onAdd={(value) => addFilter("module", value)}
          onRemove={(value) => removeFilter("module", value)}
        />

        {/* Clear All */}
        {hasActiveFilters && (
          <Button
            variant="ghost"
            size="sm"
            onClick={clearAllFilters}
            className="ml-auto text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)]"
          >
            Clear all
          </Button>
        )}
      </div>

      {/* Active Filter Pills */}
      {hasActiveFilters && (
        <div className="flex flex-wrap gap-2">
          {currentFilters.provider.map((value) => (
            <FilterPill
              key={`provider:${value}`}
              label="provider"
              value={value}
              onRemove={() => removeFilter("provider", value)}
            />
          ))}
          {currentFilters.type.map((value) => (
            <FilterPill
              key={`type:${value}`}
              label="type"
              value={value}
              onRemove={() => removeFilter("type", value)}
            />
          ))}
          {currentFilters.module.map((value) => (
            <FilterPill
              key={`module:${value}`}
              label="module"
              value={value}
              onRemove={() => removeFilter("module", value)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// Filter Dropdown Component
function FilterDropdown({
  label,
  options,
  selected,
  onAdd,
  onRemove: _onRemove,
}: {
  label: string;
  options: string[];
  selected: string[];
  onAdd: (value: string) => void;
  onRemove: (value: string) => void;
}) {
  const [isOpen, setIsOpen] = React.useState(false);
  const dropdownRef = React.useRef<HTMLDivElement>(null);

  // Close on click outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [isOpen]);

  const availableOptions = options.filter((opt) => !selected.includes(opt));

  return (
    <div ref={dropdownRef} className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="px-3 py-1.5 text-xs font-medium bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded hover:bg-[var(--sg-bg-1)] transition-colors"
      >
        {label}
        {selected.length > 0 && (
          <span className="ml-1.5 text-[var(--sg-accent)]">
            ({selected.length})
          </span>
        )}
      </button>

      {isOpen && availableOptions.length > 0 && (
        <div className="absolute top-full mt-1 z-50 w-48 max-h-64 overflow-y-auto bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg shadow-lg">
          {availableOptions.map((option) => (
            <button
              key={option}
              onClick={() => {
                onAdd(option);
                setIsOpen(false);
              }}
              className="w-full px-3 py-2 text-left text-xs font-mono hover:bg-[var(--sg-bg-1)] transition-colors"
            >
              {option}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// Filter Pill Component
function FilterPill({
  label,
  value,
  onRemove: _onRemove,
}: {
  label: string;
  value: string;
  onRemove: () => void;
}) {
  return (
    <div className="inline-flex items-center gap-1.5 px-2 py-1 bg-[var(--sg-accent-bg)] border border-[var(--sg-accent)] rounded text-xs">
      <span className="text-[var(--sg-text-dim)]">{label}:</span>
      <span className="font-mono text-[var(--sg-accent)]">{value}</span>
      <button
        onClick={_onRemove}
        className="hover:text-[var(--sg-text)] transition-colors"
      >
        <X className="h-3 w-3" />
      </button>
    </div>
  );
}

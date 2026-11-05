"use client";

import { Instance } from '@/lib/api/client';
import { useState, useMemo } from 'react';
import { getEnvironment, getLocation, getProviderLabel } from '@/lib/instances';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { X, ChevronDown, ChevronRight } from 'lucide-react';
import { Checkbox } from '@/components/ui/checkbox';

export interface FacetFilters {
  providers: Set<string>;
  types: Set<string>;
  environments: Set<string>;
  locations: Set<string>;
  modules: Set<string>;
}

interface FacetedFiltersProps {
  instances: Instance[];
  filters: FacetFilters;
  onFiltersChange: (filters: FacetFilters) => void;
}

interface FacetOption {
  value: string;
  count: number;
}

/**
 * Faceted filters for inventory view.
 * Provides composable filters with counts.
 */
export function FacetedFilters({
  instances,
  filters,
  onFiltersChange,
}: FacetedFiltersProps) {
  const [expandedFacets, setExpandedFacets] = useState<Set<string>>(
    new Set(['providers', 'types'])
  );

  // Compute facet options with counts
  const facetOptions = useMemo(() => {
    const providers = new Map<string, number>();
    const types = new Map<string, number>();
    const environments = new Map<string, number>();
    const locations = new Map<string, number>();
    const modules = new Map<string, number>();

    instances.forEach((instance) => {
      // Format provider name for display (e.g., "hashicorp/aws")
      const providerLabel = getProviderLabel(instance.provider);
      providers.set(providerLabel, (providers.get(providerLabel) || 0) + 1);
      types.set(instance.type, (types.get(instance.type) || 0) + 1);

      const env = getEnvironment(instance);
      if (env) {
        environments.set(env, (environments.get(env) || 0) + 1);
      }

      const loc = getLocation(instance);
      if (loc) {
        locations.set(loc, (locations.get(loc) || 0) + 1);
      }

      if (instance.module) {
        modules.set(instance.module, (modules.get(instance.module) || 0) + 1);
      }
    });

    const toOptions = (map: Map<string, number>): FacetOption[] =>
      Array.from(map.entries())
        .map(([value, count]) => ({ value, count }))
        .sort((a, b) => b.count - a.count);

    return {
      providers: toOptions(providers),
      types: toOptions(types),
      environments: toOptions(environments),
      locations: toOptions(locations),
      modules: toOptions(modules),
    };
  }, [instances]);

  const toggleFacet = (facet: string) => {
    setExpandedFacets((prev) => {
      const next = new Set(prev);
      if (next.has(facet)) {
        next.delete(facet);
      } else {
        next.add(facet);
      }
      return next;
    });
  };

  const toggleFilter = (facetKey: keyof FacetFilters, value: string) => {
    const next = { ...filters };
    const set = new Set(next[facetKey]);
    if (set.has(value)) {
      set.delete(value);
    } else {
      set.add(value);
    }
    next[facetKey] = set as Set<string>;
    onFiltersChange(next);
  };

  const clearAllFilters = () => {
    onFiltersChange({
      providers: new Set(),
      types: new Set(),
      environments: new Set(),
      locations: new Set(),
      modules: new Set(),
    });
  };

  const activeFilterCount =
    filters.providers.size +
    filters.types.size +
    filters.environments.size +
    filters.locations.size +
    filters.modules.size;

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          Filters
          {activeFilterCount > 0 && (
            <Badge variant="secondary" className="ml-2">
              {activeFilterCount}
            </Badge>
          )}
        </div>
        {activeFilterCount > 0 && (
          <Button
            variant="ghost"
            size="sm"
            onClick={clearAllFilters}
            className="text-xs h-6"
          >
            Clear all
          </Button>
        )}
      </div>

      {/* Facets */}
      <div className="space-y-3">
        <Facet
          title="Provider"
          options={facetOptions.providers}
          selected={filters.providers}
          isExpanded={expandedFacets.has('providers')}
          onToggle={() => toggleFacet('providers')}
          onSelect={(value) => toggleFilter('providers', value)}
        />

        <Facet
          title="Resource Type"
          options={facetOptions.types}
          selected={filters.types}
          isExpanded={expandedFacets.has('types')}
          onToggle={() => toggleFacet('types')}
          onSelect={(value) => toggleFilter('types', value)}
        />

        {facetOptions.environments.length > 0 && (
          <Facet
            title="Environment"
            options={facetOptions.environments}
            selected={filters.environments}
            isExpanded={expandedFacets.has('environments')}
            onToggle={() => toggleFacet('environments')}
            onSelect={(value) => toggleFilter('environments', value)}
          />
        )}

        {facetOptions.locations.length > 0 && (
          <Facet
            title="Location"
            options={facetOptions.locations}
            selected={filters.locations}
            isExpanded={expandedFacets.has('locations')}
            onToggle={() => toggleFacet('locations')}
            onSelect={(value) => toggleFilter('locations', value)}
          />
        )}

        {facetOptions.modules.length > 0 && (
          <Facet
            title="Module"
            options={facetOptions.modules}
            selected={filters.modules}
            isExpanded={expandedFacets.has('modules')}
            onToggle={() => toggleFacet('modules')}
            onSelect={(value) => toggleFilter('modules', value)}
          />
        )}
      </div>
    </div>
  );
}

interface FacetProps {
  title: string;
  options: FacetOption[];
  selected: Set<string>;
  isExpanded: boolean;
  onToggle: () => void;
  onSelect: (value: string) => void;
}

function Facet({ title, options, selected, isExpanded, onToggle, onSelect }: FacetProps) {
  const [showAll, setShowAll] = useState(false);
  const displayOptions = showAll ? options : options.slice(0, 5);

  return (
    <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
      <button
        onClick={onToggle}
        className="w-full flex items-center justify-between px-3 py-2 hover:bg-[var(--sg-bg-2)] transition-colors rounded-t-lg"
      >
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-[var(--sg-text)]">{title}</span>
          {selected.size > 0 && (
            <Badge variant="secondary" className="text-xs">
              {selected.size}
            </Badge>
          )}
        </div>
        {isExpanded ? (
          <ChevronDown className="h-4 w-4 text-[var(--sg-text-muted)]" />
        ) : (
          <ChevronRight className="h-4 w-4 text-[var(--sg-text-muted)]" />
        )}
      </button>

      {isExpanded && (
        <div className="px-3 pb-3 space-y-2">
          {displayOptions.map((option) => (
            <label
              key={option.value}
              className="flex items-center gap-2 cursor-pointer hover:bg-[var(--sg-bg-2)] -mx-1 px-1 py-1 rounded transition-colors"
              title={option.value}
            >
              <Checkbox
                checked={selected.has(option.value)}
                onCheckedChange={() => onSelect(option.value)}
              />
              <span className="flex-1 min-w-0 text-sm text-[var(--sg-text)] truncate">
                {option.value}
              </span>
              <span className="text-xs text-[var(--sg-text-dim)] flex-shrink-0">
                {option.count}
              </span>
            </label>
          ))}

          {options.length > 5 && !showAll && (
            <button
              onClick={() => setShowAll(true)}
              className="text-xs text-[var(--sg-accent)] hover:text-[var(--sg-accent-hover)] transition-colors"
            >
              Show {options.length - 5} more
            </button>
          )}

          {showAll && (
            <button
              onClick={() => setShowAll(false)}
              className="text-xs text-[var(--sg-accent)] hover:text-[var(--sg-accent-hover)] transition-colors"
            >
              Show less
            </button>
          )}
        </div>
      )}
    </div>
  );
}

/**
 * Active filter chips display
 */
interface ActiveFiltersProps {
  filters: FacetFilters;
  onRemove: (facetKey: keyof FacetFilters, value: string) => void;
  onClearAll: () => void;
}

export function ActiveFilters({ filters, onRemove, onClearAll }: ActiveFiltersProps) {
  const allFilters: Array<{ facet: keyof FacetFilters; value: string }> = [];

  (Object.keys(filters) as Array<keyof FacetFilters>).forEach((facet) => {
    filters[facet].forEach((value) => {
      allFilters.push({ facet, value: String(value) });
    });
  });

  if (allFilters.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap gap-2 items-center">
      {allFilters.map(({ facet, value }) => (
        <Badge
          key={`${facet}-${value}`}
          variant="secondary"
          className="gap-1.5 pr-1"
        >
          <span className="text-xs">{value}</span>
          <button
            onClick={() => onRemove(facet, value)}
            className="hover:bg-[var(--sg-bg-0)] rounded p-0.5 transition-colors"
          >
            <X className="h-3 w-3" />
          </button>
        </Badge>
      ))}

      {allFilters.length > 1 && (
        <Button
          variant="ghost"
          size="sm"
          onClick={onClearAll}
          className="text-xs h-6"
        >
          Clear all
        </Button>
      )}
    </div>
  );
}

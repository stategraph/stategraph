"use client";

import { Instance } from '@/lib/api/client';
import { useState, useMemo } from 'react';
import {
  discoverTagFacets,
  discoverRegions,
  sortTagFacets,
  getProviderLabel,
} from '@/lib/instances';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { X, ChevronDown, ChevronRight } from 'lucide-react';
import { Checkbox } from '@/components/ui/checkbox';

/**
 * Dynamic filter state supporting tag-based filtering.
 * No hard-coded semantic assumptions about Environment or Location.
 */
export interface DynamicFacetFilters {
  // Resource facets
  providers: Set<string>;
  types: Set<string>;
  modules: Set<string>;

  // Dynamic tag filters: Map<tagKey, Set<tagValue>>
  tags: Map<string, Set<string>>;

  // Derived attribute filters
  regions: Set<string>;
}

interface DynamicFacetedFiltersProps {
  instances: Instance[];
  filters: DynamicFacetFilters;
  onFiltersChange: (filters: DynamicFacetFilters) => void;
}

interface FacetOption {
  value: string;
  count: number;
}

/**
 * Dynamic faceted filters with no hard-coded semantic fields.
 * Discovers tag keys and attribute fields from observed data only.
 */
export function DynamicFacetedFilters({
  instances,
  filters,
  onFiltersChange,
}: DynamicFacetedFiltersProps) {
  // Expanded sections state
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    new Set(['resource-providers', 'resource-types'])
  );

  // Discover facets from data
  const { tagFacets, providerOptions, typeOptions, moduleOptions, regionOptions } = useMemo(() => {
    // Tag facets
    const discoveredTagFacets = sortTagFacets(discoverTagFacets(instances));

    // Provider facets (with formatting)
    const providers = new Map<string, number>();
    instances.forEach((instance) => {
      const label = getProviderLabel(instance.provider);
      providers.set(label, (providers.get(label) || 0) + 1);
    });

    // Type facets
    const types = new Map<string, number>();
    instances.forEach((instance) => {
      types.set(instance.type, (types.get(instance.type) || 0) + 1);
    });

    // Module facets
    const modules = new Map<string, number>();
    instances.forEach((instance) => {
      if (instance.module) {
        modules.set(instance.module, (modules.get(instance.module) || 0) + 1);
      }
    });

    // Region facets
    const regions = discoverRegions(instances);

    const toOptions = (map: Map<string, number>): FacetOption[] =>
      Array.from(map.entries())
        .map(([value, count]) => ({ value, count }))
        .sort((a, b) => b.count - a.count);

    return {
      tagFacets: discoveredTagFacets,
      providerOptions: toOptions(providers),
      typeOptions: toOptions(types),
      moduleOptions: toOptions(modules),
      regionOptions: toOptions(regions),
    };
  }, [instances]);

  const toggleSection = (section: string) => {
    setExpandedSections((prev) => {
      const next = new Set(prev);
      if (next.has(section)) {
        next.delete(section);
      } else {
        next.add(section);
      }
      return next;
    });
  };

  const toggleResourceFilter = (
    facetKey: 'providers' | 'types' | 'modules' | 'regions',
    value: string
  ) => {
    const next = { ...filters };
    const set = new Set(next[facetKey]);
    if (set.has(value)) {
      set.delete(value);
    } else {
      set.add(value);
    }
    next[facetKey] = set;
    onFiltersChange(next);
  };

  const toggleTagFilter = (tagKey: string, tagValue: string) => {
    const next = { ...filters, tags: new Map(filters.tags) };

    if (!next.tags.has(tagKey)) {
      next.tags.set(tagKey, new Set([tagValue]));
    } else {
      const valueSet = new Set(next.tags.get(tagKey)!);
      if (valueSet.has(tagValue)) {
        valueSet.delete(tagValue);
        if (valueSet.size === 0) {
          next.tags.delete(tagKey);
        } else {
          next.tags.set(tagKey, valueSet);
        }
      } else {
        valueSet.add(tagValue);
        next.tags.set(tagKey, valueSet);
      }
    }

    onFiltersChange(next);
  };

  const clearAllFilters = () => {
    onFiltersChange({
      providers: new Set(),
      types: new Set(),
      modules: new Set(),
      tags: new Map(),
      regions: new Set(),
    });
  };

  const activeFilterCount =
    filters.providers.size +
    filters.types.size +
    filters.modules.size +
    filters.regions.size +
    Array.from(filters.tags.values()).reduce((sum, set) => sum + set.size, 0);

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          Facets
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

      <div className="space-y-3">
        {/* Tags Section */}
        {tagFacets.length > 0 && (
          <FacetGroup title="Tags">
            {tagFacets.map((tagFacet) => {
              const sectionId = `tag-${tagFacet.key}`;
              const selected = filters.tags.get(tagFacet.key) || new Set();
              const options: FacetOption[] = Array.from(tagFacet.values.entries())
                .map(([value, count]) => ({ value, count }))
                .sort((a, b) => b.count - a.count);

              return (
                <Facet
                  key={tagFacet.key}
                  title={tagFacet.key}
                  options={options}
                  selected={selected}
                  isExpanded={expandedSections.has(sectionId)}
                  onToggle={() => toggleSection(sectionId)}
                  onSelect={(value) => toggleTagFilter(tagFacet.key, value)}
                />
              );
            })}
          </FacetGroup>
        )}

        {/* Attributes Section */}
        {regionOptions.length > 0 && (
          <FacetGroup title="Attributes">
            <Facet
              title="Region"
              options={regionOptions}
              selected={filters.regions}
              isExpanded={expandedSections.has('attr-region')}
              onToggle={() => toggleSection('attr-region')}
              onSelect={(value) => toggleResourceFilter('regions', value)}
            />
          </FacetGroup>
        )}

        {/* Resource Section */}
        <FacetGroup title="Resource">
          <Facet
            title="Provider"
            options={providerOptions}
            selected={filters.providers}
            isExpanded={expandedSections.has('resource-providers')}
            onToggle={() => toggleSection('resource-providers')}
            onSelect={(value) => toggleResourceFilter('providers', value)}
          />

          <Facet
            title="Resource Type"
            options={typeOptions}
            selected={filters.types}
            isExpanded={expandedSections.has('resource-types')}
            onToggle={() => toggleSection('resource-types')}
            onSelect={(value) => toggleResourceFilter('types', value)}
          />

          {moduleOptions.length > 0 && (
            <Facet
              title="Module"
              options={moduleOptions}
              selected={filters.modules}
              isExpanded={expandedSections.has('resource-modules')}
              onToggle={() => toggleSection('resource-modules')}
              onSelect={(value) => toggleResourceFilter('modules', value)}
            />
          )}
        </FacetGroup>
      </div>
    </div>
  );
}

/**
 * Facet group container with a section header
 */
interface FacetGroupProps {
  title: string;
  children: React.ReactNode;
}

function FacetGroup({ title, children }: FacetGroupProps) {
  return (
    <div className="space-y-2">
      <div className="text-xs font-medium text-[var(--sg-text-dim)] uppercase tracking-wide px-1">
        {title}
      </div>
      <div className="space-y-2">
        {children}
      </div>
    </div>
  );
}

/**
 * Individual facet with collapsible values
 */
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
 * Active filter chips display (updated for dynamic tags)
 */
interface ActiveFiltersProps {
  filters: DynamicFacetFilters;
  onRemove: (category: string, key: string, value: string) => void;
  onClearAll: () => void;
}

export function DynamicActiveFilters({ filters, onRemove, onClearAll }: ActiveFiltersProps) {
  const allFilters: Array<{ category: string; key: string; value: string; display: string }> = [];

  // Resource filters
  filters.providers.forEach((value) => {
    allFilters.push({ category: 'resource', key: 'providers', value, display: value });
  });
  filters.types.forEach((value) => {
    allFilters.push({ category: 'resource', key: 'types', value, display: value });
  });
  filters.modules.forEach((value) => {
    allFilters.push({ category: 'resource', key: 'modules', value, display: value });
  });
  filters.regions.forEach((value) => {
    allFilters.push({ category: 'attribute', key: 'regions', value, display: `Region: ${value}` });
  });

  // Tag filters
  filters.tags.forEach((valueSet, tagKey) => {
    valueSet.forEach((tagValue) => {
      allFilters.push({
        category: 'tag',
        key: tagKey,
        value: tagValue,
        display: `${tagKey}: ${tagValue}`
      });
    });
  });

  if (allFilters.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap gap-2 items-center">
      {allFilters.map(({ category, key, value, display }) => (
        <Badge
          key={`${category}-${key}-${value}`}
          variant="secondary"
          className="gap-1.5 pr-1"
        >
          <span className="text-xs">{display}</span>
          <button
            onClick={() => onRemove(category, key, value)}
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

/**
 * Query Normalizer
 * Combines filter selections with free text and existing query state
 */

import { QueryObject } from './types';
import { parseQuery } from './parser';
import { compileQuery } from './compiler';

/**
 * Normalize a query string and filter selections into a single QueryObject
 */
export function normalizeQuery(
  queryString: string,
  providers?: string[],
  types?: string[],
  modules?: string[]
): QueryObject {
  // Parse existing query
  const parsed = parseQuery(queryString);

  // Override with explicit filter selections
  return {
    provider: providers && providers.length > 0 ? providers : parsed.provider,
    type: types && types.length > 0 ? types : parsed.type,
    module: modules && modules.length > 0 ? modules : parsed.module,
    free: parsed.free,
  };
}

/**
 * Apply filter selections to an existing query string
 */
export function applyFilters(
  queryString: string,
  filters: {
    providers?: string[];
    types?: string[];
    modules?: string[];
  }
): string {
  const parsed = parseQuery(queryString);

  const normalized = {
    provider: filters.providers || parsed.provider,
    type: filters.types || parsed.type,
    module: filters.modules || parsed.module,
    free: parsed.free,
  };

  return compileQuery(normalized);
}

/**
 * Extract filter values from a query string
 */
export function extractFilters(queryString: string): {
  providers: string[];
  types: string[];
  modules: string[];
} {
  const parsed = parseQuery(queryString);

  return {
    providers: parsed.provider || [],
    types: parsed.type || [],
    modules: parsed.module || [],
  };
}

/**
 * Update a single filter type in a query string
 */
export function updateFilter(
  queryString: string,
  filterType: 'provider' | 'type' | 'module',
  values: string[]
): string {
  const parsed = parseQuery(queryString);

  const updated = {
    ...parsed,
    [filterType]: values.length > 0 ? values : undefined,
  };

  return compileQuery(updated);
}

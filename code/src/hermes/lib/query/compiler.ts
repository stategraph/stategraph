/**
 * Query Compiler
 * Serializes QueryObject back into query strings
 */

import { QueryObject } from './types';

/**
 * Compile a QueryObject back into a query string
 *
 * @example
 * compileQuery({ provider: ["aws"], type: ["aws_s3_bucket"], free: ["hello"] })
 * // Returns: "provider:aws type:aws_s3_bucket hello"
 */
export function compileQuery(query: QueryObject): string {
  const parts: string[] = [];

  // Add provider filters
  if (query.provider && query.provider.length > 0) {
    query.provider.forEach((p) => {
      parts.push(`provider:${escapeValue(p)}`);
    });
  }

  // Add type filters
  if (query.type && query.type.length > 0) {
    query.type.forEach((t) => {
      parts.push(`type:${escapeValue(t)}`);
    });
  }

  // Add module filters
  if (query.module && query.module.length > 0) {
    query.module.forEach((m) => {
      parts.push(`module:${escapeValue(m)}`);
    });
  }

  // Add free text tokens
  if (query.free && query.free.length > 0) {
    query.free.forEach((f) => {
      parts.push(escapeValue(f));
    });
  }

  return parts.join(' ');
}

/**
 * Escape a value if it contains spaces or special characters
 */
function escapeValue(value: string): string {
  if (value.includes(' ') || value.includes(':')) {
    return `"${value}"`;
  }
  return value;
}

/**
 * Merge two query objects, with the second overriding the first
 */
export function mergeQueries(base: QueryObject, override: QueryObject): QueryObject {
  return {
    provider: override.provider || base.provider,
    type: override.type || base.type,
    module: override.module || base.module,
    free: override.free || base.free,
  };
}

/**
 * Remove a specific filter from a query object
 */
export function removeFilter(
  query: QueryObject,
  key: keyof QueryObject,
  value: string
): QueryObject {
  const result = { ...query };

  if (result[key]) {
    result[key] = result[key]!.filter((v) => v !== value);
    if (result[key]!.length === 0) {
      delete result[key];
    }
  }

  return result;
}

/**
 * Add a filter to a query object
 */
export function addFilter(
  query: QueryObject,
  key: keyof QueryObject,
  value: string
): QueryObject {
  const result = { ...query };

  if (!result[key]) {
    result[key] = [];
  }

  // Avoid duplicates
  if (!result[key]!.includes(value)) {
    result[key]!.push(value);
  }

  return result;
}

/**
 * Clear all filters of a specific type
 */
export function clearFilterType(query: QueryObject, key: keyof QueryObject): QueryObject {
  const result = { ...query };
  delete result[key];
  return result;
}

/**
 * Clear all filters from a query
 */
export function clearAllFilters(_query: QueryObject): QueryObject {
  return {};
}

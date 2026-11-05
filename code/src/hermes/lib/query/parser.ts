/**
 * Query Parser
 * Parses query strings into structured QueryObject format
 */

import { QueryObject } from './types';

/**
 * Parse a query string into a QueryObject
 *
 * @example
 * parseQuery("provider:aws type:aws_s3_bucket hello world")
 * // Returns: { provider: ["aws"], type: ["aws_s3_bucket"], free: ["hello", "world"] }
 */
export function parseQuery(q: string): QueryObject {
  if (!q || typeof q !== 'string') {
    return {};
  }

  const result: QueryObject = {};
  const tokens = tokenize(q);

  for (const token of tokens) {
    if (token.includes(':')) {
      const [key, value] = token.split(':', 2);
      const trimmedKey = key.trim().toLowerCase();
      const trimmedValue = value.trim();

      // Only process known keys
      if (['provider', 'type', 'module'].includes(trimmedKey) && trimmedValue) {
        if (!result[trimmedKey as keyof QueryObject]) {
          result[trimmedKey as keyof QueryObject] = [];
        }
        result[trimmedKey as keyof QueryObject]!.push(trimmedValue);
      }
    } else {
      // Free text token
      const trimmed = token.trim();
      if (trimmed) {
        if (!result.free) {
          result.free = [];
        }
        result.free.push(trimmed);
      }
    }
  }

  return result;
}

/**
 * Tokenize a query string, respecting quotes
 */
function tokenize(q: string): string[] {
  const tokens: string[] = [];
  let current = '';
  let inQuotes = false;
  let quoteChar = '';

  for (let i = 0; i < q.length; i++) {
    const char = q[i];

    if ((char === '"' || char === "'") && !inQuotes) {
      // Start quote
      inQuotes = true;
      quoteChar = char;
    } else if (char === quoteChar && inQuotes) {
      // End quote
      inQuotes = false;
      quoteChar = '';
    } else if (char === ' ' && !inQuotes) {
      // Space outside quotes - end token
      if (current.trim()) {
        tokens.push(current.trim());
      }
      current = '';
    } else {
      current += char;
    }
  }

  // Add final token
  if (current.trim()) {
    tokens.push(current.trim());
  }

  return tokens;
}

/**
 * Check if a query string is empty or only whitespace
 */
export function isEmptyQuery(q: string): boolean {
  return !q || q.trim().length === 0;
}

/**
 * Get all values for a specific key from a query object
 */
export function getQueryValues(query: QueryObject, key: keyof QueryObject): string[] {
  return query[key] || [];
}

/**
 * Check if a query object has any filters
 */
export function hasFilters(query: QueryObject): boolean {
  return Boolean(
    (query.provider && query.provider.length > 0) ||
    (query.type && query.type.length > 0) ||
    (query.module && query.module.length > 0) ||
    (query.free && query.free.length > 0)
  );
}

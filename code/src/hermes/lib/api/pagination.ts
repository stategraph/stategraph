/**
 * Pagination Utilities
 *
 * Utilities for parsing HTTP Link headers (RFC 5988) used by the Stategraph API
 * for cursor-based pagination.
 */

export interface ParsedLinks {
  next?: string[];
  prev?: string[];
}

/**
 * Parse an HTTP Link header to extract pagination cursors.
 *
 * Example Link header:
 *   Link: <http://api/path?page=n%3Aaddress1>, rel="next"; <http://api/path?page=p%3Aaddress2>, rel="prev"
 *
 * Returns:
 *   { next: ['address1'], prev: ['address2'] }
 *
 * @param linkHeader - The Link header value from the HTTP response
 * @returns Object with next/prev cursor arrays, or empty object if no links
 */
export function parseLinkHeader(linkHeader: string | null): ParsedLinks {
  if (!linkHeader) {
    return {};
  }

  const links: ParsedLinks = {};

  // Split by comma to get individual link entries
  const linkEntries = linkHeader.split(',');

  for (const entry of linkEntries) {
    // Parse: <URL>, rel="next"
    const match = entry.match(/<([^>]+)>;\s*rel="([^"]+)"/);
    if (!match) continue;

    const [, url, rel] = match;

    // Only care about next and prev rels
    if (rel !== 'next' && rel !== 'prev') continue;

    // Extract page query parameter
    const pageParams = extractPageParams(url);
    if (pageParams.length > 0) {
      links[rel as 'next' | 'prev'] = pageParams;
    }
  }

  return links;
}

/**
 * Extract and decode the page parameter from a URL.
 *
 * The page parameter can appear multiple times:
 *   ?page=value1&page=value2
 *
 * Each value may be URL-encoded and prefixed with direction:
 *   n:address (next)
 *   p:address (prev)
 *
 * @param url - The URL to parse
 * @returns Array of decoded page cursor values (without n:/p: prefixes)
 */
function extractPageParams(url: string): string[] {
  try {
    const urlObj = new URL(url);
    const pageParams = urlObj.searchParams.getAll('page');

    // Decode and strip direction prefix (n: or p:)
    return pageParams.map((param) => {
      const decoded = decodeURIComponent(param);
      // Remove n: or p: prefix if present
      return decoded.replace(/^[np]:/, '');
    });
  } catch (error) {
    console.warn('[parseLinkHeader] Failed to parse URL:', url, error);
    return [];
  }
}

/**
 * Check if pagination metadata indicates more pages exist.
 *
 * @param links - Parsed link header
 * @returns true if a next page cursor exists
 */
export function hasNextPage(links: ParsedLinks): boolean {
  return Boolean(links.next && links.next.length > 0);
}

/**
 * Check if pagination metadata indicates previous pages exist.
 *
 * @param links - Parsed link header
 * @returns true if a prev page cursor exists
 */
export function hasPrevPage(links: ParsedLinks): boolean {
  return Boolean(links.prev && links.prev.length > 0);
}

/**
 * Query utilities for converting search terms to backend-compatible tag queries
 */

/**
 * Detects if a query string already contains tag syntax (tag:value)
 */
export function hasTagSyntax(query: string): boolean {
  const trimmed = query.trim();
  if (!trimmed) return false;

  // Check if query contains tag prefix patterns or boolean operators
  // Tag prefixes: address:, resource_address:, module:, provider:, type:, attr:, tag:
  return /^(address|resource_address|module|provider|type|attr|tag):/.test(trimmed) ||
         trimmed.includes(':') ||
         trimmed.includes(' AND ') ||
         trimmed.includes(' OR ') ||
         trimmed.includes(' NOT ');
}

/**
 * Converts a bare search term into a backend-compatible tag query.
 *
 * The backend requires explicit tag prefixes (like "type:value").
 * When users enter bare search terms, we search across multiple fields
 * using an OR query to maximize chances of finding matches.
 *
 * Enhanced to support searching by:
 * - Terraform addresses
 * - Resource types
 * - Providers
 * - Modules
 * - Instance tags (via attr:tags.Name, attr:tags.Environment, etc.)
 * - Generic name attributes
 *
 * @param searchTerm - The raw search term from user input
 * @returns A tag query string that searches across multiple fields
 *
 * @example
 * ensureTagQuery("ecs_cluster")
 * // Returns: "address:ecs_cluster OR type:ecs_cluster OR provider:ecs_cluster OR module:ecs_cluster OR attr:name:ecs_cluster OR attr:tags.Name:ecs_cluster"
 *
 * @example
 * ensureTagQuery("type:aws_instance")
 * // Returns: "type:aws_instance" (unchanged - already has tag syntax)
 *
 * @example
 * ensureTagQuery("tag:Environment:production")
 * // Returns: "attr:tags.Environment:production"
 *
 * @example
 * ensureTagQuery("type:aws_instance OR type:aws_s3_bucket")
 * // Returns: "type:aws_instance OR type:aws_s3_bucket" (unchanged)
 */
export function ensureTagQuery(searchTerm: string): string {
  const trimmed = searchTerm.trim();

  if (!trimmed) {
    return '';
  }

  // If it already has tag syntax, check for tag: shorthand and convert
  if (hasTagSyntax(trimmed)) {
    // Convert tag:Key:Value shorthand to attr:tags.Key:Value
    return trimmed.replace(/\btag:([^:]+):([^\s]+)/g, 'attr:tags.$1:$2');
  }

  // For bare search terms, search across all relevant fields
  // This allows matching whether they're searching for a type, address, provider, module, name, or tag
  const fields = [
    'address',           // Terraform address
    'type',              // Resource type
    'provider',          // Provider name
    'module',            // Module path
    'attr:name',         // Generic name attribute
    'attr:tags.Name',    // AWS Name tag (most common)
    'attr:tags.Environment',  // Environment tag
    'attr:tags.Project',      // Project tag
    'attr:bucket',       // S3 bucket name
    'attr:db_instance_identifier',  // RDS identifier
  ];

  return fields.map(field => `${field}:${trimmed}`).join(' OR ');
}

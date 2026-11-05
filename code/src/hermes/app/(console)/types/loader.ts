/**
 * Resource Types Page Data Loader
 *
 * Per-resource-type instance counts, served by ONE server-side MQL query
 * (`resourceTypesQuery`) for either a single state or all live states. The
 * previous implementation fetched `/resources/summary` per state and merged
 * the results client-side, silently dropping any state whose fetch failed.
 */

import { executeMQL } from '@/lib/api/client';
import { resourceTypesQuery, MAX_TYPES, type ResourceTypeRow } from './mqlQueries';

// ============================================================================
// TYPES
// ============================================================================

export interface ResourceTypeData {
  type: string;
  instances: number;
  provider: string;
}

export interface ResourceTypesData {
  types: ResourceTypeData[];
  totalTypes: number;
  totalInstances: number;
}

// ============================================================================
// DATA LOADERS
// ============================================================================

/**
 * Load resource types summed across all live states via a single MQL query.
 */
export async function loadAllResourceTypes(): Promise<ResourceTypesData> {
  return runResourceTypesQuery(resourceTypesQuery());
}

/**
 * Load all resource types from a specific state via a single MQL query.
 *
 * @param stateId - The state ID to load resource types from
 * @returns Resource types data with aggregated counts
 */
export async function loadResourceTypes(stateId: string): Promise<ResourceTypesData> {
  return runResourceTypesQuery(resourceTypesQuery(stateId));
}

/**
 * Execute a resource-types MQL query and shape the rows into
 * `ResourceTypesData`. The query carries an explicit `limit ${MAX_TYPES}`, so
 * a non-null `defaultLimitApplied` should never happen; we still warn if it
 * does, since that would mean the counts are an undercount.
 */
async function runResourceTypesQuery(query: string): Promise<ResourceTypesData> {
  const result = await executeMQL(query);

  if (result.defaultLimitApplied !== null) {
    console.warn(
      `[loadResourceTypes] Unexpected default limit (${result.defaultLimitApplied}) applied; counts may be truncated.`
    );
  }

  const rows = result.data as ResourceTypeRow[];

  const types: ResourceTypeData[] = rows.map((row) => ({
    type: String(row.type),
    instances: Number(row.instances ?? 0),
    provider: extractProvider(String(row.type)),
  }));

  // The query already orders by count desc, then type; the map above preserves
  // that order.
  const totalTypes = types.length;
  const totalInstances = types.reduce((sum, t) => sum + t.instances, 0);

  if (totalTypes === MAX_TYPES) {
    console.warn(
      `[loadResourceTypes] Hit MAX_TYPES (${MAX_TYPES}); some resource types may be omitted.`
    );
  }

  return { types, totalTypes, totalInstances };
}

/**
 * Extract provider from resource type name
 * e.g., "aws_s3_bucket" -> "aws"
 */
function extractProvider(type: string): string {
  const parts = type.split('_');
  return parts[0] || 'unknown';
}

/**
 * Get provider display name
 */
export function getProviderDisplay(provider: string): string {
  const providerMap: Record<string, string> = {
    'aws': 'AWS',
    'google': 'GCP',
    'azurerm': 'Azure',
    'kubernetes': 'K8s',
    'datadog': 'Datadog',
    'github': 'GitHub',
    'gitlab': 'GitLab',
    'cloudflare': 'Cloudflare',
    'helm': 'Helm',
    'terraform': 'Terraform',
  };

  return providerMap[provider.toLowerCase()] || provider.toUpperCase();
}

/**
 * Filter resource types client-side
 */
export function filterResourceTypes(
  types: ResourceTypeData[],
  searchQuery: string,
  minInstances?: number
): ResourceTypeData[] {
  if (!searchQuery && !minInstances) {
    return types;
  }

  const query = searchQuery.toLowerCase();

  return types.filter((type) => {
    // Filter by minimum instances
    if (minInstances && type.instances < minInstances) {
      return false;
    }

    // Filter by search query (matches type name or provider)
    if (query) {
      const matchesType = type.type.toLowerCase().includes(query);
      const matchesProvider = type.provider.toLowerCase().includes(query);
      return matchesType || matchesProvider;
    }

    return true;
  });
}

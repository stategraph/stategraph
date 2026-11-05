// Dynamic facet discovery for inventory filtering
// Extracts all observable tag keys, attribute fields, and resource properties

import { Instance } from '@/lib/api/client';
import { getInstanceTags } from './tags';
import { getLocation } from './metadata';

/**
 * Discovered tag key with value counts
 */
export interface TagFacet {
  key: string;
  values: Map<string, number>; // value -> count
  totalInstances: number;
}

/**
 * Discover all unique tag keys and their values from instances.
 * Only includes tags that actually exist in the data.
 */
export function discoverTagFacets(instances: Instance[]): TagFacet[] {
  const tagKeyMap = new Map<string, Map<string, number>>();

  instances.forEach((instance) => {
    const tags = getInstanceTags(instance);

    tags.forEach(({ key, value }) => {
      if (!tagKeyMap.has(key)) {
        tagKeyMap.set(key, new Map<string, number>());
      }

      const valueMap = tagKeyMap.get(key)!;
      valueMap.set(value, (valueMap.get(value) || 0) + 1);
    });
  });

  // Convert to TagFacet array
  const facets: TagFacet[] = [];
  for (const [key, valueMap] of tagKeyMap.entries()) {
    const totalInstances = Array.from(valueMap.values()).reduce((sum, count) => sum + count, 0);
    facets.push({
      key,
      values: valueMap,
      totalInstances,
    });
  }

  // Sort by total instances descending (most common tags first)
  return facets.sort((a, b) => b.totalInstances - a.totalInstances);
}

/**
 * Discover all unique regions from instances.
 * Only includes regions that can be confidently determined.
 */
export function discoverRegions(instances: Instance[]): Map<string, number> {
  const regionMap = new Map<string, number>();

  instances.forEach((instance) => {
    const region = getLocation(instance);
    if (region) {
      regionMap.set(region, (regionMap.get(region) || 0) + 1);
    }
  });

  return regionMap;
}

/**
 * Get tag value for a specific key from an instance.
 * Returns undefined if tag doesn't exist.
 */
export function getTagValue(instance: Instance, tagKey: string): string | undefined {
  if (!instance.attributes?.tags) {
    return undefined;
  }

  const value = instance.attributes.tags[tagKey];
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

/**
 * Priority order for tag facets in the sidebar.
 * Tags not in this list will appear alphabetically after priority tags.
 */
export const PRIORITY_TAG_FACETS = [
  'Environment',
  'Env',
  'Service',
  'Owner',
  'Team',
  'Project',
  'Application',
  'App',
];

/**
 * Sort tag facets by priority, then alphabetically.
 */
export function sortTagFacets(facets: TagFacet[]): TagFacet[] {
  return facets.sort((a, b) => {
    const aPriority = PRIORITY_TAG_FACETS.indexOf(a.key);
    const bPriority = PRIORITY_TAG_FACETS.indexOf(b.key);

    // Both have priority: sort by priority order
    if (aPriority !== -1 && bPriority !== -1) {
      return aPriority - bPriority;
    }

    // Only a has priority
    if (aPriority !== -1) return -1;

    // Only b has priority
    if (bPriority !== -1) return 1;

    // Neither has priority: alphabetical
    return a.key.localeCompare(b.key);
  });
}

// Tag extraction and prioritization for instances
// Handles safe extraction and ranking of tags from instance attributes

import { Instance } from '@/lib/api/client';

/**
 * Common high-value tags that should be prioritized in the UI.
 * Order matters: tags earlier in the list are shown first.
 */
export const PRIORITY_TAG_KEYS = [
  'Name',
  'Environment',
  'Env',
  'Project',
  'Application',
  'App',
  'Service',
  'Owner',
  'Team',
  'CostCenter',
  'Cost Center',
  'ManagedBy',
  'Managed By',
];

/**
 * Tag entry for rendering.
 */
export interface Tag {
  key: string;
  value: string;
  isPriority: boolean;
}

/**
 * Extract tags from instance attributes.
 * Returns an empty array if tags are missing or invalid.
 */
export function getInstanceTags(instance: Instance): Tag[] {
  if (!instance.attributes?.tags) {
    return [];
  }

  const tags = instance.attributes.tags;

  // Ensure tags is an object
  if (typeof tags !== 'object' || tags === null || Array.isArray(tags)) {
    return [];
  }

  // Convert to Tag array
  const tagEntries: Tag[] = [];
  for (const [key, value] of Object.entries(tags)) {
    // Only include string values
    if (typeof value === 'string' && value.trim()) {
      const isPriority = PRIORITY_TAG_KEYS.includes(key);
      tagEntries.push({ key, value: value.trim(), isPriority });
    }
  }

  return tagEntries;
}

/**
 * Get tags sorted by priority (priority tags first, then alphabetical).
 */
export function getSortedTags(instance: Instance): Tag[] {
  const tags = getInstanceTags(instance);

  return tags.sort((a, b) => {
    // Priority tags come first
    if (a.isPriority && !b.isPriority) return -1;
    if (!a.isPriority && b.isPriority) return 1;

    // Within priority/non-priority groups, maintain the order from PRIORITY_TAG_KEYS
    // or sort alphabetically
    if (a.isPriority && b.isPriority) {
      const aIndex = PRIORITY_TAG_KEYS.indexOf(a.key);
      const bIndex = PRIORITY_TAG_KEYS.indexOf(b.key);
      return aIndex - bIndex;
    }

    // Non-priority tags: alphabetical
    return a.key.localeCompare(b.key);
  });
}

/**
 * Get only priority tags (useful for compact display).
 */
export function getPriorityTags(instance: Instance): Tag[] {
  return getSortedTags(instance).filter(tag => tag.isPriority);
}

/**
 * Check if instance has any tags.
 */
export function hasTags(instance: Instance): boolean {
  return getInstanceTags(instance).length > 0;
}

/**
 * Search helper: Get all tag key-value pairs as searchable strings.
 * Returns ["key:value", ...] format for easy matching.
 */
export function getTagSearchStrings(instance: Instance): string[] {
  const tags = getInstanceTags(instance);
  return tags.map(tag => `${tag.key}:${tag.value}`);
}

// Client-side search utilities for instances
// Used for local filtering and matching against derived display names

import { Instance } from '@/lib/api/client';
import { getInstanceDisplayName } from './displayName';
import { getInstanceTags, getTagSearchStrings } from './tags';

/**
 * Check if an instance matches a search term.
 * Searches across:
 * - Display name (derived)
 * - Terraform address
 * - Resource type
 * - Provider
 * - Module
 * - Tag keys and values
 *
 * @param instance - The instance to check
 * @param searchTerm - The search term (case-insensitive)
 * @returns true if the instance matches the search term
 */
export function instanceMatchesSearch(instance: Instance, searchTerm: string): boolean {
  if (!searchTerm || !searchTerm.trim()) {
    return true; // Empty search matches everything
  }

  const term = searchTerm.toLowerCase().trim();

  // 1. Display name
  const displayName = getInstanceDisplayName(instance);
  if (displayName.toLowerCase().includes(term)) {
    return true;
  }

  // 2. Terraform address
  if (instance.address.toLowerCase().includes(term)) {
    return true;
  }

  // 3. Resource type
  if (instance.type.toLowerCase().includes(term)) {
    return true;
  }

  // 4. Provider
  if (instance.provider.toLowerCase().includes(term)) {
    return true;
  }

  // 5. Module
  if (instance.module && instance.module.toLowerCase().includes(term)) {
    return true;
  }

  // 6. Tags (key and value)
  const tags = getInstanceTags(instance);
  for (const tag of tags) {
    if (tag.key.toLowerCase().includes(term) || tag.value.toLowerCase().includes(term)) {
      return true;
    }
  }

  // 7. Tag search strings (key:value format)
  const tagSearchStrings = getTagSearchStrings(instance);
  for (const tagStr of tagSearchStrings) {
    if (tagStr.toLowerCase().includes(term)) {
      return true;
    }
  }

  return false;
}

/**
 * Filter a list of instances by a search term.
 *
 * @param instances - The instances to filter
 * @param searchTerm - The search term
 * @returns Filtered instances that match the search term
 */
export function filterInstances(instances: Instance[], searchTerm: string): Instance[] {
  if (!searchTerm || !searchTerm.trim()) {
    return instances;
  }

  return instances.filter(instance => instanceMatchesSearch(instance, searchTerm));
}

/**
 * Sort instances by relevance to a search term.
 * More specific matches (display name, exact match) rank higher.
 *
 * @param instances - The instances to sort
 * @param searchTerm - The search term
 * @returns Sorted instances with most relevant first
 */
export function sortByRelevance(instances: Instance[], searchTerm: string): Instance[] {
  if (!searchTerm || !searchTerm.trim()) {
    return instances;
  }

  const term = searchTerm.toLowerCase().trim();

  return [...instances].sort((a, b) => {
    const scoreA = getRelevanceScore(a, term);
    const scoreB = getRelevanceScore(b, term);
    return scoreB - scoreA; // Higher score first
  });
}

/**
 * Calculate relevance score for an instance based on search term.
 * Higher scores indicate better matches.
 */
function getRelevanceScore(instance: Instance, term: string): number {
  let score = 0;

  const displayName = getInstanceDisplayName(instance).toLowerCase();

  // Exact match: highest score
  if (displayName === term) {
    score += 100;
  }

  // Display name starts with term: high score
  if (displayName.startsWith(term)) {
    score += 50;
  }

  // Display name contains term: medium score
  if (displayName.includes(term)) {
    score += 25;
  }

  // Address exact match
  if (instance.address.toLowerCase() === term) {
    score += 80;
  }

  // Address contains term
  if (instance.address.toLowerCase().includes(term)) {
    score += 15;
  }

  // Type exact match
  if (instance.type.toLowerCase() === term) {
    score += 40;
  }

  // Type contains term
  if (instance.type.toLowerCase().includes(term)) {
    score += 10;
  }

  // Priority tag match
  const tags = getInstanceTags(instance);
  for (const tag of tags) {
    if (tag.isPriority) {
      if (tag.value.toLowerCase() === term) {
        score += 30;
      } else if (tag.value.toLowerCase().includes(term)) {
        score += 10;
      }
    } else {
      if (tag.value.toLowerCase() === term) {
        score += 15;
      } else if (tag.value.toLowerCase().includes(term)) {
        score += 5;
      }
    }
  }

  return score;
}

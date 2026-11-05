// High-signal attribute extraction for resource inspection
// Identifies the most useful attributes to show first in the detail drawer

import { Instance } from '@/lib/api/client';

export interface HighSignalAttribute {
  key: string;
  label: string;
  value: string;
  mono?: boolean;
}

/**
 * High-signal attribute keys across providers.
 * Only includes attributes that help answer "What infrastructure do I have?"
 * Excludes internal IDs, provider-specific identifiers, and low-signal fields.
 */
const HIGH_SIGNAL_KEYS = [
  'name',
  'bucket',
  'function_name',
  'instance_type',
  'instance_class',
  'engine',
  'engine_version',
  'status',
  'state',
  'enabled',
  'public',
  'publicly_accessible',
  'encryption',
  'encrypted',
  'multi_az',
  'storage_type',
  'allocated_storage',
  'backup_retention_period',
  'deletion_protection',
];

/**
 * Extract high-signal attributes from instance attributes.
 * Returns a curated list of key-value pairs for the most useful fields.
 *
 * @param instance - The instance to extract attributes from
 * @param maxAttributes - Maximum number of attributes to return (default: 8)
 * @returns Array of high-signal attributes
 */
export function getHighSignalAttributes(
  instance: Instance,
  maxAttributes: number = 8
): HighSignalAttribute[] {
  if (!instance.attributes) {
    return [];
  }

  const result: HighSignalAttribute[] = [];
  const attrs = instance.attributes;

  // Check each high-signal key in priority order
  for (const key of HIGH_SIGNAL_KEYS) {
    if (result.length >= maxAttributes) {
      break;
    }

    const value = attrs[key];
    if (value !== undefined && value !== null) {
      result.push({
        key,
        label: formatAttributeLabel(key),
        value: formatAttributeValue(value),
        mono: shouldUseMonospace(key),
      });
    }
  }

  return result;
}

/**
 * Format an attribute value for display.
 * Handles strings, numbers, booleans, and simple structures.
 */
function formatAttributeValue(value: unknown): string {
  if (value === null || value === undefined) {
    return '—';
  }

  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }

  if (typeof value === 'string') {
    return value;
  }

  if (typeof value === 'number') {
    return String(value);
  }

  // For complex types, stringify
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    if (value.length <= 3 && value.every(v => typeof v === 'string')) {
      return value.join(', ');
    }
    return `Array(${value.length})`;
  }

  if (typeof value === 'object') {
    return `Object(${Object.keys(value).length} keys)`;
  }

  return String(value);
}

/**
 * Determine if an attribute key should be displayed in monospace font.
 */
function shouldUseMonospace(key: string): boolean {
  const monoKeys = [
    'bucket',
    'function_name',
  ];

  return monoKeys.includes(key);
}

/**
 * Format attribute key as human-readable label.
 * Converts snake_case to Title Case.
 */
function formatAttributeLabel(key: string): string {
  // Special cases for common abbreviations
  const specialCases: Record<string, string> = {
    'multi_az': 'Multi-AZ',
    'kms_key_id': 'KMS Key',
    'vpc_id': 'VPC',
    'db_instance_identifier': 'Database Instance',
  };

  if (specialCases[key]) {
    return specialCases[key];
  }

  // Convert snake_case to Title Case
  return key
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Get a formatted provider display name.
 * Extracts "hashicorp/aws" from "provider["registry.terraform.io/hashicorp/aws"]"
 */
export function getProviderLabel(provider: string): string {
  // Remove provider["..."] wrapper if present
  let cleaned = provider;
  const providerMatch = provider.match(/provider\["(.+?)"\]/);
  if (providerMatch) {
    cleaned = providerMatch[1];
  }

  // Extract part after first slash (e.g., "registry.terraform.io/hashicorp/aws" → "hashicorp/aws")
  const firstSlashIndex = cleaned.indexOf('/');
  if (firstSlashIndex !== -1) {
    cleaned = cleaned.substring(firstSlashIndex + 1);
  }

  return cleaned;
}

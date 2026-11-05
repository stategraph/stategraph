// Column configuration system for dynamic table views
// Supports core fields, tag-based columns, and derived attributes

import { Instance } from '@/lib/api/client';
import { getTagValue, getLocation, getProviderLabel } from './index';

/**
 * Column types supported in the inventory table
 */
export type ColumnType = 'core' | 'tag' | 'attribute';

/**
 * Column definition
 */
export interface ColumnDefinition {
  id: string;
  label: string;
  type: ColumnType;
  width?: string; // Tailwind width class (e.g., 'w-32')
  isDefault?: boolean; // Included in default view
  getValue: (instance: Instance) => string | undefined;
  format?: 'text' | 'badge' | 'mono' | 'code';
}

/**
 * Default core columns (always available)
 */
export const CORE_COLUMNS: Record<string, ColumnDefinition> = {
  resource: {
    id: 'resource',
    label: 'Resource',
    type: 'core',
    isDefault: true,
    getValue: (instance) => instance.address,
    format: 'text',
  },
  type: {
    id: 'type',
    label: 'Resource Type',
    type: 'core',
    width: 'w-48',
    isDefault: true,
    getValue: (instance) => instance.type,
    format: 'mono',
  },
  provider: {
    id: 'provider',
    label: 'Provider',
    type: 'core',
    width: 'w-32',
    isDefault: true,
    getValue: (instance) => getProviderLabel(instance.provider),
    format: 'text',
  },
  module: {
    id: 'module',
    label: 'Module',
    type: 'core',
    width: 'w-64',
    isDefault: false,
    getValue: (instance) => instance.module,
    format: 'mono',
  },
  state_name: {
    id: 'state_name',
    label: 'State',
    type: 'core',
    width: 'w-40',
    isDefault: false, // Conditionally shown based on searchScope
    getValue: (instance) => instance.state_name,
    format: 'text',
  },
};

/**
 * Derived attribute columns (computed from instance data)
 */
export const ATTRIBUTE_COLUMNS: Record<string, ColumnDefinition> = {
  region: {
    id: 'region',
    label: 'Region',
    type: 'attribute',
    width: 'w-32',
    isDefault: false,
    getValue: (instance) => getLocation(instance),
    format: 'text',
  },
};

/**
 * Create a tag-based column definition
 */
export function createTagColumn(tagKey: string): ColumnDefinition {
  return {
    id: `tag:${tagKey}`,
    label: tagKey,
    type: 'tag',
    width: 'w-32',
    isDefault: false,
    getValue: (instance) => getTagValue(instance, tagKey),
    format: 'badge',
  };
}

/**
 * Column configuration for a table view
 */
export interface ColumnConfig {
  visibleColumns: string[]; // Column IDs in display order
  tagColumns: string[]; // Tag keys to show as columns
}

/**
 * Default column configuration
 */
export const DEFAULT_COLUMN_CONFIG: ColumnConfig = {
  visibleColumns: ['resource', 'type', 'provider'],
  tagColumns: [],
};

/**
 * Get all available columns for picker
 */
export function getAvailableColumns(instances: Instance[]): {
  core: ColumnDefinition[];
  attributes: ColumnDefinition[];
  tags: ColumnDefinition[];
} {
  // Core columns
  const core = Object.values(CORE_COLUMNS);

  // Attribute columns
  const attributes = Object.values(ATTRIBUTE_COLUMNS);

  // Discover tag columns from data
  const tagKeys = new Set<string>();
  instances.forEach((instance) => {
    if (instance.attributes?.tags) {
      Object.keys(instance.attributes.tags).forEach((key) => {
        tagKeys.add(key);
      });
    }
  });

  const tags = Array.from(tagKeys)
    .sort()
    .map((tagKey) => createTagColumn(tagKey));

  return { core, attributes, tags };
}

/**
 * Resolve column definitions from config
 */
export function resolveColumns(
  config: ColumnConfig,
  _instances: Instance[]
): ColumnDefinition[] {
  const columns: ColumnDefinition[] = [];

  config.visibleColumns.forEach((columnId) => {
    // Core columns
    if (CORE_COLUMNS[columnId]) {
      columns.push(CORE_COLUMNS[columnId]);
      return;
    }

    // Attribute columns
    if (ATTRIBUTE_COLUMNS[columnId]) {
      columns.push(ATTRIBUTE_COLUMNS[columnId]);
      return;
    }

    // Tag columns
    if (columnId.startsWith('tag:')) {
      const tagKey = columnId.replace('tag:', '');
      columns.push(createTagColumn(tagKey));
    }
  });

  return columns;
}

/**
 * LocalStorage key for column config
 */
export const COLUMN_CONFIG_STORAGE_KEY = 'stategraph-inventory-columns';

/**
 * Load column config from localStorage
 */
export function loadColumnConfig(): ColumnConfig {
  try {
    const stored = localStorage.getItem(COLUMN_CONFIG_STORAGE_KEY);
    if (stored) {
      return JSON.parse(stored);
    }
  } catch (error) {
    console.error('[ColumnConfig] Failed to load from localStorage:', error);
  }
  return DEFAULT_COLUMN_CONFIG;
}

/**
 * Save column config to localStorage
 */
export function saveColumnConfig(config: ColumnConfig): void {
  try {
    localStorage.setItem(COLUMN_CONFIG_STORAGE_KEY, JSON.stringify(config));
  } catch (error) {
    console.error('[ColumnConfig] Failed to save to localStorage:', error);
  }
}

/**
 * Reset to default column config
 */
export function resetColumnConfig(): ColumnConfig {
  try {
    localStorage.removeItem(COLUMN_CONFIG_STORAGE_KEY);
  } catch (error) {
    console.error('[ColumnConfig] Failed to reset localStorage:', error);
  }
  return DEFAULT_COLUMN_CONFIG;
}

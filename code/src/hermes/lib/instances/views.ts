// View configuration system for preset table layouts
// Supports default views and custom user-created views

import { ColumnConfig, DEFAULT_COLUMN_CONFIG } from './columns';

/**
 * View definition
 * A view is a saved configuration of columns and display settings
 */
export interface View {
  id: string;
  name: string;
  description: string;
  isDefault: boolean; // Default views cannot be deleted or renamed
  columnConfig: ColumnConfig;
  createdAt?: string; // ISO timestamp for custom views
}

/**
 * Default views available to all users
 */
export const DEFAULT_VIEWS: View[] = [
  {
    id: 'all',
    name: 'All Resources',
    description: 'Standard view with essential columns',
    isDefault: true,
    columnConfig: DEFAULT_COLUMN_CONFIG,
  },
  {
    id: 'by-environment',
    name: 'By Environment',
    description: 'Optimized for environment-based workflows',
    isDefault: true,
    columnConfig: {
      visibleColumns: ['resource', 'type', 'tag:Environment', 'provider'],
      tagColumns: ['Environment'],
    },
  },
  {
    id: 'by-service',
    name: 'By Service',
    description: 'Optimized for service-based workflows',
    isDefault: true,
    columnConfig: {
      visibleColumns: ['resource', 'type', 'tag:Service', 'tag:Owner'],
      tagColumns: ['Service', 'Owner'],
    },
  },
  {
    id: 'by-provider',
    name: 'By Provider',
    description: 'Optimized for cloud provider workflows',
    isDefault: true,
    columnConfig: {
      visibleColumns: ['resource', 'type', 'provider', 'region'],
      tagColumns: [],
    },
  },
  {
    id: 'detailed',
    name: 'Detailed',
    description: 'All available columns for deep inspection',
    isDefault: true,
    columnConfig: {
      visibleColumns: ['resource', 'type', 'provider', 'module', 'region'],
      tagColumns: [],
    },
  },
];

/**
 * Get view by ID from default views
 */
export function getDefaultView(viewId: string): View | undefined {
  return DEFAULT_VIEWS.find((v) => v.id === viewId);
}

/**
 * LocalStorage key for custom views
 */
export const CUSTOM_VIEWS_STORAGE_KEY = 'stategraph-inventory-custom-views';

/**
 * LocalStorage key for current view ID
 */
export const CURRENT_VIEW_STORAGE_KEY = 'stategraph-inventory-current-view';

/**
 * Load custom views from localStorage
 */
export function loadCustomViews(): View[] {
  try {
    const stored = localStorage.getItem(CUSTOM_VIEWS_STORAGE_KEY);
    if (stored) {
      return JSON.parse(stored);
    }
  } catch (error) {
    console.error('[Views] Failed to load custom views from localStorage:', error);
  }
  return [];
}

/**
 * Save custom views to localStorage
 */
export function saveCustomViews(views: View[]): void {
  try {
    localStorage.setItem(CUSTOM_VIEWS_STORAGE_KEY, JSON.stringify(views));
  } catch (error) {
    console.error('[Views] Failed to save custom views to localStorage:', error);
  }
}

/**
 * Load current view ID from localStorage
 */
export function loadCurrentViewId(): string {
  try {
    const stored = localStorage.getItem(CURRENT_VIEW_STORAGE_KEY);
    if (stored) {
      return stored;
    }
  } catch (error) {
    console.error('[Views] Failed to load current view ID from localStorage:', error);
  }
  return 'all'; // Default to "All Resources"
}

/**
 * Save current view ID to localStorage
 */
export function saveCurrentViewId(viewId: string): void {
  try {
    localStorage.setItem(CURRENT_VIEW_STORAGE_KEY, viewId);
  } catch (error) {
    console.error('[Views] Failed to save current view ID to localStorage:', error);
  }
}

/**
 * Get all views (default + custom)
 */
export function getAllViews(): View[] {
  const customViews = loadCustomViews();
  return [...DEFAULT_VIEWS, ...customViews];
}

/**
 * Get view by ID (searches both default and custom)
 */
export function getViewById(viewId: string): View | undefined {
  const allViews = getAllViews();
  return allViews.find((v) => v.id === viewId);
}

/**
 * Create a new custom view
 */
export function createCustomView(
  name: string,
  description: string,
  columnConfig: ColumnConfig
): View {
  const customViews = loadCustomViews();

  // Generate unique ID
  const id = `custom-${Date.now()}`;

  const newView: View = {
    id,
    name,
    description,
    isDefault: false,
    columnConfig,
    createdAt: new Date().toISOString(),
  };

  customViews.push(newView);
  saveCustomViews(customViews);

  return newView;
}

/**
 * Update an existing custom view
 */
export function updateCustomView(viewId: string, updates: Partial<Omit<View, 'id' | 'isDefault'>>): boolean {
  const customViews = loadCustomViews();
  const index = customViews.findIndex((v) => v.id === viewId);

  if (index === -1) {
    return false;
  }

  customViews[index] = {
    ...customViews[index],
    ...updates,
  };

  saveCustomViews(customViews);
  return true;
}

/**
 * Delete a custom view
 */
export function deleteCustomView(viewId: string): boolean {
  const customViews = loadCustomViews();
  const filtered = customViews.filter((v) => v.id !== viewId);

  if (filtered.length === customViews.length) {
    return false; // View not found
  }

  saveCustomViews(filtered);
  return true;
}

/**
 * Duplicate a view (creates a custom copy)
 */
export function duplicateView(sourceViewId: string, newName?: string): View | null {
  const sourceView = getViewById(sourceViewId);

  if (!sourceView) {
    return null;
  }

  const name = newName || `${sourceView.name} (Copy)`;
  const description = sourceView.description;
  const columnConfig = { ...sourceView.columnConfig };

  return createCustomView(name, description, columnConfig);
}

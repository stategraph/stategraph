/**
 * Query Engine Types
 * Shared types for the unified query system
 */

/**
 * Parsed query object structure
 */
export interface QueryObject {
  provider?: string[];
  type?: string[];
  module?: string[];
  free?: string[];
}

/**
 * Saved query structure
 */
export interface SavedQuery {
  name: string;
  q: string;
  createdAt?: string;
}

/**
 * Filter options for dropdowns
 */
export interface FilterOptions {
  providers: string[];
  types: string[];
  modules: string[];
}

/**
 * Query token for autocomplete
 */
export interface QueryToken {
  type: 'key' | 'value' | 'free';
  key?: string;
  value?: string;
}

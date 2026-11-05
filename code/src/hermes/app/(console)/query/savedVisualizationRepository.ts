/**
 * Repository pattern for Saved Visualizations
 * V1: localStorage implementation
 * Future: Can swap to backend API implementation
 */

import type { ChartType } from './analyticsUtils';

export interface SavedVisualization {
  id: string;
  name: string;
  description?: string;
  query: string;
  chartType: ChartType;
  dimensionField: string;
  metricFunction: 'COUNT';
  createdAt: string; // ISO timestamp
  updatedAt?: string; // ISO timestamp
}

export interface SavedVisualizationInput {
  name: string;
  description?: string;
  query: string;
  chartType: ChartType;
  dimensionField: string;
  metricFunction: 'COUNT';
}

interface StorageData {
  version: number;
  visualizations: SavedVisualization[];
}

/**
 * Abstract repository interface for saved visualizations
 * Allows easy swapping between localStorage and backend API
 */
export interface SavedVisualizationRepository {
  list(): SavedVisualization[];
  get(id: string): SavedVisualization | null;
  save(input: SavedVisualizationInput): SavedVisualization;
  update(id: string, fields: Partial<SavedVisualizationInput>): SavedVisualization | null;
  delete(id: string): boolean;
}

/**
 * localStorage implementation of SavedVisualizationRepository
 */
export class LocalSavedVisualizationRepository implements SavedVisualizationRepository {
  private readonly storageKey = 'stategraph.analytics.visualizations';
  private readonly currentVersion = 1;

  /**
   * Load data from localStorage with corruption protection
   */
  private load(): StorageData {
    try {
      const raw = localStorage.getItem(this.storageKey);
      if (!raw) {
        return { version: this.currentVersion, visualizations: [] };
      }

      const parsed = JSON.parse(raw);

      // Validate structure
      if (!parsed || typeof parsed !== 'object') {
        console.warn('Corrupted localStorage data, resetting');
        return { version: this.currentVersion, visualizations: [] };
      }

      // Handle version migrations if needed
      if (parsed.version !== this.currentVersion) {
        return this.migrate(parsed);
      }

      // Validate visualizations array
      if (!Array.isArray(parsed.visualizations)) {
        console.warn('Invalid visualizations array, resetting');
        return { version: this.currentVersion, visualizations: [] };
      }

      return parsed;
    } catch (error) {
      console.error('Error loading saved visualizations:', error);
      return { version: this.currentVersion, visualizations: [] };
    }
  }

  /**
   * Save data to localStorage
   */
  private persist(data: StorageData): void {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(data));
    } catch (error) {
      console.error('Error persisting saved visualizations:', error);
      // Could throw here if we want to surface the error to the UI
    }
  }

  /**
   * Handle version migrations
   */
  private migrate(oldData: unknown): StorageData {
    // For V1, no migrations needed yet
    // Future versions can add migration logic here
    console.log('Migrating visualization data from older version');
    const data = oldData as { visualizations?: unknown };
    return {
      version: this.currentVersion,
      visualizations: Array.isArray(data.visualizations) ? data.visualizations : [],
    };
  }

  /**
   * Generate a unique ID
   */
  private generateId(): string {
    return `viz_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * List all saved visualizations
   */
  list(): SavedVisualization[] {
    const data = this.load();
    // Return a copy to prevent external modifications
    return [...data.visualizations];
  }

  /**
   * Get a specific visualization by ID
   */
  get(id: string): SavedVisualization | null {
    const data = this.load();
    const viz = data.visualizations.find((v) => v.id === id);
    return viz ? { ...viz } : null;
  }

  /**
   * Save a new visualization
   */
  save(input: SavedVisualizationInput): SavedVisualization {
    const data = this.load();

    const newViz: SavedVisualization = {
      id: this.generateId(),
      name: input.name,
      description: input.description,
      query: input.query,
      chartType: input.chartType,
      dimensionField: input.dimensionField,
      metricFunction: input.metricFunction,
      createdAt: new Date().toISOString(),
    };

    data.visualizations.unshift(newViz); // Add to beginning
    this.persist(data);

    return { ...newViz };
  }

  /**
   * Update an existing visualization
   */
  update(id: string, fields: Partial<SavedVisualizationInput>): SavedVisualization | null {
    const data = this.load();
    const index = data.visualizations.findIndex((v) => v.id === id);

    if (index === -1) {
      return null;
    }

    const updated: SavedVisualization = {
      ...data.visualizations[index],
      ...fields,
      updatedAt: new Date().toISOString(),
    };

    data.visualizations[index] = updated;
    this.persist(data);

    return { ...updated };
  }

  /**
   * Delete a visualization
   */
  delete(id: string): boolean {
    const data = this.load();
    const initialLength = data.visualizations.length;

    data.visualizations = data.visualizations.filter((v) => v.id !== id);

    if (data.visualizations.length < initialLength) {
      this.persist(data);
      return true;
    }

    return false;
  }

  /**
   * Clear all visualizations (for testing/debugging)
   */
  clear(): void {
    localStorage.removeItem(this.storageKey);
  }
}

// Export a singleton instance
export const savedVisualizationRepository = new LocalSavedVisualizationRepository();

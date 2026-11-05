/**
 * Dashboard Repository
 *
 * Handles persistence of dashboards (collections of saved visualizations).
 * Uses localStorage with a repository pattern for future backend swap.
 */

// ============================================================================
// TYPES
// ============================================================================

export interface Dashboard {
  id: string;
  name: string;
  description?: string;
  visualizationIds: string[];  // Array of SavedVisualization IDs
  createdAt: string;           // ISO timestamp
  updatedAt?: string;          // ISO timestamp (for renames/updates)
}

export interface DashboardInput {
  name: string;
  description?: string;
  visualizationIds?: string[];  // Optional on create (defaults to [])
}

// ============================================================================
// REPOSITORY INTERFACE
// ============================================================================

export interface DashboardRepository {
  list(): Dashboard[];
  get(id: string): Dashboard | null;
  save(input: DashboardInput): Dashboard;
  update(id: string, fields: Partial<DashboardInput>): Dashboard | null;
  delete(id: string): boolean;
  addVisualization(dashboardId: string, visualizationId: string): Dashboard | null;
  removeVisualization(dashboardId: string, visualizationId: string): Dashboard | null;
}

// ============================================================================
// LOCALSTORAGE IMPLEMENTATION
// ============================================================================

interface StorageData {
  version: number;
  dashboards: Dashboard[];
}

export class LocalDashboardRepository implements DashboardRepository {
  private readonly storageKey = 'stategraph.analytics.dashboards';
  private readonly currentVersion = 1;

  /**
   * Load dashboards from localStorage
   */
  private load(): StorageData {
    try {
      const raw = localStorage.getItem(this.storageKey);
      if (!raw) {
        return { version: this.currentVersion, dashboards: [] };
      }

      const parsed = JSON.parse(raw);

      // Validate structure
      if (!parsed || typeof parsed !== 'object') {
        console.warn('[DashboardRepository] Corrupted localStorage data, resetting');
        return { version: this.currentVersion, dashboards: [] };
      }

      // Handle version migrations
      if (parsed.version !== this.currentVersion) {
        return this.migrate(parsed);
      }

      return parsed;
    } catch (error) {
      console.error('[DashboardRepository] Error loading dashboards:', error);
      return { version: this.currentVersion, dashboards: [] };
    }
  }

  /**
   * Persist dashboards to localStorage
   */
  private persist(data: StorageData): void {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(data));
    } catch (error) {
      console.error('[DashboardRepository] Error persisting dashboards:', error);
    }
  }

  /**
   * Migrate data from older versions
   */
  private migrate(oldData: unknown): StorageData {
    console.log('[DashboardRepository] Migrating from older version');

    // V1: No migrations needed yet
    // Future versions: Add migration logic here

    const data = oldData as { dashboards?: unknown };
    return {
      version: this.currentVersion,
      dashboards: Array.isArray(data.dashboards) ? data.dashboards : [],
    };
  }

  /**
   * Generate a unique ID for a new dashboard
   */
  private generateId(): string {
    // Format: dash_<timestamp>_<random>
    return `dash_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * List all dashboards (sorted by creation date, newest first)
   */
  list(): Dashboard[] {
    const data = this.load();
    return [...data.dashboards].sort((a, b) => {
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
  }

  /**
   * Get a single dashboard by ID
   */
  get(id: string): Dashboard | null {
    const data = this.load();
    const dashboard = data.dashboards.find((d) => d.id === id);
    return dashboard ? { ...dashboard } : null;
  }

  /**
   * Save a new dashboard
   */
  save(input: DashboardInput): Dashboard {
    const data = this.load();

    const newDashboard: Dashboard = {
      id: this.generateId(),
      name: input.name,
      description: input.description,
      visualizationIds: input.visualizationIds || [],
      createdAt: new Date().toISOString(),
    };

    data.dashboards.unshift(newDashboard);
    this.persist(data);

    return { ...newDashboard };
  }

  /**
   * Update an existing dashboard
   */
  update(id: string, fields: Partial<DashboardInput>): Dashboard | null {
    const data = this.load();
    const index = data.dashboards.findIndex((d) => d.id === id);

    if (index === -1) {
      return null;
    }

    const updated: Dashboard = {
      ...data.dashboards[index],
      ...fields,
      updatedAt: new Date().toISOString(),
    };

    data.dashboards[index] = updated;
    this.persist(data);

    return { ...updated };
  }

  /**
   * Delete a dashboard
   */
  delete(id: string): boolean {
    const data = this.load();
    const initialLength = data.dashboards.length;

    data.dashboards = data.dashboards.filter((d) => d.id !== id);

    if (data.dashboards.length === initialLength) {
      return false; // Not found
    }

    this.persist(data);
    return true;
  }

  /**
   * Add a visualization to a dashboard
   */
  addVisualization(dashboardId: string, visualizationId: string): Dashboard | null {
    const data = this.load();
    const index = data.dashboards.findIndex((d) => d.id === dashboardId);

    if (index === -1) {
      return null;
    }

    const dashboard = data.dashboards[index];

    // Prevent duplicates
    if (dashboard.visualizationIds.includes(visualizationId)) {
      return { ...dashboard };
    }

    const updated: Dashboard = {
      ...dashboard,
      visualizationIds: [...dashboard.visualizationIds, visualizationId],
      updatedAt: new Date().toISOString(),
    };

    data.dashboards[index] = updated;
    this.persist(data);

    return { ...updated };
  }

  /**
   * Remove a visualization from a dashboard
   */
  removeVisualization(dashboardId: string, visualizationId: string): Dashboard | null {
    const data = this.load();
    const index = data.dashboards.findIndex((d) => d.id === dashboardId);

    if (index === -1) {
      return null;
    }

    const dashboard = data.dashboards[index];

    const updated: Dashboard = {
      ...dashboard,
      visualizationIds: dashboard.visualizationIds.filter((id) => id !== visualizationId),
      updatedAt: new Date().toISOString(),
    };

    data.dashboards[index] = updated;
    this.persist(data);

    return { ...updated };
  }
}

// ============================================================================
// SINGLETON EXPORT
// ============================================================================

/**
 * Global repository instance.
 * To swap to backend API, replace this with ApiDashboardRepository.
 */
export const dashboardRepository: DashboardRepository = new LocalDashboardRepository();

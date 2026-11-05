/**
 * Saved Query Repository
 *
 * Repository pattern for saved queries with swappable implementations.
 * Current: localStorage
 * Future: Backend API
 */

export interface SavedQuery {
  id: string;
  name: string;
  description?: string;
  query: string;
  createdAt: number;
  updatedAt: number;
}

export interface SavedQueryRepository {
  /**
   * List all saved queries
   */
  list(): Promise<SavedQuery[]>;

  /**
   * Get a specific saved query by ID
   */
  get(id: string): Promise<SavedQuery | null>;

  /**
   * Save a new query or update existing one
   */
  save(query: Omit<SavedQuery, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }): Promise<SavedQuery>;

  /**
   * Delete a saved query
   */
  delete(id: string): Promise<void>;
}

/**
 * LocalStorage implementation of SavedQueryRepository
 * Can be swapped with an API implementation later
 */
export class LocalSavedQueryRepository implements SavedQueryRepository {
  private readonly storageKey = 'stategraph.saved.queries';

  private async getAll(): Promise<SavedQuery[]> {
    try {
      const stored = localStorage.getItem(this.storageKey);
      if (!stored) return [];
      return JSON.parse(stored);
    } catch (error) {
      console.error('Failed to load saved queries:', error);
      return [];
    }
  }

  private async saveAll(queries: SavedQuery[]): Promise<void> {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(queries));
    } catch (error) {
      console.error('Failed to save queries:', error);
      throw new Error('Failed to save query');
    }
  }

  async list(): Promise<SavedQuery[]> {
    const queries = await this.getAll();
    // Sort by updatedAt descending (most recent first)
    return queries.sort((a, b) => b.updatedAt - a.updatedAt);
  }

  async get(id: string): Promise<SavedQuery | null> {
    const queries = await this.getAll();
    return queries.find(q => q.id === id) || null;
  }

  async save(
    input: Omit<SavedQuery, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }
  ): Promise<SavedQuery> {
    const queries = await this.getAll();
    const now = Date.now();

    if (input.id) {
      // Update existing
      const index = queries.findIndex(q => q.id === input.id);
      if (index === -1) {
        throw new Error('Query not found');
      }

      const updated: SavedQuery = {
        ...queries[index],
        name: input.name,
        description: input.description,
        query: input.query,
        updatedAt: now,
      };

      queries[index] = updated;
      await this.saveAll(queries);
      return updated;
    } else {
      // Create new
      const newQuery: SavedQuery = {
        id: `sq_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        name: input.name,
        description: input.description,
        query: input.query,
        createdAt: now,
        updatedAt: now,
      };

      queries.push(newQuery);
      await this.saveAll(queries);
      return newQuery;
    }
  }

  async delete(id: string): Promise<void> {
    const queries = await this.getAll();
    const filtered = queries.filter(q => q.id !== id);

    if (filtered.length === queries.length) {
      throw new Error('Query not found');
    }

    await this.saveAll(filtered);
  }
}

/**
 * Repository singleton instance
 * In the future, this can be swapped with an API implementation
 */
export const savedQueryRepository: SavedQueryRepository = new LocalSavedQueryRepository();

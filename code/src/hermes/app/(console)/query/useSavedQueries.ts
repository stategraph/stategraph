/**
 * Saved Queries Hook
 *
 * React hook that wraps the SavedQueryRepository for easy component integration
 */

import { useState, useEffect, useCallback } from 'react';
import { savedQueryRepository, type SavedQuery } from './savedQueryRepository';

export function useSavedQueries() {
  const [savedQueries, setSavedQueries] = useState<SavedQuery[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load saved queries
  const loadQueries = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const queries = await savedQueryRepository.list();
      setSavedQueries(queries);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to load saved queries');
      console.error('Failed to load saved queries:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  // Load on mount
  useEffect(() => {
    loadQueries();
  }, [loadQueries]);

  // Save a query
  const saveQuery = useCallback(
    async (
      name: string,
      query: string,
      description?: string,
      id?: string
    ): Promise<SavedQuery> => {
      try {
        const saved = await savedQueryRepository.save({
          id,
          name,
          query,
          description,
        });

        // Reload list to get updated sort order
        await loadQueries();

        return saved;
      } catch (err: unknown) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to save query';
        setError(errorMsg);
        throw new Error(errorMsg);
      }
    },
    [loadQueries]
  );

  // Delete a query
  const deleteQuery = useCallback(
    async (id: string): Promise<void> => {
      try {
        await savedQueryRepository.delete(id);
        await loadQueries();
      } catch (err: unknown) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to delete query';
        setError(errorMsg);
        throw new Error(errorMsg);
      }
    },
    [loadQueries]
  );

  // Get a specific query
  const getQuery = useCallback(async (id: string): Promise<SavedQuery | null> => {
    try {
      return await savedQueryRepository.get(id);
    } catch (err: unknown) {
      console.error('Failed to get query:', err);
      return null;
    }
  }, []);

  return {
    savedQueries,
    loading,
    error,
    saveQuery,
    deleteQuery,
    getQuery,
    refresh: loadQueries,
  };
}

/**
 * Query History Hook
 *
 * Manages client-side query history with localStorage persistence.
 */

import { useState, useEffect } from 'react';

const STORAGE_KEY = 'stategraph.query.history';
const MAX_HISTORY_SIZE = 20;

export interface HistoryEntry {
  id: string;
  query: string;
  timestamp: number;
  executionTime?: number;
  resultCount?: number;
}

export function useQueryHistory() {
  // Load history from localStorage using lazy initialization
  const [history, setHistory] = useState<HistoryEntry[]>(() => {
    try {
      if (typeof window === 'undefined') return [];
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        return JSON.parse(stored);
      }
    } catch (error) {
      console.error('Failed to load query history:', error);
    }
    return [];
  });

  // Save history to localStorage whenever it changes
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(history));
    } catch (error) {
      console.error('Failed to save query history:', error);
    }
  }, [history]);

  /**
   * Add a query to history
   * Deduplicates consecutive identical queries
   */
  const addToHistory = (
    query: string,
    executionTime?: number,
    resultCount?: number
  ) => {
    // Normalize query (trim whitespace and semicolons)
    const normalizedQuery = query.trim().replace(/;+$/, '');

    if (!normalizedQuery) return;

    setHistory((prev) => {
      // Check if the last query is identical (deduplicate)
      if (prev.length > 0 && prev[0].query === normalizedQuery) {
        // Update the existing entry with new execution data
        return [
          {
            ...prev[0],
            timestamp: Date.now(),
            executionTime,
            resultCount,
          },
          ...prev.slice(1),
        ];
      }

      // Create new entry
      const newEntry: HistoryEntry = {
        id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        query: normalizedQuery,
        timestamp: Date.now(),
        executionTime,
        resultCount,
      };

      // Add to beginning and limit size
      return [newEntry, ...prev].slice(0, MAX_HISTORY_SIZE);
    });
  };

  /**
   * Remove a specific entry from history
   */
  const removeFromHistory = (id: string) => {
    setHistory((prev) => prev.filter((entry) => entry.id !== id));
  };

  /**
   * Clear all history
   */
  const clearHistory = () => {
    setHistory([]);
  };

  /**
   * Get the most recent query
   */
  const getLastQuery = (): string | null => {
    return history.length > 0 ? history[0].query : null;
  };

  return {
    history,
    addToHistory,
    removeFromHistory,
    clearHistory,
    getLastQuery,
  };
}

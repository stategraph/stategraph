"use client";

import { useState, useCallback } from "react";

interface SavedQuery {
  q: string;
  name?: string;
  timestamp: number;
}

interface SavedQueriesData {
  recent: SavedQuery[];
  saved: SavedQuery[];
}

const STORAGE_KEY = "stategraph-queries";
const MAX_RECENT = 10;

export function useSavedQueries() {
  // Load from localStorage using lazy initialization
  const [data, setData] = useState<SavedQueriesData>(() => {
    if (typeof window === "undefined") {
      return { recent: [], saved: [] };
    }
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        return JSON.parse(stored);
      }
    } catch (error) {
      console.error("Failed to load saved queries:", error);
    }
    return { recent: [], saved: [] };
  });

  // Add a query to recent history
  const addToRecent = useCallback((q: string) => {
    if (!q.trim()) return;

    setData((prev) => {
      const newRecent = [
        { q, timestamp: Date.now() },
        ...prev.recent.filter((item) => item.q !== q),
      ].slice(0, MAX_RECENT);

      const newData = {
        ...prev,
        recent: newRecent,
      };

      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(newData));
      } catch (error) {
        console.error("Failed to save queries:", error);
      }

      return newData;
    });
  }, []);

  // Save a query with a name
  const saveQuery = useCallback((q: string, name: string) => {
    if (!q.trim() || !name.trim()) return;

    setData((prev) => {
      const newSaved = [
        { q, name, timestamp: Date.now() },
        ...prev.saved.filter((item) => item.name !== name),
      ];

      const newData = {
        ...prev,
        saved: newSaved,
      };

      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(newData));
      } catch (error) {
        console.error("Failed to save queries:", error);
      }

      return newData;
    });
  }, []);

  // Remove a saved query
  const removeSaved = useCallback((name: string) => {
    setData((prev) => {
      const newData = {
        ...prev,
        saved: prev.saved.filter((item) => item.name !== name),
      };

      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(newData));
      } catch (error) {
        console.error("Failed to save queries:", error);
      }

      return newData;
    });
  }, []);

  // Clear recent history
  const clearRecent = useCallback(() => {
    setData((prev) => {
      const newData = {
        ...prev,
        recent: [],
      };

      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(newData));
      } catch (error) {
        console.error("Failed to save queries:", error);
      }

      return newData;
    });
  }, []);

  return {
    recent: data.recent,
    saved: data.saved,
    addToRecent,
    saveQuery,
    removeSaved,
    clearRecent,
  };
}

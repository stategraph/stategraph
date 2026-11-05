/**
 * React hook for managing saved visualizations
 */

import { useState } from 'react';
import {
  savedVisualizationRepository,
  type SavedVisualization,
  type SavedVisualizationInput,
} from './savedVisualizationRepository';

export function useSavedVisualizations() {
  const [visualizations, setVisualizations] = useState<SavedVisualization[]>(() => {
    // Initialize with data from repository
    return savedVisualizationRepository.list();
  });

  // Reload function for refreshing
  const loadVisualizations = () => {
    const loaded = savedVisualizationRepository.list();
    setVisualizations(loaded);
  };

  const saveVisualization = (input: SavedVisualizationInput): SavedVisualization => {
    const saved = savedVisualizationRepository.save(input);
    const loaded = savedVisualizationRepository.list();
    setVisualizations(loaded); // Refresh list
    return saved;
  };

  const updateVisualization = (
    id: string,
    fields: Partial<SavedVisualizationInput>
  ): SavedVisualization | null => {
    const updated = savedVisualizationRepository.update(id, fields);
    if (updated) {
      loadVisualizations(); // Refresh list
    }
    return updated;
  };

  const deleteVisualization = (id: string): boolean => {
    const deleted = savedVisualizationRepository.delete(id);
    if (deleted) {
      loadVisualizations(); // Refresh list
    }
    return deleted;
  };

  const getVisualization = (id: string): SavedVisualization | null => {
    return savedVisualizationRepository.get(id);
  };

  return {
    visualizations,
    saveVisualization,
    updateVisualization,
    deleteVisualization,
    getVisualization,
    refresh: loadVisualizations,
  };
}

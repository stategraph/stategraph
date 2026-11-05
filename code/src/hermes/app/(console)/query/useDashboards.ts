/**
 * React hook for managing dashboards
 */

import { useState } from 'react';
import {
  dashboardRepository,
  type Dashboard,
  type DashboardInput,
} from './dashboardRepository';

export function useDashboards() {
  const [dashboards, setDashboards] = useState<Dashboard[]>(() => {
    // Initialize with data from repository
    return dashboardRepository.list();
  });

  // Reload function for refreshing
  const loadDashboards = () => {
    const loaded = dashboardRepository.list();
    setDashboards(loaded);
  };

  const saveDashboard = (input: DashboardInput): Dashboard => {
    const saved = dashboardRepository.save(input);
    const loaded = dashboardRepository.list();
    setDashboards(loaded); // Refresh list
    return saved;
  };

  const updateDashboard = (
    id: string,
    fields: Partial<DashboardInput>
  ): Dashboard | null => {
    const updated = dashboardRepository.update(id, fields);
    if (updated) {
      loadDashboards(); // Refresh list
    }
    return updated;
  };

  const deleteDashboard = (id: string): boolean => {
    const deleted = dashboardRepository.delete(id);
    if (deleted) {
      loadDashboards(); // Refresh list
    }
    return deleted;
  };

  const getDashboard = (id: string): Dashboard | null => {
    return dashboardRepository.get(id);
  };

  const addVisualizationToDashboard = (
    dashboardId: string,
    visualizationId: string
  ): Dashboard | null => {
    const updated = dashboardRepository.addVisualization(dashboardId, visualizationId);
    if (updated) {
      loadDashboards(); // Refresh list
    }
    return updated;
  };

  const removeVisualizationFromDashboard = (
    dashboardId: string,
    visualizationId: string
  ): Dashboard | null => {
    const updated = dashboardRepository.removeVisualization(dashboardId, visualizationId);
    if (updated) {
      loadDashboards(); // Refresh list
    }
    return updated;
  };

  return {
    dashboards,
    saveDashboard,
    updateDashboard,
    deleteDashboard,
    getDashboard,
    addVisualizationToDashboard,
    removeVisualizationFromDashboard,
    refresh: loadDashboards,
  };
}

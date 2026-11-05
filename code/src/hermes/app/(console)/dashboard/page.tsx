"use client";

import { useState, useEffect, useCallback, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { ArrowLeft, Plus, Edit, Trash2, AlertCircle, BookmarkPlus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useStates } from '@/contexts/StateContext';
import { useDeepLinkRouter, useStateSelection } from '@/hooks';
import { useDashboards } from '../query/useDashboards';
import { AddVisualizationDialog } from '../query/AddVisualizationDialog';
import { savedVisualizationRepository, type SavedVisualization } from '../query/savedVisualizationRepository';
import { InlinePanelEditor } from './InlinePanelEditor';
import { loadChartData, ChartAggregationUnsupportedError } from '@/lib/analytics/loadChartData';
import { AnalyticsChart } from '../query/AnalyticsChart';
import { type ChartDataPoint } from '../query/analyticsUtils';
import type { Dashboard } from '../query/dashboardRepository';
import { StateFilter } from '@/components/filters';

interface ChartState {
  loading: boolean;
  error: string | null;
  chartData: Record<string, unknown>[] | null;
}

function ChartContent({ chartState, visualization }: { chartState: ChartState; visualization: SavedVisualization }) {
  if (chartState.loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[var(--sg-accent)] mx-auto mb-3"></div>
          <div className="text-sm text-[var(--sg-text-muted)]">Loading chart...</div>
        </div>
      </div>
    );
  }

  if (chartState.error) {
    return (
      <div className="px-4 py-3 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
        <div className="flex items-start gap-2">
          <AlertCircle className="w-5 h-5 text-[var(--sg-error)] flex-shrink-0 mt-0.5" />
          <div>
            <div className="text-sm font-medium text-[var(--sg-error)] mb-1">
              Failed to load chart
            </div>
            <div className="text-xs text-[var(--sg-error)]/80">{chartState.error}</div>
          </div>
        </div>
      </div>
    );
  }

  if (chartState.chartData && chartState.chartData.length > 0) {
    return (
      <div className="h-[400px]">
        <AnalyticsChart
          chartType={visualization.chartType}
          data={chartState.chartData as ChartDataPoint[]}
          dimensionField={visualization.dimensionField}
          metricField="count"
        />
      </div>
    );
  }

  return (
    <div className="text-center py-12">
      <div className="text-sm text-[var(--sg-text-muted)]">No data available</div>
    </div>
  );
}

function DashboardViewer() {
  const searchParams = useSearchParams();
  const router = useDeepLinkRouter();
  const { states, isLoading: statesLoading } = useStates();
  const {
    getDashboard,
    updateDashboard,
    deleteDashboard,
    addVisualizationToDashboard,
    removeVisualizationFromDashboard,
  } = useDashboards();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection({ allowAll: false });

  // Get the currently selected state object
  const currentState = states.find(s => s.id === selectedStateId) || null;

  const dashboardId = searchParams.get('id') || '';

  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [isRenaming, setIsRenaming] = useState(false);
  const [renameName, setRenameName] = useState('');
  const [renameDescription, setRenameDescription] = useState('');
  const [showAddDialog, setShowAddDialog] = useState(false);
  const [showInlineEditor, setShowInlineEditor] = useState(false);

  // Store chart states for each visualization
  const [chartStates, setChartStates] = useState<Record<string, ChartState>>({});

  // Load dashboard on mount
  useEffect(() => {
    // Redirect to dashboards list if no ID provided
    if (!dashboardId) {
      router.push('/dashboards');
      return;
    }

    const dash = getDashboard(dashboardId);
    if (!dash) {
      setNotFound(true);
      return;
    }
    setDashboard(dash);
    setRenameName(dash.name);
    setRenameDescription(dash.description || '');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboardId]);

  // Execute a single visualization's query as a server-side MQL aggregation over
  // the whole selected state (#1055), instead of counting a capped client-side
  // page. Unsupported queries/dimensions surface as a per-panel error.
  const executeQueryForViz = useCallback(async (vizId: string) => {
    const visualization = savedVisualizationRepository.get(vizId);

    if (!visualization || !currentState) {
      setChartStates(prev => ({
        ...prev,
        [vizId]: { loading: false, error: 'No state selected', chartData: null }
      }));
      return;
    }

    setChartStates(prev => ({
      ...prev,
      [vizId]: { loading: true, error: null, chartData: null }
    }));

    try {
      const { data } = await loadChartData({
        stateId: currentState.id,
        query: visualization.query,
        dimensionField: visualization.dimensionField,
      });

      setChartStates(prev => ({
        ...prev,
        [vizId]: { loading: false, error: null, chartData: data }
      }));
    } catch (error: unknown) {
      setChartStates(prev => ({
        ...prev,
        [vizId]: {
          loading: false,
          error:
            error instanceof ChartAggregationUnsupportedError
              ? error.message
              : error instanceof Error
                ? error.message
                : 'Unknown error occurred',
          chartData: null,
        }
      }));
    }
  }, [currentState]);

  // Execute all visualization queries when dashboard loads
  useEffect(() => {
    if (dashboard && currentState) {
      dashboard.visualizationIds.forEach(vizId => {
        executeQueryForViz(vizId);
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboard?.id, currentState?.id]);

  const handleSaveRename = () => {
    if (!dashboard) return;

    const updated = updateDashboard(dashboard.id, {
      name: renameName,
      description: renameDescription || undefined,
    });

    if (updated) {
      setDashboard(updated);
      setIsRenaming(false);
    }
  };

  const handleDelete = () => {
    if (!dashboard) return;

    if (confirm(`Delete "${dashboard.name}"? This action cannot be undone.`)) {
      const deleted = deleteDashboard(dashboard.id);
      if (deleted) {
        router.push('/dashboards');
      }
    }
  };

  const reloadDashboard = useCallback((id: string) => {
    const dash = getDashboard(id);
    if (dash) {
      setDashboard(dash);
      setRenameName(dash.name);
      setRenameDescription(dash.description || '');
    }
  }, [getDashboard]);

  const handleAddVisualizations = (visualizationIds: string[]) => {
    if (!dashboard) return;

    visualizationIds.forEach((vizId) => {
      addVisualizationToDashboard(dashboard.id, vizId);
    });

    reloadDashboard(dashboard.id);

    visualizationIds.forEach((vizId) => {
      executeQueryForViz(vizId);
    });
  };

  const handleRemoveVisualization = (visualizationId: string) => {
    if (!dashboard) return;
    removeVisualizationFromDashboard(dashboard.id, visualizationId);
    reloadDashboard(dashboard.id);
  };

  const handlePanelCreated = (vizId: string) => {
    reloadDashboard(dashboardId);
    executeQueryForViz(vizId);
    setShowInlineEditor(false);
  };

  const formatDate = (isoString: string) => {
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Not found state
  if (notFound) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="text-center max-w-md">
          <AlertCircle className="w-16 h-16 mx-auto mb-4 text-[var(--sg-error)]" />
          <h2 className="text-xl font-semibold text-[var(--sg-text)] mb-2">
            Dashboard Not Found
          </h2>
          <p className="text-sm text-[var(--sg-text-muted)] mb-6">
            The dashboard you&apos;re looking for doesn&apos;t exist or has been deleted.
          </p>
          <Button {...router.nav('/dashboards')}>
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Dashboards
          </Button>
        </div>
      </div>
    );
  }

  // Loading state
  if (!dashboard) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="text-center">
          <div className="text-sm text-[var(--sg-text-muted)]">Loading dashboard...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col bg-[var(--sg-bg-0)]">
      {/* Header */}
      <div className="border-b border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-4 py-4 sm:px-6">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div className="flex-1 min-w-0">
            {isRenaming ? (
              <div className="space-y-3">
                <input
                  type="text"
                  value={renameName}
                  onChange={(e) => setRenameName(e.target.value)}
                  className="w-full px-3 py-2 bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-lg text-lg font-semibold text-[var(--sg-text)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                  autoFocus
                />
                <textarea
                  value={renameDescription}
                  onChange={(e) => setRenameDescription(e.target.value)}
                  placeholder="Description (optional)"
                  rows={2}
                  className="w-full px-3 py-2 bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text-muted)] resize-none focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                />
                <div className="flex gap-2">
                  <Button onClick={handleSaveRename} size="sm">
                    Save
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => {
                      setIsRenaming(false);
                      setRenameName(dashboard.name);
                      setRenameDescription(dashboard.description || '');
                    }}
                    size="sm"
                  >
                    Cancel
                  </Button>
                </div>
              </div>
            ) : (
              <>
                <h1 className="text-2xl font-semibold text-[var(--sg-text)] mb-2">
                  {dashboard.name}
                </h1>
                {dashboard.description && (
                  <p className="text-sm text-[var(--sg-text-muted)] mb-2">
                    {dashboard.description}
                  </p>
                )}
                <div className="text-xs text-[var(--sg-text-dim)]">
                  Created {formatDate(dashboard.createdAt)}
                  {dashboard.updatedAt && ` • Updated ${formatDate(dashboard.updatedAt)}`}
                </div>
              </>
            )}
          </div>

          {!isRenaming && (
            <div className="flex flex-wrap gap-2">
              <StateFilter
                value={selectedStateId}
                onChange={setSelectedStateId}
                className="w-full sm:w-auto sm:min-w-[200px]"
              />
              <Button variant="outline" size="sm" {...router.nav('/dashboards')}>
                <ArrowLeft className="w-4 h-4 mr-2" />
                Back
              </Button>
              <Button variant="outline" size="sm" onClick={() => setIsRenaming(true)}>
                <Edit className="w-4 h-4 mr-2" />
                Rename
              </Button>
              <Button variant="outline" size="sm" onClick={handleDelete}>
                <Trash2 className="w-4 h-4 mr-2" />
                Delete
              </Button>
              <Button onClick={() => setShowInlineEditor(true)} size="sm">
                <Plus className="w-4 h-4 mr-2" />
                Create Panel
              </Button>
              <Button variant="outline" size="sm" onClick={() => setShowAddDialog(true)}>
                <BookmarkPlus className="w-4 h-4 mr-2" />
                Add Saved
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-6">
        {dashboard.visualizationIds.length === 0 ? (
          // Empty State
          <div className="flex items-center justify-center py-24">
            <div className="text-center max-w-md">
              <div className="w-16 h-16 mx-auto mb-4 rounded-lg bg-[var(--sg-bg-2)] flex items-center justify-center">
                <Plus className="w-8 h-8 text-[var(--sg-text-muted)]" />
              </div>
              <h3 className="text-lg font-semibold text-[var(--sg-text)] mb-2">
                No Visualizations Yet
              </h3>
              <p className="text-sm text-[var(--sg-text-muted)] mb-6">
                Create a panel by writing a query and configuring a chart, or add an existing saved visualization.
              </p>
              <Button onClick={() => setShowInlineEditor(true)}>
                <Plus className="w-4 h-4 mr-2" />
                Create Panel
              </Button>
              <button
                onClick={() => setShowAddDialog(true)}
                className="block mx-auto mt-3 text-sm text-[var(--sg-accent)] hover:underline"
              >
                or add from saved visualizations
              </button>
            </div>
          </div>
        ) : (
          // Chart Grid - RENDER DIRECTLY WITH WORKING STRUCTURE
          <div className="space-y-6 max-w-7xl mx-auto">
            {dashboard.visualizationIds.map((vizId) => {
              const visualization = savedVisualizationRepository.get(vizId);
              // With no state to query (an empty tenant), a panel's query is
              // never issued — resolve it to the neutral no-data card instead
              // of the initial loading placeholder.
              const chartState =
                chartStates[vizId] ??
                (currentState || statesLoading
                  ? { loading: true, error: null, chartData: null }
                  : { loading: false, error: null, chartData: [] });

              if (!visualization) {
                return (
                  <div key={vizId} className="border border-[var(--sg-border)] rounded-lg p-6 bg-[var(--sg-bg-1)]">
                    <div className="flex items-center gap-2 text-[var(--sg-error)]">
                      <AlertCircle className="w-5 h-5" />
                      <span className="text-sm font-medium">Visualization not found</span>
                    </div>
                    <button
                      onClick={() => handleRemoveVisualization(vizId)}
                      className="mt-3 text-xs text-[var(--sg-accent)] hover:underline"
                    >
                      Remove from dashboard
                    </button>
                  </div>
                );
              }

              return (
                <div key={vizId} className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
                  {/* Header */}
                  <div className="flex items-start justify-between px-6 py-4 border-b border-[var(--sg-border)]">
                    <div className="flex-1 min-w-0">
                      <h3 className="text-base font-semibold text-[var(--sg-text)] mb-1">
                        {visualization.name}
                      </h3>
                      {visualization.description && (
                        <p className="text-sm text-[var(--sg-text-muted)]">{visualization.description}</p>
                      )}
                    </div>
                    <button
                      onClick={() => {
                        if (confirm(`Remove "${visualization.name}" from this dashboard?`)) {
                          handleRemoveVisualization(vizId);
                        }
                      }}
                      className="p-2 rounded hover:bg-[var(--sg-error)]/10 transition-colors"
                      title="Remove from dashboard"
                    >
                      <Trash2 className="w-4 h-4 text-[var(--sg-error)]" />
                    </button>
                  </div>

                  {/* Chart */}
                  <div className="border border-[var(--sg-border)] rounded-lg p-6 bg-[var(--sg-bg-1)]">
                    <ChartContent chartState={chartState} visualization={visualization} />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Add Visualization Dialog */}
      <AddVisualizationDialog
        isOpen={showAddDialog}
        onClose={() => setShowAddDialog(false)}
        onAdd={handleAddVisualizations}
        excludeIds={dashboard.visualizationIds}
      />

      {/* Inline Panel Editor */}
      {showInlineEditor && (
        <InlinePanelEditor
          dashboardId={dashboard.id}
          onClose={() => setShowInlineEditor(false)}
          onPanelCreated={handlePanelCreated}
        />
      )}
    </div>
  );
}

export default function DashboardViewerPage() {
  return (
    <Suspense fallback={
      <div className="h-full flex items-center justify-center">
        <div className="text-sm text-[var(--sg-text-muted)]">Loading dashboard...</div>
      </div>
    }>
      <DashboardViewer />
    </Suspense>
  );
}

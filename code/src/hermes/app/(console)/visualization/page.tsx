"use client";

import { useState, useEffect, useCallback, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { ArrowLeft, Play, Edit, Trash2, Code, Info, AlertCircle, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useStates } from '@/contexts/StateContext';
import { useDeepLinkRouter, useStateSelection } from '@/hooks';
import {
  savedVisualizationRepository,
  type SavedVisualization,
} from '../query/savedVisualizationRepository';
import { type ParsedQuery, type WhereCondition } from '../query/compiler';
import { loadChartData, ChartAggregationUnsupportedError } from '@/lib/analytics/loadChartData';
import { AnalyticsChart } from '../query/AnalyticsChart';
import { type ChartDataPoint } from '../query/analyticsUtils';
import { AddVisualizationToDashboardDialog } from '../query/AddVisualizationToDashboardDialog';
import { useDashboards } from '../query/useDashboards';
import { StateFilter } from '@/components/filters';

interface QueryExecutionState {
  loading: boolean;
  error: string | null;
  results: Record<string, unknown>[] | null;
  chartData: Record<string, unknown>[] | null;
  executionTime: number | null;
}

function VisualizationViewer() {
  const searchParams = useSearchParams();
  const router = useDeepLinkRouter();
  const { states, isLoading: statesLoading } = useStates();
  const { addVisualizationToDashboard } = useDashboards();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection({ allowAll: false });

  // Get the currently selected state object
  const currentState = states.find(s => s.id === selectedStateId) || null;

  const visualizationId = searchParams.get('id') || '';

  // Visualization metadata
  const [visualization, setVisualization] = useState<SavedVisualization | null>(null);
  const [notFound, setNotFound] = useState(false);

  // Query execution state
  const [execution, setExecution] = useState<QueryExecutionState>({
    loading: false,
    error: null,
    results: null,
    chartData: null,
    executionTime: null,
  });

  // UI state
  const [showExplain, setShowExplain] = useState(false);
  const [showQuery, setShowQuery] = useState(true);
  const [isRenaming, setIsRenaming] = useState(false);
  const [renameName, setRenameName] = useState('');
  const [renameDescription, setRenameDescription] = useState('');
  const [showAddToDashboard, setShowAddToDashboard] = useState(false);

  // Parsed query + executed MQL for the Explain panel
  const [parsedQuery, setParsedQuery] = useState<ParsedQuery | null>(null);
  const [execMql, setExecMql] = useState<string | null>(null);

  // Load visualization on mount
  useEffect(() => {
    // Redirect to query page if no ID provided
    if (!visualizationId) {
      router.push('/query');
      return;
    }

    const viz = savedVisualizationRepository.get(visualizationId);
    /* eslint-disable react-hooks/set-state-in-effect -- one-time load of the saved
       visualization from localStorage on mount; not derivable during render. */
    if (!viz) {
      setNotFound(true);
      return;
    }
    setVisualization(viz);
    setRenameName(viz.name);
    setRenameDescription(viz.description || '');
    /* eslint-enable react-hooks/set-state-in-effect */
  }, [visualizationId, router]);

  // Execute the saved query
  const executeQuery = useCallback(async () => {
    if (!visualization || !currentState) {
      setExecution((prev) => ({
        ...prev,
        error: 'No state selected. Please select a state from the dropdown.',
      }));
      return;
    }

    setExecution({
      loading: true,
      error: null,
      results: null,
      chartData: null,
      executionTime: null,
    });

    try {
      const startTime = Date.now();

      // Aggregate server-side over the whole state (count(*) group by dimension)
      // instead of counting a capped client-side page (#1055).
      const result = await loadChartData({
        stateId: currentState.id,
        query: visualization.query,
        dimensionField: visualization.dimensionField,
      });

      setParsedQuery(result.parsed);
      setExecMql(result.mql);

      setExecution({
        loading: false,
        error: null,
        results: result.data,
        chartData: result.data,
        executionTime: Date.now() - startTime,
      });
    } catch (error: unknown) {
      setParsedQuery(null);
      setExecMql(null);
      setExecution({
        loading: false,
        error:
          error instanceof ChartAggregationUnsupportedError
            ? error.message
            : error instanceof Error
              ? error.message
              : 'Unknown error occurred',
        results: null,
        chartData: null,
        executionTime: null,
      });
    }
  }, [visualization, currentState]);

  // Auto-execute query when visualization loads and state is available
  useEffect(() => {
    if (visualization && currentState && !execution.results) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- kicks off the async query when inputs are ready
      executeQuery();
    }
  }, [visualization, currentState, execution.results, executeQuery]);

  // Handle rename
  const handleSaveRename = () => {
    if (!visualization) return;

    const updated = savedVisualizationRepository.update(visualization.id, {
      name: renameName,
      description: renameDescription || undefined,
    });

    if (updated) {
      setVisualization(updated);
      setIsRenaming(false);
    }
  };

  // Handle delete
  const handleDelete = () => {
    if (!visualization) return;

    if (confirm(`Delete "${visualization.name}"? This action cannot be undone.`)) {
      const deleted = savedVisualizationRepository.delete(visualization.id);
      if (deleted) {
        router.push('/query');
      }
    }
  };

  // Handle add to dashboard
  const handleAddToDashboards = (dashboardIds: string[]) => {
    dashboardIds.forEach((dashboardId) => {
      addVisualizationToDashboard(dashboardId, visualizationId);
    });
  };

  // Format date
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
            Visualization Not Found
          </h2>
          <p className="text-sm text-[var(--sg-text-muted)] mb-6">
            The visualization you&apos;re looking for doesn&apos;t exist or has been deleted.
          </p>
          <Button {...router.nav('/query')}>
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Query
          </Button>
        </div>
      </div>
    );
  }

  // Loading state (initial load)
  if (!visualization) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="text-center">
          <div className="text-sm text-[var(--sg-text-muted)]">Loading visualization...</div>
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
                      setRenameName(visualization.name);
                      setRenameDescription(visualization.description || '');
                    }}
                    size="sm"
                  >
                    Cancel
                  </Button>
                </div>
              </div>
            ) : (
              <>
                <div className="flex items-center gap-3 mb-2">
                  <h1 className="text-2xl font-semibold text-[var(--sg-text)]">
                    {visualization.name}
                  </h1>
                  <span className="px-2 py-1 text-xs rounded bg-[var(--sg-accent)]/20 text-[var(--sg-accent)] uppercase tracking-wide">
                    {visualization.chartType}
                  </span>
                </div>
                {visualization.description && (
                  <p className="text-sm text-[var(--sg-text-muted)] mb-2">
                    {visualization.description}
                  </p>
                )}
                <div className="text-xs text-[var(--sg-text-dim)]">
                  Created {formatDate(visualization.createdAt)}
                  {visualization.updatedAt && ` • Updated ${formatDate(visualization.updatedAt)}`}
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
              <Button variant="outline" size="sm" {...router.nav('/query')}>
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
              <Button variant="outline" size="sm" onClick={() => setShowAddToDashboard(true)}>
                <Plus className="w-4 h-4 mr-2" />
                Add to Dashboard
              </Button>
              <Button onClick={executeQuery} disabled={execution.loading} size="sm">
                <Play className="w-4 h-4 mr-2" />
                {execution.loading ? 'Running...' : 'Run Again'}
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        {/* No states: the query never runs, so say why instead of a blank page */}
        {!statesLoading && states.length === 0 && (
          <div className="border border-[var(--sg-border)] rounded-lg p-12 bg-[var(--sg-bg-1)] text-center">
            <Info className="w-12 h-12 mx-auto mb-3 text-[var(--sg-text-muted)]" />
            <div className="text-sm text-[var(--sg-text-muted)]">
              No states in this tenant yet. Import or create a state to run this visualization.
            </div>
          </div>
        )}

        {/* Error Banner */}
        {execution.error && (
          <div className="px-4 py-3 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
            <div className="flex items-start gap-2">
              <AlertCircle className="w-5 h-5 text-[var(--sg-error)] flex-shrink-0 mt-0.5" />
              <div>
                <div className="text-sm font-medium text-[var(--sg-error)] mb-1">
                  Failed to execute query
                </div>
                <div className="text-xs text-[var(--sg-error)]/80">{execution.error}</div>
                <Button variant="outline" size="sm" onClick={executeQuery} className="mt-2">
                  <Play className="w-3 h-3 mr-2" />
                  Retry
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* Loading State */}
        {execution.loading && (
          <div className="flex items-center justify-center py-12">
            <div className="text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[var(--sg-accent)] mx-auto mb-3"></div>
              <div className="text-sm text-[var(--sg-text-muted)]">Running query...</div>
            </div>
          </div>
        )}

        {/* Chart Display */}
        {!execution.loading && execution.chartData && execution.chartData.length > 0 && (
          <div className="border border-[var(--sg-border)] rounded-lg p-6 bg-[var(--sg-bg-1)]">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-semibold text-[var(--sg-text)]">Visualization</h3>
              <div className="text-xs text-[var(--sg-text-muted)]">
                {execution.chartData.length} data{' '}
                {execution.chartData.length === 1 ? 'point' : 'points'}
                {execution.executionTime && ` • ${execution.executionTime}ms`}
              </div>
            </div>
            <div className="h-[400px]">
              <AnalyticsChart
                chartType={visualization.chartType}
                data={execution.chartData as ChartDataPoint[]}
                dimensionField={visualization.dimensionField}
                metricField="count"
              />
            </div>
          </div>
        )}

        {/* Empty State */}
        {!execution.loading && execution.results && execution.results.length === 0 && (
          <div className="border border-[var(--sg-border)] rounded-lg p-12 bg-[var(--sg-bg-1)] text-center">
            <Info className="w-12 h-12 mx-auto mb-3 text-[var(--sg-text-muted)]" />
            <div className="text-sm text-[var(--sg-text-muted)]">
              Query returned no results. The data may have changed since this visualization was
              created.
            </div>
          </div>
        )}

        {/* Query Panel */}
        <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
          <button
            onClick={() => setShowQuery(!showQuery)}
            className="w-full flex items-center justify-between px-4 py-3 hover:bg-[var(--sg-bg-2)] transition-colors"
          >
            <div className="flex items-center gap-2">
              <Code className="w-4 h-4 text-[var(--sg-accent)]" />
              <span className="text-sm font-semibold text-[var(--sg-text)]">Underlying Query</span>
            </div>
            <svg
              className={`w-4 h-4 text-[var(--sg-text-muted)] transition-transform ${
                showQuery ? 'rotate-180' : ''
              }`}
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          {showQuery && (
            <div className="px-4 py-3 border-t border-[var(--sg-border)]">
              <pre className="text-xs font-mono text-[var(--sg-text)] bg-[var(--sg-bg-0)] px-3 py-2 rounded border border-[var(--sg-border)] overflow-x-auto">
                {visualization.query}
              </pre>
              <div className="mt-3 grid grid-cols-2 gap-3 text-xs">
                <div>
                  <div className="text-[var(--sg-text-muted)] mb-1">Dimension Field</div>
                  <div className="text-[var(--sg-text)] font-mono">
                    {visualization.dimensionField}
                  </div>
                </div>
                <div>
                  <div className="text-[var(--sg-text-muted)] mb-1">Metric Function</div>
                  <div className="text-[var(--sg-text)] font-mono">
                    {visualization.metricFunction}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Explain Panel */}
        <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)]">
          <button
            onClick={() => setShowExplain(!showExplain)}
            className="w-full flex items-center justify-between px-4 py-3 hover:bg-[var(--sg-bg-2)] transition-colors"
          >
            <div className="flex items-center gap-2">
              <Info className="w-4 h-4 text-[var(--sg-accent)]" />
              <span className="text-sm font-semibold text-[var(--sg-text)]">Explain Query</span>
            </div>
            <svg
              className={`w-4 h-4 text-[var(--sg-text-muted)] transition-transform ${
                showExplain ? 'rotate-180' : ''
              }`}
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          {showExplain && parsedQuery && (
            <div className="px-4 py-3 border-t border-[var(--sg-border)] space-y-3">
              <div>
                <div className="text-xs font-semibold text-[var(--sg-text)] mb-2">
                  SELECT Fields
                </div>
                <div className="text-xs font-mono text-[var(--sg-text-muted)]">
                  {parsedQuery.select.join(', ')}
                </div>
              </div>
              <div>
                <div className="text-xs font-semibold text-[var(--sg-text)] mb-2">FROM Table</div>
                <div className="text-xs font-mono text-[var(--sg-text-muted)]">
                  {parsedQuery.from}
                </div>
              </div>
              {parsedQuery.where && parsedQuery.where.length > 0 && (
                <div>
                  <div className="text-xs font-semibold text-[var(--sg-text)] mb-2">
                    WHERE Conditions
                  </div>
                  <div className="space-y-1">
                    {parsedQuery.where.map((condition: WhereCondition, idx: number) => (
                      <div key={idx} className="text-xs font-mono text-[var(--sg-text-muted)]">
                        {condition.field} {condition.operator} {String(condition.value)}
                      </div>
                    ))}
                  </div>
                </div>
              )}
              <div>
                <div className="text-xs font-semibold text-[var(--sg-text)] mb-2">
                  Q-String Translation
                </div>
                <div className="text-xs font-mono text-[var(--sg-text-muted)] break-all">
                  {parsedQuery.qString || '(empty)'}
                </div>
              </div>
              {execMql && (
                <div>
                  <div className="text-xs font-semibold text-[var(--sg-text)] mb-2">
                    Server-side aggregation (MQL)
                  </div>
                  <pre className="text-xs font-mono text-[var(--sg-text-muted)] whitespace-pre-wrap break-all">
                    {execMql}
                  </pre>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Add to Dashboard Dialog */}
      <AddVisualizationToDashboardDialog
        isOpen={showAddToDashboard}
        onClose={() => setShowAddToDashboard(false)}
        onAdd={handleAddToDashboards}
        visualizationId={visualizationId}
      />
    </div>
  );
}

export default function VisualizationViewerPage() {
  return (
    <Suspense fallback={
      <div className="h-full flex items-center justify-center">
        <div className="text-sm text-[var(--sg-text-muted)]">Loading visualization...</div>
      </div>
    }>
      <VisualizationViewer />
    </Suspense>
  );
}

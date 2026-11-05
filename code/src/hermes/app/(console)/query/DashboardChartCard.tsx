"use client";

import { useState, useEffect, useCallback } from 'react';
import { AlertCircle, Trash2, ExternalLink } from 'lucide-react';
import { useDeepLinkRouter } from '@/hooks';
import { savedVisualizationRepository, type SavedVisualization } from './savedVisualizationRepository';
import { loadChartData, ChartAggregationUnsupportedError } from '@/lib/analytics/loadChartData';
import { AnalyticsChart } from './AnalyticsChart';
import { type ChartDataPoint } from './analyticsUtils';

interface DashboardChartCardProps {
  visualizationId: string;
  stateId: string | null;
  onRemove?: (visualizationId: string) => void;
}

interface QueryExecutionState {
  loading: boolean;
  error: string | null;
  chartData: Record<string, unknown>[] | null;
}

export function DashboardChartCard({ visualizationId, stateId, onRemove }: DashboardChartCardProps) {
  const router = useDeepLinkRouter();
  const [visualization, setVisualization] = useState<SavedVisualization | null>(null);
  const [execution, setExecution] = useState<QueryExecutionState>({
    loading: true,
    error: null,
    chartData: null,
  });

  // Load visualization on mount
  useEffect(() => {
    const viz = savedVisualizationRepository.get(visualizationId);
    /* eslint-disable react-hooks/set-state-in-effect -- one-time load of the saved
       visualization from localStorage on mount; not derivable during render. */
    if (!viz) {
      setExecution({
        loading: false,
        error: 'Visualization not found',
        chartData: null,
      });
      return;
    }
    setVisualization(viz);
    /* eslint-enable react-hooks/set-state-in-effect */
  }, [visualizationId]);

  // Execute the saved query - COPIED FROM visualization/page.tsx
  const executeQuery = useCallback(async () => {
    if (!visualization || !stateId) {
      setExecution((prev) => ({
        ...prev,
        error: 'No state selected',
      }));
      return;
    }

    setExecution({
      loading: true,
      error: null,
      chartData: null,
    });

    try {
      // Aggregate server-side over the whole state (#1055) instead of counting a
      // capped client-side page.
      const { data } = await loadChartData({
        stateId,
        query: visualization.query,
        dimensionField: visualization.dimensionField,
      });

      setExecution({
        loading: false,
        error: null,
        chartData: data,
      });
    } catch (error: unknown) {
      setExecution({
        loading: false,
        error:
          error instanceof ChartAggregationUnsupportedError
            ? error.message
            : error instanceof Error
              ? error.message
              : 'Unknown error occurred',
        chartData: null,
      });
    }
  }, [visualization, stateId]);

  // Auto-execute query when visualization loads and state is available
  useEffect(() => {
    if (visualization && stateId && !execution.chartData) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- kicks off the async query when inputs are ready
      executeQuery();
    }
  }, [visualization, stateId, execution.chartData, executeQuery]);

  // Visualization not found
  if (!execution.loading && execution.error === 'Visualization not found') {
    return (
      <div className="border border-[var(--sg-border)] rounded-lg p-6 bg-[var(--sg-bg-1)]">
        <div className="flex items-center gap-2 text-[var(--sg-error)]">
          <AlertCircle className="w-5 h-5" />
          <span className="text-sm font-medium">Visualization not found</span>
        </div>
        <p className="text-xs text-[var(--sg-text-muted)] mt-2">
          ID: {visualizationId}
        </p>
        {onRemove && (
          <button
            onClick={() => onRemove(visualizationId)}
            className="mt-3 text-xs text-[var(--sg-accent)] hover:underline"
          >
            Remove from dashboard
          </button>
        )}
      </div>
    );
  }

  if (!visualization) {
    return (
      <div className="border border-[var(--sg-border)] rounded-lg p-6 bg-[var(--sg-bg-1)]">
        <div className="animate-pulse">
          <div className="h-4 bg-[var(--sg-bg-2)] rounded w-1/3 mb-2"></div>
          <div className="h-3 bg-[var(--sg-bg-2)] rounded w-2/3"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="border border-[var(--sg-border)] rounded-lg bg-[var(--sg-bg-1)] group">
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

        {/* Actions */}
        <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            {...router.nav(`/visualization?id=${visualizationId}`)}
            className="p-2 rounded hover:bg-[var(--sg-accent)]/10 transition-colors"
            title="Open in viewer"
          >
            <ExternalLink className="w-4 h-4 text-[var(--sg-accent)]" />
          </button>
          {onRemove && (
            <button
              onClick={() => {
                if (confirm(`Remove "${visualization.name}" from this dashboard?`)) {
                  onRemove(visualizationId);
                }
              }}
              className="p-2 rounded hover:bg-[var(--sg-error)]/10 transition-colors"
              title="Remove from dashboard"
            >
              <Trash2 className="w-4 h-4 text-[var(--sg-error)]" />
            </button>
          )}
        </div>
      </div>

      {/* Chart Area - COPIED FROM visualization/page.tsx */}
      <div className="px-6 pt-0 pb-6">
        {execution.loading && (
          <div className="flex items-center justify-center py-12">
            <div className="text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[var(--sg-accent)] mx-auto mb-3"></div>
              <div className="text-sm text-[var(--sg-text-muted)]">Loading chart...</div>
            </div>
          </div>
        )}

        {execution.error && (
          <div className="px-4 py-3 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
            <div className="flex items-start gap-2">
              <AlertCircle className="w-5 h-5 text-[var(--sg-error)] flex-shrink-0 mt-0.5" />
              <div>
                <div className="text-sm font-medium text-[var(--sg-error)] mb-1">
                  Failed to load chart
                </div>
                <div className="text-xs text-[var(--sg-error)]/80">{execution.error}</div>
              </div>
            </div>
          </div>
        )}

        {!execution.loading && !execution.error && execution.chartData && execution.chartData.length > 0 && (
          <div className="h-[400px]">
            <AnalyticsChart
              chartType={visualization.chartType}
              data={execution.chartData as ChartDataPoint[]}
              dimensionField={visualization.dimensionField}
              metricField="count"
            />
          </div>
        )}

        {!execution.loading && !execution.error && execution.chartData && execution.chartData.length === 0 && (
          <div className="text-center py-12">
            <div className="text-sm text-[var(--sg-text-muted)]">No data available</div>
          </div>
        )}
      </div>
    </div>
  );
}

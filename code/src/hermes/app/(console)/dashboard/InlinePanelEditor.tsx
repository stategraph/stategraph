"use client";

import { useState, useEffect, useRef, useCallback } from 'react';
import { X, Play, BarChart3, PieChart, TreePine, Plus, type LucideIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { executeMQL } from '@/lib/api/client';
import { AnalyticsChart } from '../query/AnalyticsChart';
import {
  transformToChartData,
  getAvailableDimensionFields,
  suggestChartType,
  type ChartType,
  type ChartDataPoint,
} from '../query/analyticsUtils';
import { savedVisualizationRepository } from '../query/savedVisualizationRepository';
import { useDashboards } from '../query/useDashboards';
import { useSavedQueries } from '../query/useSavedQueries';

interface InlinePanelEditorProps {
  dashboardId: string;
  onClose: () => void;
  onPanelCreated: (visualizationId: string) => void;
}

const CHART_TYPES: { value: ChartType; label: string; icon: LucideIcon }[] = [
  { value: 'bar', label: 'Bar Chart', icon: BarChart3 },
  { value: 'pie', label: 'Pie Chart', icon: PieChart },
  { value: 'treemap', label: 'Treemap', icon: TreePine },
];

export function InlinePanelEditor({ dashboardId, onClose, onPanelCreated }: InlinePanelEditorProps) {
  const { addVisualizationToDashboard } = useDashboards();
  const { savedQueries } = useSavedQueries();

  // Query state
  const [query, setQuery] = useState('');
  const [queryRunning, setQueryRunning] = useState(false);
  const [queryError, setQueryError] = useState<string | null>(null);
  const [results, setResults] = useState<Record<string, unknown>[] | null>(null);
  const [executionTime, setExecutionTime] = useState<number | null>(null);

  // Chart config state
  const [chartType, setChartType] = useState<ChartType>('bar');
  const [dimensionField, setDimensionField] = useState('');
  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);

  // Panel info state
  const [panelName, setPanelName] = useState('');
  const [panelDescription, setPanelDescription] = useState('');
  const [saveError, setSaveError] = useState<string | null>(null);

  const configInitializedRef = useRef(false);

  const availableFields = results ? getAvailableDimensionFields(results) : [];

  // Auto-initialize chart config when results arrive
  useEffect(() => {
    if (results && results.length > 0 && !configInitializedRef.current) {
      configInitializedRef.current = true;
      const fields = getAvailableDimensionFields(results);
      if (fields.length > 0) {
        const firstField = fields[0];
        const testData = transformToChartData(results, firstField);
        const suggested = suggestChartType(firstField, testData.length);
        setDimensionField(firstField);
        setChartType(suggested);
      }
    }
  }, [results]);

  // Recompute chart data when config changes
  useEffect(() => {
    if (results && results.length > 0 && dimensionField) {
      const data = transformToChartData(results, dimensionField);
      setChartData(data);
    } else {
      setChartData([]);
    }
  }, [results, dimensionField]);

  const handleRunQuery = useCallback(async () => {
    const trimmed = query.trim();
    if (!trimmed) return;

    setQueryRunning(true);
    setQueryError(null);
    setResults(null);
    setChartData([]);
    setExecutionTime(null);
    configInitializedRef.current = false;

    const startTime = performance.now();

    try {
      const response = await executeMQL(trimmed);
      const elapsed = performance.now() - startTime;
      setExecutionTime(elapsed);

      const data = response.data as Record<string, unknown>[];
      setResults(data);
    } catch (error: unknown) {
      setQueryError(error instanceof Error ? error.message : 'Query execution failed');
    } finally {
      setQueryRunning(false);
    }
  }, [query]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault();
      handleRunQuery();
    }
  };

  const handleAddToDashboard = () => {
    if (!panelName.trim()) {
      setSaveError('Please enter a panel name');
      return;
    }
    if (!dimensionField || chartData.length === 0) {
      setSaveError('Please run a query and configure the chart first');
      return;
    }

    setSaveError(null);

    // Save visualization
    const saved = savedVisualizationRepository.save({
      name: panelName.trim(),
      description: panelDescription.trim() || undefined,
      query: query.trim(),
      chartType,
      dimensionField,
      metricFunction: 'COUNT',
    });

    // Add to dashboard
    addVisualizationToDashboard(dashboardId, saved.id);

    onPanelCreated(saved.id);
  };

  const canAddToDashboard = panelName.trim() && dimensionField && chartData.length > 0;

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-[var(--sg-bg-0)]">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
        <h2 className="text-lg font-semibold text-[var(--sg-text)]">Create Panel</h2>
        <Button variant="ghost" size="sm" onClick={onClose}>
          <X className="w-4 h-4" />
        </Button>
      </div>

      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto px-6 py-6">
        <div className="max-w-4xl mx-auto space-y-6">
          {/* Query Section */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-sm font-semibold text-[var(--sg-text)]">
                SQL Query
              </label>
              {savedQueries.length > 0 && (
                <select
                  value=""
                  onChange={(e) => {
                    const sq = savedQueries.find(q => q.id === e.target.value);
                    if (sq) {
                      setQuery(sq.query);
                      if (!panelName) setPanelName(sq.name);
                      if (sq.description && !panelDescription) setPanelDescription(sq.description);
                    }
                  }}
                  className="px-2 py-1 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-xs focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                >
                  <option value="">Load saved query...</option>
                  {savedQueries.map((sq) => (
                    <option key={sq.id} value={sq.id}>{sq.name}</option>
                  ))}
                </select>
              )}
            </div>
            <textarea
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Enter SQL query... (e.g., select * from instances)"
              rows={3}
              className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm font-mono resize-y focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
              autoFocus
            />
            <div className="flex items-center gap-3">
              <Button
                onClick={handleRunQuery}
                disabled={!query.trim() || queryRunning}
                size="sm"
              >
                <Play className="w-4 h-4 mr-2" />
                {queryRunning ? 'Running...' : 'Run'}
              </Button>
              <span className="text-xs text-[var(--sg-text-dim)]">Ctrl+Enter to run</span>
              {results && executionTime !== null && (
                <span className="text-xs text-[var(--sg-text-muted)]">
                  {results.length} {results.length === 1 ? 'row' : 'rows'} in {(executionTime / 1000).toFixed(2)}s
                </span>
              )}
            </div>

            {/* Query error */}
            {queryError && (
              <div className="px-4 py-3 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
                <div className="text-sm text-[var(--sg-error)]">{queryError}</div>
              </div>
            )}
          </div>

          {/* Chart Config Section - visible after results */}
          {results && results.length > 0 && (
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-[var(--sg-text)]">Chart Configuration</h3>

              {/* Chart Type Selector */}
              <div>
                <label className="text-sm text-[var(--sg-text-muted)] block mb-2">
                  Chart Type
                </label>
                <div className="grid grid-cols-3 gap-3">
                  {CHART_TYPES.map((type) => {
                    const Icon = type.icon;
                    return (
                      <button
                        key={type.value}
                        onClick={() => setChartType(type.value)}
                        className={`flex flex-col items-center gap-2 p-4 rounded-lg border-2 transition-colors ${
                          chartType === type.value
                            ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                            : 'border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)]/50'
                        }`}
                      >
                        <Icon
                          className={`w-6 h-6 ${
                            chartType === type.value
                              ? 'text-[var(--sg-accent)]'
                              : 'text-[var(--sg-text-muted)]'
                          }`}
                        />
                        <span
                          className={`text-sm font-medium ${
                            chartType === type.value
                              ? 'text-[var(--sg-accent)]'
                              : 'text-[var(--sg-text)]'
                          }`}
                        >
                          {type.label}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Dimension Field Selector */}
              <div>
                <label className="text-sm text-[var(--sg-text-muted)] block mb-2">
                  Dimension Field
                  <span className="text-xs text-[var(--sg-text-dim)] ml-2">(Group by this field)</span>
                </label>
                {availableFields.length > 0 ? (
                  <select
                    value={dimensionField}
                    onChange={(e) => setDimensionField(e.target.value)}
                    className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                  >
                    <option value="">Select a field...</option>
                    {availableFields.map((field) => (
                      <option key={field} value={field}>{field}</option>
                    ))}
                  </select>
                ) : (
                  <div className="text-sm text-[var(--sg-text-muted)] italic">
                    No suitable fields found for visualization
                  </div>
                )}
              </div>

              {/* Metric Function */}
              <div>
                <label className="text-sm text-[var(--sg-text-muted)] block mb-2">
                  Metric Function
                </label>
                <div className="px-3 py-2 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm">
                  <span className="text-[var(--sg-text)] font-mono">COUNT</span>
                  <span className="text-[var(--sg-text-muted)] ml-2">(Count of occurrences per group)</span>
                </div>
              </div>
            </div>
          )}

          {/* Chart Preview - visible after config */}
          {chartData.length > 0 && (
            <div className="border border-[var(--sg-border)] rounded-lg p-4 bg-[var(--sg-bg-1)]">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-semibold text-[var(--sg-text)]">Preview</h3>
                <div className="text-xs text-[var(--sg-text-muted)]">
                  {chartData.length} unique {chartData.length === 1 ? 'value' : 'values'}
                </div>
              </div>
              <AnalyticsChart
                chartType={chartType}
                data={chartData}
                dimensionField={dimensionField}
                metricField="count"
              />
            </div>
          )}

          {/* Panel Info - visible after chart data */}
          {chartData.length > 0 && (
            <div className="space-y-4">
              <h3 className="text-sm font-semibold text-[var(--sg-text)]">Panel Info</h3>

              <div>
                <label className="text-sm text-[var(--sg-text-muted)] block mb-2">
                  Name <span className="text-[var(--sg-error)]">*</span>
                </label>
                <input
                  type="text"
                  value={panelName}
                  onChange={(e) => setPanelName(e.target.value)}
                  placeholder="e.g., Provider Distribution"
                  className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                />
              </div>

              <div>
                <label className="text-sm text-[var(--sg-text-muted)] block mb-2">
                  Description
                  <span className="text-xs text-[var(--sg-text-dim)] ml-2">(Optional)</span>
                </label>
                <textarea
                  value={panelDescription}
                  onChange={(e) => setPanelDescription(e.target.value)}
                  placeholder="e.g., Shows the distribution of resources across cloud providers"
                  rows={2}
                  className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                />
              </div>

              {/* Save error */}
              {saveError && (
                <div className="px-3 py-2 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
                  <div className="text-sm text-[var(--sg-error)]">{saveError}</div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
        <Button variant="outline" onClick={onClose}>
          Cancel
        </Button>
        <Button
          onClick={handleAddToDashboard}
          disabled={!canAddToDashboard}
        >
          <Plus className="w-4 h-4 mr-2" />
          Add to Dashboard
        </Button>
      </div>
    </div>
  );
}

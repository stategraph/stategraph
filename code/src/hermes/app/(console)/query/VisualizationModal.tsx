"use client";

import { useState, useEffect, useRef } from 'react';
import { X, BarChart3, PieChart, TreePine, Eye, Save, type LucideIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { AnalyticsChart } from './AnalyticsChart';
import {
  transformToChartData,
  getAvailableDimensionFields,
  validateVisualizationConfig,
  suggestChartType,
  type ChartType,
  type VisualizationConfig,
  type ChartDataPoint,
} from './analyticsUtils';
import { SaveVisualizationDialog } from './SaveVisualizationDialog';
import type { SavedVisualizationInput } from './savedVisualizationRepository';

interface VisualizationModalProps {
  results: Record<string, unknown>[];
  query: string;
  onClose: () => void;
  onSave?: (input: SavedVisualizationInput) => void;
}

const CHART_TYPES: { value: ChartType; label: string; icon: LucideIcon }[] = [
  { value: 'bar', label: 'Bar Chart', icon: BarChart3 },
  { value: 'pie', label: 'Pie Chart', icon: PieChart },
  { value: 'treemap', label: 'Treemap', icon: TreePine },
];

export function VisualizationModal({ results, query, onClose, onSave }: VisualizationModalProps) {
  const [config, setConfig] = useState<VisualizationConfig>({
    chartType: 'bar',
    dimensionField: '',
    metricFunction: 'COUNT',
  });

  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);
  const [showPreview, setShowPreview] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showSaveDialog, setShowSaveDialog] = useState(false);
  const initializedRef = useRef(false);

  const availableFields = getAvailableDimensionFields(results);

  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  // Auto-select first field if available (using useEffect with ref guard)
  useEffect(() => {
    if (availableFields.length > 0 && !config.dimensionField && !initializedRef.current) {
      initializedRef.current = true;
      const firstField = availableFields[0];
      const testData = transformToChartData(results, firstField);
      const suggestedType = suggestChartType(firstField, testData.length);

      // Use setTimeout to defer state update to next tick
      setTimeout(() => {
        setConfig((prev) => ({
          ...prev,
          dimensionField: firstField,
          chartType: suggestedType,
        }));
      }, 0);
    }
  }, [availableFields, results, config.dimensionField]);

  // Handle preview
  const handlePreview = () => {
    // Validate configuration
    const validation = validateVisualizationConfig(config, results);

    if (!validation.isValid) {
      setError(validation.error || 'Invalid configuration');
      return;
    }

    // Transform data
    const data = transformToChartData(results, config.dimensionField);

    if (data.length === 0) {
      setError('No data to visualize after grouping');
      return;
    }

    setChartData(data);
    setShowPreview(true);
    setError(null);
  };

  // Handle field change
  const handleFieldChange = (field: string) => {
    setConfig((prev) => ({ ...prev, dimensionField: field }));
    setShowPreview(false); // Reset preview when config changes
  };

  // Handle chart type change
  const handleChartTypeChange = (chartType: ChartType) => {
    setConfig((prev) => ({ ...prev, chartType }));
    setShowPreview(false); // Reset preview when config changes
  };

  // Handle save
  const handleSave = (saveInput: SavedVisualizationInput) => {
    // Validate that we have a valid configuration
    const validation = validateVisualizationConfig(config, results);
    if (!validation.isValid) {
      setError(validation.error || 'Invalid configuration');
      return;
    }

    // Merge the save dialog input with the full configuration
    const fullInput: SavedVisualizationInput = {
      ...saveInput,
      query,
      chartType: config.chartType,
      dimensionField: config.dimensionField,
      metricFunction: config.metricFunction,
    };

    // Call the parent's onSave handler
    if (onSave) {
      onSave(fullInput);
    }

    // Close the save dialog
    setShowSaveDialog(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded-lg shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[var(--sg-border)]">
          <div>
            <h2 className="text-lg font-semibold text-[var(--sg-text)]">Visualize Query Results</h2>
            <p className="text-sm text-[var(--sg-text-muted)] mt-1">
              Create a chart from your query results
            </p>
          </div>
          <Button variant="ghost" size="sm" onClick={onClose}>
            <X className="w-4 h-4" />
          </Button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          <div className="space-y-6">
            {/* Configuration Section */}
            <div className="space-y-4">
              {/* Chart Type Selector */}
              <div>
                <label className="text-sm font-semibold text-[var(--sg-text)] block mb-2">
                  Chart Type
                </label>
                <div className="grid grid-cols-3 gap-3">
                  {CHART_TYPES.map((type) => {
                    const Icon = type.icon;
                    return (
                      <button
                        key={type.value}
                        onClick={() => handleChartTypeChange(type.value)}
                        className={`flex flex-col items-center gap-2 p-4 rounded-lg border-2 transition-colors ${
                          config.chartType === type.value
                            ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                            : 'border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)]/50'
                        }`}
                      >
                        <Icon
                          className={`w-6 h-6 ${
                            config.chartType === type.value
                              ? 'text-[var(--sg-accent)]'
                              : 'text-[var(--sg-text-muted)]'
                          }`}
                        />
                        <span
                          className={`text-sm font-medium ${
                            config.chartType === type.value
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
                <label className="text-sm font-semibold text-[var(--sg-text)] block mb-2">
                  Dimension Field
                  <span className="text-xs text-[var(--sg-text-dim)] font-normal ml-2">
                    (Group by this field)
                  </span>
                </label>
                {availableFields.length > 0 ? (
                  <select
                    value={config.dimensionField}
                    onChange={(e) => handleFieldChange(e.target.value)}
                    className="w-full px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg text-[var(--sg-text)] text-sm focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)]"
                  >
                    <option value="">Select a field...</option>
                    {availableFields.map((field) => (
                      <option key={field} value={field}>
                        {field}
                      </option>
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
                <label className="text-sm font-semibold text-[var(--sg-text)] block mb-2">
                  Metric Function
                </label>
                <div className="px-3 py-2 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm">
                  <span className="text-[var(--sg-text)] font-mono">COUNT</span>
                  <span className="text-[var(--sg-text-muted)] ml-2">
                    (Count of occurrences per group)
                  </span>
                </div>
              </div>
            </div>

            {/* Error Message */}
            {error && (
              <div className="px-4 py-3 bg-[var(--sg-error)]/10 border border-[var(--sg-error)]/30 rounded-lg">
                <div className="text-sm text-[var(--sg-error)]">{error}</div>
              </div>
            )}

            {/* Preview Section */}
            {showPreview && chartData.length > 0 && (
              <div className="border border-[var(--sg-border)] rounded-lg p-4 bg-[var(--sg-bg-1)]">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-sm font-semibold text-[var(--sg-text)]">Preview</h3>
                  <div className="text-xs text-[var(--sg-text-muted)]">
                    {chartData.length} unique {chartData.length === 1 ? 'value' : 'values'}
                  </div>
                </div>
                <AnalyticsChart
                  chartType={config.chartType}
                  data={chartData}
                  dimensionField={config.dimensionField}
                  metricField="count"
                />
              </div>
            )}

            {/* Data Summary */}
            {showPreview && chartData.length > 0 && (
              <div className="border border-[var(--sg-border)] rounded-lg p-4 bg-[var(--sg-bg-1)]">
                <h3 className="text-sm font-semibold text-[var(--sg-text)] mb-3">Data Summary</h3>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <div className="text-[var(--sg-text-muted)]">Total Records</div>
                    <div className="text-lg font-semibold text-[var(--sg-text)]">{results.length}</div>
                  </div>
                  <div>
                    <div className="text-[var(--sg-text-muted)]">Unique Values</div>
                    <div className="text-lg font-semibold text-[var(--sg-text)]">{chartData.length}</div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-[var(--sg-border)]">
          <div>
            {showPreview && chartData.length > 0 && (
              <Button
                variant="outline"
                onClick={() => setShowSaveDialog(true)}
                disabled={!config.dimensionField}
              >
                <Save className="w-4 h-4 mr-2" />
                Save Visualization
              </Button>
            )}
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button
              onClick={handlePreview}
              disabled={!config.dimensionField || availableFields.length === 0}
            >
              <Eye className="w-4 h-4 mr-2" />
              Preview Chart
            </Button>
          </div>
        </div>
      </div>

      {/* Save Visualization Dialog */}
      <SaveVisualizationDialog
        isOpen={showSaveDialog}
        onClose={() => setShowSaveDialog(false)}
        onSave={handleSave}
      />
    </div>
  );
}

/**
 * Analytics Utilities for Query Result Visualization
 * Transforms query results into chart-ready data formats
 */

export interface ChartDataPoint {
  dimension: string;
  count: number;
  label?: string;
  [key: string]: unknown; // Allow additional properties for Recharts compatibility
}

export type ChartType = 'bar' | 'pie' | 'treemap';

export interface VisualizationConfig {
  chartType: ChartType;
  dimensionField: string;
  metricFunction: 'COUNT'; // Only COUNT for now
}

/**
 * Transform query results into chart data by grouping and counting
 */
export function transformToChartData(
  results: Record<string, unknown>[],
  dimensionField: string
): ChartDataPoint[] {
  if (!results || results.length === 0) {
    return [];
  }

  // Group by dimension field and count occurrences
  const groups = new Map<string, number>();

  results.forEach((row) => {
    const rawValue = row[dimensionField];

    // Handle null/undefined values and convert to string
    const value: string = (rawValue === null || rawValue === undefined)
      ? '(null)'
      : String(rawValue);

    groups.set(value, (groups.get(value) || 0) + 1);
  });

  // Convert to array and sort by count (descending)
  const chartData: ChartDataPoint[] = Array.from(groups.entries())
    .map(([dimension, count]) => ({
      dimension,
      count,
      label: dimension, // Label for display
    }))
    .sort((a, b) => b.count - a.count);

  return chartData;
}

/**
 * Get available dimension fields from results
 * Returns fields that are suitable for grouping (string-like values)
 */
export function getAvailableDimensionFields(results: Record<string, unknown>[]): string[] {
  if (!results || results.length === 0) {
    return [];
  }

  const firstRow = results[0];
  const fields = Object.keys(firstRow);

  // Filter out fields that are not suitable for dimensions
  // Keep: strings, numbers (they'll be converted to strings)
  // Exclude: objects, arrays, very long text fields
  return fields.filter((field) => {
    const value = firstRow[field];
    const type = typeof value;

    // Accept strings, numbers, booleans
    if (type === 'string' || type === 'number' || type === 'boolean') {
      // If string, check it's not too long (likely a description/blob)
      if (type === 'string' && typeof value === 'string' && value.length > 200) {
        return false;
      }
      return true;
    }

    return false;
  });
}

/**
 * Validate visualization configuration
 */
export function validateVisualizationConfig(
  config: VisualizationConfig,
  results: Record<string, unknown>[]
): { isValid: boolean; error?: string } {
  if (!config.dimensionField) {
    return { isValid: false, error: 'Please select a dimension field' };
  }

  if (!config.chartType) {
    return { isValid: false, error: 'Please select a chart type' };
  }

  if (results.length === 0) {
    return { isValid: false, error: 'No results to visualize' };
  }

  // Check if dimension field exists in results
  const firstRow = results[0];
  if (!(config.dimensionField in firstRow)) {
    return {
      isValid: false,
      error: `Field "${config.dimensionField}" not found in results`,
    };
  }

  return { isValid: true };
}

/**
 * Get suggested chart type based on data characteristics
 */
export function suggestChartType(
  dimensionField: string,
  uniqueValueCount: number
): ChartType {
  // If few unique values (< 10), pie chart works well
  if (uniqueValueCount <= 8) {
    return 'pie';
  }

  // If moderate number (< 30), bar chart
  if (uniqueValueCount <= 30) {
    return 'bar';
  }

  // Many values, treemap for hierarchy visualization
  return 'treemap';
}

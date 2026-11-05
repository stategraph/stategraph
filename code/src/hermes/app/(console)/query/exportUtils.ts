/**
 * Export utilities for Query results
 * Supports CSV and JSON export with proper formatting
 */

/**
 * Escape CSV value (handle quotes and commas)
 */
function escapeCSVValue(value: unknown): string {
  if (value === null || value === undefined) {
    return '';
  }

  const stringValue = String(value);

  // If value contains comma, quote, or newline, wrap in quotes and escape internal quotes
  if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
    return `"${stringValue.replace(/"/g, '""')}"`;
  }

  return stringValue;
}

/**
 * Convert results array to CSV string
 */
export function convertToCSV(results: Record<string, unknown>[]): string {
  if (results.length === 0) {
    return '';
  }

  // Get headers from first row
  const headers = Object.keys(results[0]);

  // Build CSV header row
  const headerRow = headers.map(escapeCSVValue).join(',');

  // Build data rows
  const dataRows = results.map(row => {
    return headers.map(header => escapeCSVValue(row[header])).join(',');
  });

  // Combine header and data
  return [headerRow, ...dataRows].join('\n');
}

/**
 * Convert results array to JSON with metadata
 */
export function convertToJSON(
  results: Record<string, unknown>[],
  query: string,
  executionTime: number | null
): string {
  const exportData = {
    metadata: {
      query,
      rowCount: results.length,
      executionTimeMs: executionTime,
      exportedAt: new Date().toISOString(),
    },
    results,
  };

  // Pretty-print with 2 spaces
  return JSON.stringify(exportData, null, 2);
}

/**
 * Download data as a file
 */
export function downloadFile(content: string, filename: string, mimeType: string): void {
  // Create blob
  const blob = new Blob([content], { type: mimeType });

  // Create download link
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;

  // Trigger download
  document.body.appendChild(link);
  link.click();

  // Cleanup
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Export results as CSV
 */
export function exportAsCSV(results: Record<string, unknown>[], baseFilename: string = 'query-results'): void {
  const csv = convertToCSV(results);
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filename = `${baseFilename}-${timestamp}.csv`;

  downloadFile(csv, filename, 'text/csv;charset=utf-8;');
}

/**
 * Export results as JSON
 */
export function exportAsJSON(
  results: Record<string, unknown>[],
  query: string,
  executionTime: number | null,
  baseFilename: string = 'query-results'
): void {
  const json = convertToJSON(results, query, executionTime);
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filename = `${baseFilename}-${timestamp}.json`;

  downloadFile(json, filename, 'application/json;charset=utf-8;');
}

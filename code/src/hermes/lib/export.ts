/**
 * Export utility functions for instances
 */

import { Instance } from './api/client';

/**
 * Export instances as CSV
 * Excludes _sensitive_attributes for security
 */
export function exportInstancesAsCSV(instances: Instance[]): void {
  if (instances.length === 0) {
    return;
  }

  // Define CSV headers
  const headers = [
    'address',
    'type',
    'provider',
    'module',
    'dependencies',
    'attributes',
  ];

  // Convert instances to CSV rows
  const rows = instances.map(instance => {
    const dependencies = instance.dependencies?.join('; ') || '';
    const attributes = instance.attributes
      ? JSON.stringify(instance.attributes)
      : '';

    return [
      escapeCSV(instance.address),
      escapeCSV(instance.type),
      escapeCSV(instance.provider),
      escapeCSV(instance.module || ''),
      escapeCSV(dependencies),
      escapeCSV(attributes),
    ];
  });

  // Build CSV content
  const csvContent = [
    headers.join(','),
    ...rows.map(row => row.join(',')),
  ].join('\n');

  // Download file
  downloadFile(csvContent, 'instances-export.csv', 'text/csv');
}

/**
 * Export instances as JSON
 * Excludes _sensitive_attributes for security
 */
export function exportInstancesAsJSON(instances: Instance[]): void {
  // Create a clean copy without sensitive attributes
  const cleanInstances = instances.map(instance => {
    const { _sensitive_attributes: _, ...cleanInstance } = instance as Instance & { _sensitive_attributes?: unknown };
    return cleanInstance;
  });

  const jsonContent = JSON.stringify(cleanInstances, null, 2);

  // Download file
  downloadFile(jsonContent, 'instances-export.json', 'application/json');
}

export type CsvCell = string | number | null | undefined;

/** Build a CSV string from a header row + data rows (every cell stringified + escaped). */
export function toCsv(headers: string[], rows: CsvCell[][]): string {
  const head = headers.map((h) => escapeCSV(h)).join(",");
  const body = rows
    .map((row) => row.map((cell) => escapeCSV(cell == null ? "" : String(cell))).join(","))
    .join("\n");
  return body ? `${head}\n${body}` : head;
}

/** Build a CSV from headers + rows and trigger a browser download. */
export function downloadCsv(filename: string, headers: string[], rows: CsvCell[][]): void {
  downloadFile(toCsv(headers, rows), filename, "text/csv");
}

/** `audit-2026-09-08T11-30-00.csv` — sortable download names that don't
 *  collide when the same export is saved twice. */
export function timestampedFilename(base: string, ext: string): string {
  const ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  return `${base}-${ts}.${ext}`;
}

/**
 * Escape CSV field value
 */
export function escapeCSV(value: string): string {
  if (value.includes(',') || value.includes('"') || value.includes('\n')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

/**
 * Trigger file download in browser
 */
export function downloadFile(content: string, filename: string, mimeType: string): void {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  // Revoking in the same task can cancel the download before it starts in
  // some browsers (older Safari), so give it a moment.
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

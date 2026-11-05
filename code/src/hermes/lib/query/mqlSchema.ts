/**
 * MQL Schema Definition
 *
 * Fetches schema from backend: GET /api/v1/mql/schema
 * Transforms API response to typed MQLTable[] format for UI consumption.
 */

import { getMQLSchema, type MQLSchemaResponse } from '@/lib/api/client';

export interface MQLColumn {
  name: string;
  type: string;
}

export interface MQLTable {
  name: string;
  columns: MQLColumn[];
}

/**
 * Transform API schema response to MQLTable[] format
 */
function transformSchema(response: MQLSchemaResponse): MQLTable[] {
  return Object.entries(response.tables).map(([tableName, tableData]) => ({
    name: tableName,
    columns: Object.entries(tableData.columns).map(([colName, colData]) => ({
      name: colName,
      type: colData.type,
    })),
  }));
}

/**
 * Fetch MQL schema from the API
 */
export async function fetchMQLSchema(): Promise<MQLTable[]> {
  const response = await getMQLSchema();
  return transformSchema(response);
}

/**
 * Get table by name from a schema
 */
export function getTable(schema: MQLTable[], name: string): MQLTable | undefined {
  return schema.find(t => t.name.toLowerCase() === name.toLowerCase());
}

/**
 * Get all table names from a schema
 */
export function getTableNames(schema: MQLTable[]): string[] {
  return schema.map(t => t.name);
}

/**
 * Get columns for a table from a schema
 */
export function getTableColumns(schema: MQLTable[], tableName: string): MQLColumn[] {
  const table = getTable(schema, tableName);
  return table?.columns || [];
}

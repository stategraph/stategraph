// Module data loader
// Fetches modules with pagination and filtering

import { getStateModules, executeMQL, Module } from '@/lib/api/client';
import { allStatesModulesQuery, rowToModule, type ModuleRow } from './mqlQueries';

// ============================================================================
// Types
// ============================================================================

export interface LoadModulesOptions {
  q?: string;
  limit?: number;
  page?: string[];
}

export interface ModulesData {
  modules: Module[];
  hasMore: boolean;
  nextPage?: string[];
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Parse a module path into segments for breadcrumb navigation.
 * Example: "module.submodule.child" -> ["module", "submodule", "child"]
 */
export function parseModulePath(path: string): string[] {
  if (!path || path === "root") return ["root"];
  return path.split(".");
}

/**
 * Build a module path from segments up to a given index.
 * Example: (["module", "submodule", "child"], 1) -> "module.submodule"
 */
export function buildModulePath(segments: string[], upToIndex: number): string {
  if (upToIndex === 0 && segments[0] === "root") return "root";
  return segments.slice(0, upToIndex + 1).join(".");
}

// ============================================================================
// Loader Functions
// ============================================================================

/**
 * Load modules from a state with pagination and search.
 *
 * @param stateId - The state ID to load modules from
 * @param options - Query options (search, pagination, limit)
 * @returns Modules data with pagination info
 */
export async function loadModules(
  stateId: string,
  options?: LoadModulesOptions
): Promise<ModulesData> {
  const response = await getStateModules(stateId, {
    limit: options?.limit,
    page: options?.page,
  });

  // Filter by search query if provided (client-side filtering)
  let modules = response.results;
  if (options?.q) {
    const query = options.q.toLowerCase();
    modules = modules.filter((module) =>
      module.name.toLowerCase().includes(query)
    );
  }

  // TODO: Detect if there are more results
  // The API doesn't currently return pagination metadata, so we assume
  // there might be more if we got exactly the limit number of results
  const hasMore = options?.limit ? modules.length >= options.limit : false;

  return {
    modules,
    hasMore,
    nextPage: undefined, // TODO: Extract from response when API supports it
  };
}

/**
 * Load every module across ALL of the tenant's states via a single aggregate
 * MQL query (#1073) — no per-state REST fan-out. Returns the complete tenant-
 * wide set (same module name in multiple states collapses to one row), so the
 * page can search over the full set and show a correct total (#1062). The
 * tenant scope comes from the authenticated MQL context.
 *
 * @returns Every module across all states, tenant-wide aggregate counts
 */
export async function loadAllModules(): Promise<Module[]> {
  const { data } = await executeMQL(allStatesModulesQuery());
  return (data as ModuleRow[]).map(rowToModule);
}

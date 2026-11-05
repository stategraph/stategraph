// Instance data loader
// Fetches instances with pagination and filtering

import { getStateInstances, Instance, InstanceAttributes, getInstanceBlastRadius, InstanceBlastRadiusResponse, getTenantStates, executeMQL } from '@/lib/api/client';
import { ensureTagQuery } from '@/lib/query';
import { parseLinkHeader, hasNextPage } from '@/lib/api/pagination';
import {
  slimInstancesQuery,
  slimInstancesAllStatesQuery,
  instanceAttributesQuery,
  instanceRowToInstance,
  PAGE_LIMIT,
  type InstanceRow,
  type InstanceAttributesRow,
} from './mqlQueries';

// ============================================================================
// Types
// ============================================================================

export interface LoadInstancesOptions {
  q?: string;
  limit?: number;
  page?: string[];
}

export interface InstancesData {
  instances: Instance[];
  hasMore: boolean;
  nextPage?: string[];
}

export interface FilterOptions {
  providers: string[];
  types: string[];
  modules: string[];
}

// ============================================================================
// Loader Functions
// ============================================================================

/**
 * Load instances from a state with pagination and search.
 *
 * @param stateId - The state ID to load instances from
 * @param options - Query options (search, pagination, limit)
 * @returns Instances data with pagination info
 */
export async function loadInstances(
  stateId: string,
  options?: LoadInstancesOptions
): Promise<InstancesData> {
  // Convert bare search terms to proper tag queries that search across all fields
  // e.g., "ecs_cluster" becomes "address:ecs_cluster OR type:ecs_cluster OR provider:ecs_cluster OR module:ecs_cluster"
  const normalizedQuery = options?.q ? ensureTagQuery(options.q) : undefined;

  const response = await getStateInstances(stateId, {
    q: normalizedQuery,
    limit: options?.limit || 100,
    page: options?.page,
  });

  // Parse Link header to extract pagination metadata
  const links = parseLinkHeader(response.linkHeader);

  return {
    instances: response.data.results,
    hasMore: hasNextPage(links),
    nextPage: links.next,
  };
}

/**
 * Load filter options (providers, types, and modules) from all instances in a state.
 *
 * @param stateId - The state ID to load filter options from
 * @returns Unique providers, types, and modules
 */
export async function loadFilterOptions(stateId: string): Promise<FilterOptions> {
  // Fetch all instances (no limit) to get unique values
  const response = await getStateInstances(stateId, {
    limit: 10000, // High limit to get all instances
  });

  const providers = new Set<string>();
  const types = new Set<string>();
  const modules = new Set<string>();

  response.data.results.forEach((instance) => {
    providers.add(instance.provider);
    types.add(instance.type);
    if (instance.module) {
      modules.add(instance.module);
    }
  });

  return {
    providers: Array.from(providers).sort(),
    types: Array.from(types).sort(),
    modules: Array.from(modules).sort(),
  };
}

/**
 * Load blast radius data for a specific instance.
 *
 * @param stateId - The state ID
 * @param instanceAddress - The instance address to analyze
 * @returns Blast radius response with dependent resources
 */
export async function loadBlastRadius(
  stateId: string,
  instanceAddress: string
): Promise<InstanceBlastRadiusResponse> {
  return await getInstanceBlastRadius(stateId, instanceAddress);
}

/**
 * Load ALL instances from every state in a tenant.
 * Returns every instance so the page component can paginate client-side.
 *
 * @param tenantId - The tenant ID to load instances from
 * @param options - Query options (search only — pagination is done client-side)
 * @returns All instances across all states
 */
export async function loadAllInstances(
  tenantId: string,
  options?: Pick<LoadInstancesOptions, 'q'>
): Promise<Instance[]> {
  const statesResponse = await getTenantStates(tenantId);
  const states = statesResponse.results;

  const normalizedQuery = options?.q ? ensureTagQuery(options.q) : undefined;

  const instancePromises = states.map(async (state) => {
    try {
      const response = await getStateInstances(state.id, {
        q: normalizedQuery,
        limit: 5000,
      });

      return response.data.results.map((instance) => ({
        ...instance,
        state_id: state.id,
        state_name: state.name,
      }));
    } catch (error) {
      console.error(`Failed to load instances from state ${state.id}:`, error);
      return [];
    }
  });

  const instanceArrays = await Promise.all(instancePromises);

  // Deduplicate by state_id + address
  const seen = new Set<string>();
  const allInstances = instanceArrays.flat().filter((instance) => {
    const key = `${instance.state_id}:${instance.address}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  allInstances.sort((a, b) => a.address.localeCompare(b.address));

  return allInstances;
}

/**
 * Load the COMPLETE instance set for one state via MQL with a SLIM attribute
 * projection (only the facet/region keys the UI reads), cursor-looping past the
 * 1000-row MQL page cap. ~14x smaller payload than the full-attributes load, so
 * facets/filters/counts run over the full set without the multi-second cost of
 * transferring and parsing every instance's full `attributes`.
 *
 * Full attributes for a single instance are fetched separately, on demand, via
 * `loadInstanceAttributes` when its detail drawer opens.
 *
 * @param stateId - The state to load instances from
 * @param stateName - Optional state name to thread onto each instance (all-states view)
 * @returns Every instance in the state, slim attributes only
 */
export async function loadStateInstancesSlim(
  stateId: string,
  stateName?: string
): Promise<Instance[]> {
  const all: Instance[] = [];
  let page: string[] | undefined = undefined;

  for (;;) {
    const { data, linkHeader } = await executeMQL(slimInstancesQuery(stateId), { page });
    const rows = data as InstanceRow[];
    for (const row of rows) {
      all.push(instanceRowToInstance(row, stateName));
    }

    const links = parseLinkHeader(linkHeader);
    if (rows.length < PAGE_LIMIT || !hasNextPage(links) || !links.next) break;
    page = links.next;
  }

  return all;
}

/**
 * Load the COMPLETE instance set for EVERY state in the tenant via the slim
 * projection, in a SINGLE cross-state paginated walk (#1073). Uses
 * `slimInstancesAllStatesQuery` — no per-state filter — and cursors the whole
 * tenant via the `(state_id, address)` keyset (the #1059 cursor), instead of
 * firing one request per state and concatenating. The tenant scope comes from
 * the authenticated MQL context, so no tenant id is needed. Full attributes are
 * still fetched on demand for the drawer via `loadInstanceAttributes`.
 *
 * @returns Every instance across all states, slim attributes only, sorted by address
 */
export async function loadAllInstancesSlim(): Promise<Instance[]> {
  const all: Instance[] = [];
  let page: string[] | undefined = undefined;

  for (;;) {
    const { data, linkHeader } = await executeMQL(slimInstancesAllStatesQuery(), { page });
    const rows = data as InstanceRow[];
    for (const row of rows) {
      all.push(instanceRowToInstance(row));
    }

    const links = parseLinkHeader(linkHeader);
    if (rows.length < PAGE_LIMIT || !hasNextPage(links) || !links.next) break;
    page = links.next;
  }

  // Keep address-sorted display order (the query returns state_id-major order).
  all.sort((a, b) => a.address.localeCompare(b.address));
  return all;
}

/**
 * Load the full `attributes` and `sensitive_attributes` for a single instance,
 * for the detail drawer (the slim whole-set load omits them).
 *
 * @param stateId - The state the instance belongs to
 * @param address - The instance address
 * @returns The full attribute maps (undefined when absent)
 */
export async function loadInstanceAttributes(
  stateId: string,
  address: string
): Promise<{ attributes?: InstanceAttributes; sensitive_attributes?: InstanceAttributes }> {
  const { data } = await executeMQL(instanceAttributesQuery(stateId, address));
  const row = (data as InstanceAttributesRow[])[0];
  return {
    attributes: row?.attributes ?? undefined,
    sensitive_attributes: row?.sensitive_attributes ?? undefined,
  };
}

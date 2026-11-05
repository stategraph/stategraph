import { executeMQL, type Instance } from "@/lib/api/client";
import { parseLinkHeader, hasNextPage } from "@/lib/api/pagination";
import {
  searchInstancesQuery,
  searchRowToInstance,
  SEARCH_PAGE_LIMIT,
  type SearchRow,
} from "./searchQuery";
import {
  filterOptionsQuery,
  MAX_FACET_VALUES,
  type FilterOptionsRow,
} from "./mqlQueries";

interface SearchData {
  instances: Instance[];
  totalCount: number;
  hasMore: boolean;
  /** Opaque MQL cursor for the next page (from the `Link` header). */
  nextPage?: string[];
  executionTime: number;
}

interface FilterOptions {
  providers: string[];
  types: string[];
  modules: string[];
}

/**
 * Distinct filter values across every live state, via a single MQL query.
 */
export async function loadAllFilterOptions(): Promise<FilterOptions> {
  return runFilterOptionsQuery(filterOptionsQuery());
}

/**
 * Execute a `/search` query via MQL. Single-state when `stateId` is given, else
 * ALL live states in one cursored query (replacing the old per-state fan-out).
 * The tag-DSL `q` is translated to an MQL WHERE (see `searchQuery.ts`);
 * pagination uses the opaque MQL cursor from the `Link` header.
 */
export async function executeSearch(
  stateId: string | undefined,
  q: string,
  page: string[] = [],
  limit: number = SEARCH_PAGE_LIMIT
): Promise<SearchData> {
  const startTime = performance.now();

  try {
    // No `tz`: the search projection has no timestamp columns, and passing tz
    // makes the MQL endpoint reject the query ("syntax error at or near $1").
    const result = await executeMQL(searchInstancesQuery(q, stateId, limit), {
      page: page.length > 0 ? page : undefined,
    });

    const rows = result.data as SearchRow[];
    const instances = rows.map(searchRowToInstance);
    const links = parseLinkHeader(result.linkHeader);
    const more = rows.length >= limit && hasNextPage(links) && !!links.next;

    return {
      instances,
      totalCount: instances.length,
      hasMore: more,
      nextPage: more ? links.next : undefined,
      executionTime: performance.now() - startTime,
    };
  } catch (error) {
    console.error("Search execution failed:", error);
    throw error;
  }
}

/**
 * Distinct filter values for a single state, via a single MQL query.
 *
 * @param stateId - The state to load filter options from
 */
export async function loadFilterOptions(
  stateId: string
): Promise<FilterOptions> {
  return runFilterOptionsQuery(filterOptionsQuery(stateId));
}

/**
 * Execute a filter-options MQL query and shape the single JSON-folded row into
 * `FilterOptions`. On any failure we log and return empty lists so the filter
 * dropdowns degrade gracefully rather than breaking the page.
 */
async function runFilterOptionsQuery(query: string): Promise<FilterOptions> {
  try {
    const result = await executeMQL(query);

    // The query folds each facet into a single JSON array (one result row) and
    // carries explicit per-facet limits, so the endpoint's default limit should
    // never engage. Warn if it does, since that would mean truncated options.
    if (result.defaultLimitApplied !== null) {
      console.warn(
        `[loadFilterOptions] Unexpected default limit (${result.defaultLimitApplied}) applied; filter options may be truncated.`
      );
    }

    const row = (result.data as FilterOptionsRow[])[0];
    const providers = row?.providers ?? [];
    const types = row?.types ?? [];
    const modules = row?.modules ?? [];

    if (
      providers.length === MAX_FACET_VALUES ||
      types.length === MAX_FACET_VALUES ||
      modules.length === MAX_FACET_VALUES
    ) {
      console.warn(
        `[loadFilterOptions] Hit MAX_FACET_VALUES (${MAX_FACET_VALUES}); some filter options may be omitted.`
      );
    }

    // The query orders each list, but json_agg over a CTE does not formally
    // guarantee row order; sort client-side to keep the dropdowns stable.
    return {
      providers: [...providers].sort(),
      types: [...types].sort(),
      modules: [...modules].sort(),
    };
  } catch (error) {
    console.error("Failed to load filter options:", error);
    return {
      providers: [],
      types: [],
      modules: [],
    };
  }
}

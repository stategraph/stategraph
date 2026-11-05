"use client";

import { useState, useMemo } from "react";
import { useSearchParams } from "next/navigation";
import type { DynamicFacetFilters } from "@/components/instances/DynamicFacetedFilters";

const SIMPLE_FACET_KEYS = ["provider", "type", "module", "region"] as const;
const TAG_PREFIX = "tag.";

/** Map from URL param key to DynamicFacetFilters field name. */
const PARAM_TO_FIELD: Record<string, keyof Omit<DynamicFacetFilters, "tags">> = {
  provider: "providers",
  type: "types",
  module: "modules",
  region: "regions",
};

/**
 * Hook that syncs `DynamicFacetFilters` to/from URL query params.
 *
 * URL encoding:
 *   Simple facets  → repeated params:  `?provider=aws&provider=gcp&type=s3_bucket`
 *   Tag facets     → prefixed params:  `?tag.Environment=prod&tag.Environment=staging`
 *
 * On mount (or navigation to the page), reads filters from the URL via
 * Next.js `useSearchParams()` — this is properly synced with the router
 * and available on the very first render after client-side navigation.
 *
 * Once the user modifies filters via the sidebar, local state takes over
 * and changes are written back to the URL via `history.replaceState`.
 */
export function useFacetFilters(): [DynamicFacetFilters, (filters: DynamicFacetFilters) => void] {
  const searchParams = useSearchParams();

  // Parse facets from Next.js router-synced search params
  const urlFilters = useMemo(() => parseFiltersFromParams(searchParams), [searchParams]);

  // Local user modifications (null = use URL-derived filters)
  const [localFilters, setLocalFilters] = useState<DynamicFacetFilters | null>(null);

  // Use URL filters when no local modifications exist
  const effectiveFilters = localFilters ?? urlFilters;

  function setFilters(next: DynamicFacetFilters) {
    setLocalFilters(next);
    writeFiltersToUrl(next);
  }

  return [effectiveFilters, setFilters];
}

/** Parse facet filters from URLSearchParams. */
function parseFiltersFromParams(params: URLSearchParams): DynamicFacetFilters {
  const filters: DynamicFacetFilters = {
    providers: new Set(),
    types: new Set(),
    modules: new Set(),
    tags: new Map(),
    regions: new Set(),
  };

  // Simple facets
  for (const paramKey of SIMPLE_FACET_KEYS) {
    const values = params.getAll(paramKey);
    if (values.length > 0) {
      const field = PARAM_TO_FIELD[paramKey];
      filters[field] = new Set(values);
    }
  }

  // Tag facets (tag.KeyName=value)
  for (const [key, value] of params.entries()) {
    if (key.startsWith(TAG_PREFIX)) {
      const tagKey = key.slice(TAG_PREFIX.length);
      if (!tagKey) continue;
      if (!filters.tags.has(tagKey)) {
        filters.tags.set(tagKey, new Set());
      }
      filters.tags.get(tagKey)!.add(value);
    }
  }

  return filters;
}

/** Write facet filters to the URL via history.replaceState (no navigation). */
function writeFiltersToUrl(filters: DynamicFacetFilters): void {
  if (typeof window === "undefined") return;

  const url = new URL(window.location.href);
  const params = url.searchParams;

  // Remove all existing facet params
  for (const key of SIMPLE_FACET_KEYS) {
    params.delete(key);
  }
  // Remove existing tag params
  const existingKeys = [...params.keys()];
  for (const key of existingKeys) {
    if (key.startsWith(TAG_PREFIX)) {
      params.delete(key);
    }
  }

  // Write simple facets
  for (const paramKey of SIMPLE_FACET_KEYS) {
    const field = PARAM_TO_FIELD[paramKey];
    for (const value of filters[field]) {
      params.append(paramKey, value);
    }
  }

  // Write tag facets
  for (const [tagKey, values] of filters.tags.entries()) {
    for (const value of values) {
      params.append(`${TAG_PREFIX}${tagKey}`, value);
    }
  }

  window.history.replaceState(null, "", url.pathname + url.search);
}

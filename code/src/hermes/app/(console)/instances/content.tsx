"use client";

import { useEffect, useState, useMemo } from 'react';
import { useSearchParams, usePathname } from 'next/navigation';
import { Instance } from '@/lib/api/client';
import { loadStateInstancesSlim, loadAllInstancesSlim, loadInstanceAttributes } from './loader';
import { useAuth } from '@/components/auth';
import { useStates, useTenant } from '@/contexts';
import { useDeepLinkRouter, useStateSelection, useFacetFilters, useIsMobile } from '@/hooks';
import { PageHeader } from '@/components/page/PageHeader';
import { Button } from '@/components/ui/button';
import { RefreshCw, Filter, Download } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { exportInstancesAsCSV, exportInstancesAsJSON } from '@/lib/export';
import {
  InventoryTable,
  ResourceDrawer,
  ColumnPicker,
  ViewSwitcher,
  PaginationControls,
} from '@/components/instances';
import {
  DynamicFacetedFilters,
  DynamicActiveFilters,
  type DynamicFacetFilters,
} from '@/components/instances/DynamicFacetedFilters';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  getProviderLabel,
  getTagValue,
  getLocation,
  loadColumnConfig,
  saveColumnConfig,
  type ColumnConfig,
  loadCurrentViewId,
  saveCurrentViewId,
  getViewById,
} from '@/lib/instances';
import { StateFilter } from '@/components/filters';

type InventoryView = 'all' | 'no_dependents';

export function InstancesContent() {
  const _searchParams = useSearchParams();
  const _router = useDeepLinkRouter();
  const _pathname = usePathname();
  const { isAuthenticated } = useAuth();
  const { states } = useStates();
  const { currentTenant } = useTenant();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";

  // Get the currently selected state object (null when "all")
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  // State
  const [inventoryView, setInventoryView] = useState<InventoryView>('all');
  const [instances, setInstances] = useState<Instance[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [totalInstanceCount, setTotalInstanceCount] = useState<number | null>(null);
  const [selectedInstance, setSelectedInstance] = useState<Instance | null>(null);
  const [selectedInstances, setSelectedInstances] = useState<Set<string>>(new Set());
  // Default the facets panel open on desktop (lg+) and closed on small screens,
  // where it renders as an overlay sheet. useIsMobile is SSR-safe (desktop
  // default on the server) and correct on the first client render.
  const isMobile = useIsMobile();
  const [showFilters, setShowFilters] = useState<boolean>(!isMobile);

  // Filters (dynamic, synced to URL params for deep linking)
  const [filters, setFilters] = useFacetFilters();

  // View management (persisted to localStorage)
  const [currentViewId, setCurrentViewId] = useState<string>(() => loadCurrentViewId());
  const [_viewUpdateTrigger, setViewUpdateTrigger] = useState(0);

  // Column configuration (driven by current view)
  const [columnConfig, setColumnConfig] = useState<ColumnConfig>(() => {
    const viewId = loadCurrentViewId();
    const view = getViewById(viewId);
    return view?.columnConfig || loadColumnConfig();
  });

  // Save view ID when it changes
  useEffect(() => {
    saveCurrentViewId(currentViewId);
  }, [currentViewId]);

  // Save column config when it changes
  useEffect(() => {
    saveColumnConfig(columnConfig);
  }, [columnConfig]);

  // Handle view change
  const handleViewChange = (viewId: string) => {
    const view = getViewById(viewId);
    if (view) {
      setCurrentViewId(viewId);
      setColumnConfig(view.columnConfig);
    }
  };

  // Handle view updates (when custom views are created/deleted)
  const handleViewsUpdated = () => {
    setViewUpdateTrigger((prev) => prev + 1);
  };

  // Pagination (client-side over the full loaded set)
  const PAGE_SIZE = 100;
  const [currentPage, setCurrentPage] = useState(1);
  // Bumped by the Refresh button to force a reload of the current scope.
  const [refreshKey, setRefreshKey] = useState(0);

  // Reset to the first page when scope, filters, or view change.
  useEffect(() => {
    setCurrentPage(1);
  }, [selectedStateId, filters, inventoryView]);

  // Load the COMPLETE instance set for the scope, then filter/paginate
  // client-side. Per-state cursors past the 1000-row cap; all-states loops per
  // state (see loader / #1059).
  useEffect(() => {
    if (!isAuthenticated || !currentTenant) return;
    if (!isAllStates && !currentState) return;

    let cancelled = false;

    async function fetchData() {
      setLoading(true);
      setError(null);

      try {
        const data = isAllStates
          ? await loadAllInstancesSlim()
          : await loadStateInstancesSlim(currentState!.id, currentState!.name);
        if (cancelled) return;

        setInstances(data);
        setTotalInstanceCount(data.length);
      } catch (e: unknown) {
        if (cancelled) return;
        const message = e instanceof Error ? e.message : 'Failed to load instances';
        setError(message);
        console.error('[InstancesPage] Error:', e);
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchData();

    return () => {
      cancelled = true;
    };
  }, [isAuthenticated, isAllStates, currentState, currentTenant, refreshKey]);

  // Apply filters client-side (dynamic tag-based filtering)
  const filteredInstances = useMemo(() => {
    let result = instances;

    if (filters.providers.size > 0) {
      result = result.filter(i => {
        const providerLabel = getProviderLabel(i.provider);
        return filters.providers.has(providerLabel);
      });
    }

    if (filters.types.size > 0) {
      result = result.filter(i => filters.types.has(i.type));
    }

    if (filters.modules.size > 0) {
      result = result.filter(i => i.module && filters.modules.has(i.module));
    }

    if (filters.regions.size > 0) {
      result = result.filter(i => {
        const region = getLocation(i);
        return region && filters.regions.has(region);
      });
    }

    if (filters.tags.size > 0) {
      result = result.filter(i => {
        for (const [tagKey, selectedValues] of filters.tags.entries()) {
          const instanceTagValue = getTagValue(i, tagKey);
          if (!instanceTagValue) return false;
          if (!selectedValues.has(instanceTagValue)) return false;
        }
        return true;
      });
    }

    return result;
  }, [instances, filters]);

  // Compute instances with no dependents (no inbound dependencies)
  const viewFilteredInstances = useMemo(() => {
    if (inventoryView === 'all') {
      return filteredInstances;
    }

    const inboundCounts = new Map<string, number>();
    filteredInstances.forEach(instance => {
      inboundCounts.set(instance.address, 0);
    });
    filteredInstances.forEach(instance => {
      if (instance.dependencies && Array.isArray(instance.dependencies)) {
        instance.dependencies.forEach(depAddress => {
          const currentCount = inboundCounts.get(depAddress) || 0;
          inboundCounts.set(depAddress, currentCount + 1);
        });
      }
    });

    return filteredInstances.filter(instance => {
      const count = inboundCounts.get(instance.address) || 0;
      return count === 0;
    });
  }, [filteredInstances, inventoryView]);

  // Client-side pagination over the full filtered set (same for both scopes).
  const totalFilteredCount = viewFilteredInstances.length;
  const totalPages = Math.max(1, Math.ceil(totalFilteredCount / PAGE_SIZE));

  const displayInstances = useMemo(() => {
    const start = (currentPage - 1) * PAGE_SIZE;
    return viewFilteredInstances.slice(start, start + PAGE_SIZE);
  }, [viewFilteredInstances, currentPage]);

  // Handlers
  const handleRefresh = () => {
    setCurrentPage(1);
    setRefreshKey((k) => k + 1);
  };

  const handleNextPage = () => {
    if (currentPage < totalPages) {
      setCurrentPage((prev) => prev + 1);
    }
  };

  const handlePreviousPage = () => {
    if (currentPage > 1) {
      setCurrentPage((prev) => prev - 1);
    }
  };

  const handleInstanceClick = async (instance: Instance) => {
    // Open immediately with the slim row (identity + facet attributes), then
    // fetch the full `attributes` on demand — the whole-set load omits them to
    // stay light, so the drawer pulls them per-instance when it opens.
    setSelectedInstance(instance);

    if (!instance.state_id) return;
    try {
      const { attributes, sensitive_attributes } = await loadInstanceAttributes(
        instance.state_id,
        instance.address
      );
      // Ignore if the user has since closed the drawer or opened a different row.
      setSelectedInstance((current) =>
        current && current.address === instance.address && current.state_id === instance.state_id
          ? { ...current, attributes: attributes ?? current.attributes, sensitive_attributes }
          : current
      );
    } catch (e) {
      console.error('[InstancesPage] Failed to load full attributes:', e);
    }
  };

  const handleCloseDrawer = () => {
    setSelectedInstance(null);
  };

  const handleRemoveFilter = (category: string, key: string, value: string) => {
    const next = { ...filters };

    if (category === 'tag') {
      // Remove tag filter
      const tags = new Map(next.tags);
      if (tags.has(key)) {
        const valueSet = new Set(tags.get(key)!);
        valueSet.delete(value);
        if (valueSet.size === 0) {
          tags.delete(key);
        } else {
          tags.set(key, valueSet);
        }
        next.tags = tags;
      }
    } else {
      // Remove resource/attribute filter
      const filterKey = key as keyof Omit<DynamicFacetFilters, 'tags'>;
      const set = new Set(next[filterKey]);
      set.delete(value);
      next[filterKey] = set as Set<string>;
    }

    setFilters(next);
  };

  const handleClearAllFilters = () => {
    setFilters({
      providers: new Set(),
      types: new Set(),
      modules: new Set(),
      tags: new Map(),
      regions: new Set(),
    });
  };

  // The whole-set load carries only slim (facet) attributes, so exports pull the
  // full `attributes` on demand for just the selected rows (a bounded set — the
  // user checks the boxes they want) before handing them to the exporters.
  const selectedWithFullAttributes = async (): Promise<Instance[]> => {
    const selected = instances.filter(instance => selectedInstances.has(instance.address));
    return Promise.all(
      selected.map(async (instance) => {
        if (!instance.state_id) return instance;
        try {
          const { attributes } = await loadInstanceAttributes(instance.state_id, instance.address);
          return attributes ? { ...instance, attributes } : instance;
        } catch (e) {
          console.error('[InstancesPage] Failed to load attributes for export:', e);
          return instance;
        }
      })
    );
  };

  const handleExportCSV = async () => {
    exportInstancesAsCSV(await selectedWithFullAttributes());
  };

  const handleExportJSON = async () => {
    exportInstancesAsJSON(await selectedWithFullAttributes());
  };

  return (
    <div className="flex h-full min-h-0 overflow-hidden">
      {/* Filters Sidebar - Dynamic facets, no hard-coded semantic fields.
          In-flow column on lg+, off-canvas overlay sheet below lg. */}
      {showFilters && (
        <>
          <div
            className="lg:hidden fixed inset-0 bg-black/30 z-40"
            onClick={() => setShowFilters(false)}
            aria-hidden="true"
          />
          <div className="fixed inset-y-0 left-0 z-50 w-72 max-w-[85vw] lg:static lg:z-auto lg:w-64 lg:max-w-none border-r border-[var(--sg-border)] bg-[var(--sg-bg-0)] overflow-y-auto flex-shrink-0">
            <div className="p-4">
              <DynamicFacetedFilters
                instances={instances}
                filters={filters}
                onFiltersChange={setFilters}
              />
            </div>
          </div>
        </>
      )}

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        {/* Header */}
        <PageHeader
          title="Resources"
          subtitle={
            selectedInstances.size > 0
              ? `${selectedInstances.size} resource${selectedInstances.size === 1 ? '' : 's'} selected`
              : totalInstanceCount !== null
              ? `${totalInstanceCount.toLocaleString()} resources`
              : `${totalFilteredCount.toLocaleString()} resources`
          }
        >
          <div className="flex flex-wrap gap-2">
            <StateFilter
              value={selectedStateId}
              onChange={setSelectedStateId}
              showAllOption
              className="min-w-[180px]"
            />
            {selectedInstances.size > 0 && (
              <>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="outline" size="sm">
                      <Download className="h-4 w-4 mr-2" />
                      Export
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={handleExportCSV}>
                      Export as CSV
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={handleExportJSON}>
                      Export as JSON
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setSelectedInstances(new Set())}
                >
                  Clear
                </Button>
              </>
            )}
            <ViewSwitcher
              currentViewId={currentViewId}
              onViewChange={handleViewChange}
              onViewsUpdated={handleViewsUpdated}
            />
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowFilters(!showFilters)}
            >
              <Filter className="h-4 w-4 mr-2" />
              {showFilters ? 'Hide' : 'Show'} Filters
            </Button>
            <ColumnPicker
              instances={instances}
              currentConfig={columnConfig}
              onConfigChange={setColumnConfig}
            />
            <Button
              variant="outline"
              size="sm"
              onClick={handleRefresh}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </Button>
          </div>
        </PageHeader>

        {/* Scope and View Controls */}
        <div className="flex-shrink-0 px-6 py-4 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)] space-y-3">
          {/* Scope, View, and Pagination */}
          <div className="flex flex-col gap-3 lg:flex-row lg:justify-between lg:items-center">
            <div className="flex gap-3">
              <Select value={inventoryView} onValueChange={(value) => setInventoryView(value as InventoryView)}>
                <SelectTrigger
                  size="sm"
                  className="w-[180px] gap-2"
                  style={{
                    background: "var(--sg-bg-2)",
                    borderColor: "var(--sg-border)",
                    color: "var(--sg-text)",
                  }}
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent
                  style={{
                    background: "var(--sg-bg-1)",
                    borderColor: "var(--sg-border)",
                    color: "var(--sg-text)",
                  }}
                >
                  <SelectItem value="all">
                    All
                  </SelectItem>
                  <SelectItem value="no_dependents">
                    No dependents
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Pagination Controls */}
            <PaginationControls
              currentPage={currentPage}
              hasNext={currentPage < totalPages}
              hasPrevious={currentPage > 1}
              onNext={handleNextPage}
              onPrevious={handlePreviousPage}
              totalResults={totalFilteredCount}
              totalPages={totalPages}
              pageSize={PAGE_SIZE}
              isLoading={loading}
            />
          </div>

          {/* View Description */}
          {inventoryView === 'no_dependents' && (
            <div className="px-3 py-2 bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded text-xs text-[var(--sg-text-muted)]">
              Resources that have no inbound dependencies within the current scope.
            </div>
          )}

          {/* Active Filters - Dynamic, no hard-coded fields */}
          <DynamicActiveFilters
            filters={filters}
            onRemove={handleRemoveFilter}
            onClearAll={handleClearAllFilters}
          />
        </div>

        {/* Error */}
        {error && (
          <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
            <div className="text-sm font-medium text-[var(--sg-error)] mb-1">
              Failed to load resources
            </div>
            <div className="text-sm text-[var(--sg-error)]">{error}</div>
          </div>
        )}

        {/* Table */}
        <div className="flex-1 overflow-y-auto px-6 py-4">
          <InventoryTable
            instances={displayInstances}
            selectedInstances={selectedInstances}
            onSelectionChange={setSelectedInstances}
            onInstanceClick={handleInstanceClick}
            isLoading={loading}
            searchScope={isAllStates ? 'all_states' : 'current_state'}
            columnConfig={columnConfig}
          />
        </div>

        {/* Pagination Controls */}
        <PaginationControls
          currentPage={currentPage}
          hasNext={currentPage < totalPages}
          hasPrevious={currentPage > 1}
          onNext={handleNextPage}
          onPrevious={handlePreviousPage}
          totalResults={totalFilteredCount}
          totalPages={totalPages}
          pageSize={PAGE_SIZE}
          isLoading={loading}
        />

      </div>

      {/* Detail Drawer */}
      <ResourceDrawer
        instance={selectedInstance}
        onClose={handleCloseDrawer}
      />
    </div>
  );
}

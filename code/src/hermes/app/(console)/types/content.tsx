"use client";

import { useState, useEffect, useMemo, useCallback } from 'react';
import { loadResourceTypes, loadAllResourceTypes, ResourceTypesData, filterResourceTypes } from './loader';
import { useAuth } from '@/components/auth';
import { useStates } from '@/contexts';
import { useStateSelection } from '@/hooks';
import { PageHeader } from '@/components/page/PageHeader';
import { Button } from '@/components/ui/button';
import { RefreshCw, Grid3x3, List, X } from 'lucide-react';
import {
  TypesGrid,
  TypesTable,
} from '@/components/types';
import { StateFilter } from '@/components/filters';

type ViewMode = 'grid' | 'table';

export function ResourceTypesContent() {
  const { isAuthenticated } = useAuth();
  const { states } = useStates();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  // State
  const [data, setData] = useState<ResourceTypesData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState<ViewMode>('grid');

  // Load data
  const loadData = useCallback(async () => {
    if (!isAllStates && !currentState) {
      setData(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const result = isAllStates
        ? await loadAllResourceTypes()
        : await loadResourceTypes(currentState!.id);
      setData(result);
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : 'Failed to load resource types';
      setError(message);
      console.error('[ResourceTypesPage] Error:', e);
    } finally {
      setLoading(false);
    }
  }, [isAllStates, currentState]);

  // Load on mount and when state changes
  useEffect(() => {
    if (isAuthenticated && (isAllStates || currentState)) {
      loadData();
    }
  }, [isAuthenticated, isAllStates, currentState, loadData]);

  // Filter types based on search query (client-side)
  const filteredTypes = useMemo(() => {
    if (!data) return [];
    return filterResourceTypes(data.types, searchQuery);
  }, [data, searchQuery]);

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <PageHeader
        title="Resource Types"
        subtitle="Browse all resource types across your Terraform state"
      >
        <div className="flex flex-wrap items-center gap-2">
          <StateFilter
            value={selectedStateId}
            onChange={setSelectedStateId}
            showAllOption
            className="min-w-[200px]"
          />
          {/* View Mode Toggle */}
          <div className="flex items-center gap-1 bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-1">
            <Button
              variant={viewMode === 'grid' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('grid')}
              className="h-8 px-3"
            >
              <Grid3x3 className="h-4 w-4" />
            </Button>
            <Button
              variant={viewMode === 'table' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('table')}
              className="h-8 px-3"
            >
              <List className="h-4 w-4" />
            </Button>
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={loadData}
            disabled={loading}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
      </PageHeader>

      {/* Search & Stats Bar */}
      <div className="flex-shrink-0 p-4 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)] space-y-3">
        <div className="relative">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search resource types by name..."
            className="w-full px-4 py-2.5 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent transition-colors"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>
        {data && !loading && (
          <div className="flex items-center gap-4 sg-metadata text-[var(--sg-text-dim)]">
            <div>
              <span className="font-semibold text-[var(--sg-text)]">
                {filteredTypes.length.toLocaleString()}
              </span>{' '}
              types
            </div>
            <div className="text-[var(--sg-text-dim)]">·</div>
            <div>
              <span className="font-semibold text-[var(--sg-text)]">
                {data.totalInstances.toLocaleString()}
              </span>{' '}
              resources
            </div>
          </div>
        )}
      </div>

      {/* Error */}
      {error && (
        <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
          <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
            Failed to load resource types
          </div>
          <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-4">
        {viewMode === 'grid' ? (
          <TypesGrid
            types={filteredTypes}
            isLoading={loading}
            searchQuery={searchQuery}
          />
        ) : (
          <TypesTable
            types={filteredTypes}
            isLoading={loading}
            searchQuery={searchQuery}
          />
        )}
      </div>
    </div>
  );
}

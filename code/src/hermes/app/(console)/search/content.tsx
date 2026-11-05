"use client";

import React, { useState, useEffect, useRef } from "react";
import { useStateSelection } from "@/hooks";
import { PageHeader, PageSection } from "@/components/page";
import { QueryBar } from "@/components/query";
import {
  SuggestedQueries,
  RecentQueries,
  EmptySearchState,
} from "@/components/search";
import { SearchResults } from "./SearchResults";
import { SearchTabs } from "./SearchTabs";
import { EnhancedFilterBar } from "./EnhancedFilterBar";
import { executeSearch, loadFilterOptions, loadAllFilterOptions } from "./loader";
import { useQueryState, useSavedQueries } from "@/hooks";
import { Instance } from "@/lib/api/client";
import { useInspector } from "@/components/inspector/InspectorContext";
import { useStates } from "@/contexts";
import { StateFilter } from "@/components/filters";
import { track } from "@/lib/analytics";

export function SearchContent() {
  const { q, page, limit, instance, setQueryState, resetPage: _resetPage } =
    useQueryState();
  const { recent, addToRecent, clearRecent } = useSavedQueries();
  const { openInspector } = useInspector();
  const { states } = useStates();

  // Per-page state selection (synced to URL ?state= param)
  const [selectedStateId, setSelectedStateId] = useStateSelection();

  const isAllStates = selectedStateId === "all";
  const currentState = isAllStates ? null : (states.find(s => s.id === selectedStateId) || null);

  // State
  const [instances, setInstances] = useState<Instance[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [executionTime, setExecutionTime] = useState<number | undefined>();
  const [providers, setProviders] = useState<string[]>([]);
  const [types, setTypes] = useState<string[]>([]);
  const [modules, setModules] = useState<string[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [searchMode, setSearchMode] = useState<"quick" | "filter">("quick");
  // MQL cursor pagination: `hasMore`/`nextPageCursor` come from the Link header;
  // `pageHistory` stacks prior cursors so Previous can walk back.
  const [hasMore, setHasMore] = useState(false);
  const [nextPageCursor, setNextPageCursor] = useState<string[] | undefined>(undefined);
  const [pageHistory, setPageHistory] = useState<string[][]>([]);

  // Abort controller for cancelling in-flight requests
  const abortControllerRef = useRef<AbortController | null>(null);

  // Load filter options when state is available
  useEffect(() => {
    if (!isAllStates && !currentState) return;

    const promise = isAllStates
      ? loadAllFilterOptions()
      : loadFilterOptions(currentState!.id);

    promise.then((options) => {
      setProviders(options.providers);
      setTypes(options.types);
      setModules(options.modules);
    });
  }, [isAllStates, currentState]);

  // Execute search when query or pagination changes
  useEffect(() => {
    if ((!isAllStates && !currentState) || !q) {
      // Defer state updates to avoid setState-in-effect warning
      setTimeout(() => {
        setInstances([]);
        setExecutionTime(undefined);
      }, 0);
      return;
    }

    // Cancel previous request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    abortControllerRef.current = new AbortController();

    // Defer setState to avoid synchronous setState in effect
    setTimeout(() => setIsLoading(true), 0);

    const searchPromise = executeSearch(
      isAllStates ? undefined : currentState!.id,
      q,
      page,
      limit
    );

    searchPromise
      .then((data) => {
        setInstances(data.instances);
        setExecutionTime(data.executionTime);
        setHasMore(data.hasMore);
        setNextPageCursor(data.nextPage);
        addToRecent(q);
        track("search_performed", {
          result_count: data.instances.length,
          has_more: data.hasMore,
          all_states: isAllStates,
        });
      })
      .catch((error) => {
        if (error.name !== "AbortError") {
          console.error("Search failed:", error);
        }
      })
      .finally(() => {
        setIsLoading(false);
      });

    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, [q, page, limit, isAllStates, currentState, states, addToRecent]);

  // Handle query change
  const handleQueryChange = (newQuery: string) => {
    setQueryState({ q: newQuery, page: [] });
    setCurrentPage(1);
    setPageHistory([]);
  };

  // Handle pagination (opaque MQL cursor + history stack)
  const handleNextPage = () => {
    if (hasMore && nextPageCursor) {
      setPageHistory((h) => [...h, page]);
      setQueryState({ page: nextPageCursor });
      setCurrentPage((prev) => prev + 1);
    }
  };

  const handlePreviousPage = () => {
    if (pageHistory.length > 0) {
      const prevCursor = pageHistory[pageHistory.length - 1];
      setPageHistory((h) => h.slice(0, -1));
      setQueryState({ page: prevCursor });
      setCurrentPage((prev) => Math.max(1, prev - 1));
    }
  };

  // Handle instance selection
  const handleSelectInstance = (selectedInstance: Instance) => {
    setQueryState({ instance: selectedInstance.address });
    openInspector({
      id: selectedInstance.address,
      address: selectedInstance.address,
      type: selectedInstance.type,
      provider: selectedInstance.provider,
      modulePath: selectedInstance.module,
      dependencyCount: selectedInstance.dependencies?.length || 0,
      dependentCount: 0, // Would need to fetch from blast radius
      instanceCount: 1,
    });
  };

  // Export JSON
  const handleExportJSON = () => {
    const dataStr = JSON.stringify(instances, null, 2);
    const blob = new Blob([dataStr], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `search-results-${Date.now()}.json`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const hasQuery = q.trim().length > 0;
  const hasResults = instances.length > 0;

  return (
    <>
      <PageHeader
        title="Search & Query"
        subtitle="Search Terraform resources across all modules, providers, and types"
      >
        <StateFilter
          value={selectedStateId}
          onChange={setSelectedStateId}
          showAllOption
          className="min-w-[200px]"
        />
      </PageHeader>

      <PageSection>
        {/* Search Tabs */}
        <SearchTabs activeTab={searchMode} onTabChange={setSearchMode} />

        {/* Search Interface */}
        <div className="mt-4">
          {searchMode === "quick" ? (
            <div className="space-y-4">
              <QueryBar q={q} onChange={handleQueryChange} autoFocus />
              <div className="text-sm text-[var(--sg-text-muted)]">
                💡 <strong>Tip:</strong> Try bare search terms like &ldquo;s3_bucket&rdquo;, or use tag syntax like{" "}
                <code className="px-1.5 py-0.5 bg-[var(--sg-bg-2)] rounded font-mono text-xs">
                  type:aws_s3_bucket
                </code>
              </div>
            </div>
          ) : (
            <EnhancedFilterBar
              q={q}
              onChange={handleQueryChange}
              providers={providers}
              types={types}
              modules={modules}
            />
          )}
        </div>

        {/* Results or Landing */}
        {hasQuery ? (
          hasResults || isLoading ? (
            <div className="mt-6">
              <SearchResults
                instances={instances}
                isLoading={isLoading}
                selectedInstance={instance}
                onSelectInstance={handleSelectInstance}
                resultCount={instances.length}
                executionTime={executionTime}
                currentQuery={q}
                currentPage={currentPage}
                hasNextPage={hasMore}
                hasPreviousPage={pageHistory.length > 0}
                onNextPage={handleNextPage}
                onPreviousPage={handlePreviousPage}
                onExportJSON={handleExportJSON}
              />
            </div>
          ) : (
            <div className="mt-6">
              <EmptySearchState hasQuery={true} />
            </div>
          )
        ) : (
          <div className="mt-8 space-y-8">
            {/* Suggested Queries */}
            <SuggestedQueries onSelectQuery={handleQueryChange} />

            {/* Recent Queries */}
            {recent.length > 0 && (
              <RecentQueries
                queries={recent}
                onSelectQuery={handleQueryChange}
                onClear={clearRecent}
              />
            )}

            {/* Empty State CTA */}
            {recent.length === 0 && <EmptySearchState hasQuery={false} />}
          </div>
        )}
      </PageSection>
    </>
  );
}

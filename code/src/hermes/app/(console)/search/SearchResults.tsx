"use client";

import React from "react";
import { Instance } from "@/lib/api/client";
import { InstanceTable } from "@/components/instances/InstanceTable";
import { PaginationControls } from "@/components/instances/PaginationControls";
import { SearchHeader } from "@/components/search";

interface SearchResultsProps {
  instances: Instance[];
  isLoading: boolean;
  selectedInstance: string | null;
  onSelectInstance: (instance: Instance) => void;
  resultCount: number;
  executionTime?: number;
  currentQuery: string;
  currentPage: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
  onNextPage: () => void;
  onPreviousPage: () => void;
  onExportJSON: () => void;
}

// Helper function to convert address string to selected instance
function getSelectedInstanceFromAddress(
  instances: Instance[],
  address: string | null
): Instance | null {
  if (!address) return null;
  return instances.find((i) => i.address === address) || null;
}

export function SearchResults({
  instances,
  isLoading,
  selectedInstance,
  onSelectInstance,
  resultCount,
  executionTime,
  currentQuery,
  currentPage,
  hasNextPage,
  hasPreviousPage,
  onNextPage,
  onPreviousPage,
  onExportJSON,
}: SearchResultsProps) {
  return (
    <div className="space-y-4">
      <SearchHeader
        resultCount={resultCount}
        executionTime={executionTime}
        currentQuery={currentQuery}
        onExportJSON={onExportJSON}
      />

      <InstanceTable
        instances={instances}
        onInstanceClick={onSelectInstance}
        selectedInstance={getSelectedInstanceFromAddress(
          instances,
          selectedInstance
        )}
        isLoading={isLoading}
      />

      {!isLoading && instances.length > 0 && (
        <PaginationControls
          currentPage={currentPage}
          hasNext={hasNextPage}
          hasPrevious={hasPreviousPage}
          onNext={onNextPage}
          onPrevious={onPreviousPage}
          totalResults={resultCount}
          isLoading={isLoading}
        />
      )}
    </div>
  );
}

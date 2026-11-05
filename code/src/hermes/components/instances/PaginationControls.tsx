"use client";

import { Button } from '@/components/ui/button';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface PaginationControlsProps {
  currentPage: number;
  hasNext: boolean;
  hasPrevious: boolean;
  onNext: () => void;
  onPrevious: () => void;
  totalResults?: number;
  totalPages?: number;
  pageSize?: number;
  isLoading?: boolean;
}

/**
 * PaginationControls - Next/Previous navigation for paginated results
 */
export function PaginationControls({
  currentPage,
  hasNext,
  hasPrevious,
  onNext,
  onPrevious,
  totalResults,
  totalPages,
  pageSize = 100,
  isLoading = false,
}: PaginationControlsProps) {
  // Compute range for current page
  const rangeStart = totalResults !== undefined && totalResults > 0
    ? (currentPage - 1) * pageSize + 1
    : 0;
  const rangeEnd = totalResults !== undefined
    ? Math.min(currentPage * pageSize, totalResults)
    : 0;

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 sm:gap-6 px-4 py-3 border-t border-[var(--sg-border)] bg-[var(--sg-bg-1)]">
      <div className="flex items-center gap-3">
        <div className="sg-metadata">
          {totalResults !== undefined && totalResults > 0 ? (
            <>
              {rangeStart.toLocaleString()}–{rangeEnd.toLocaleString()} of {totalResults.toLocaleString()}
              {totalPages !== undefined && totalPages > 1 && (
                <> · Page {currentPage} of {totalPages}</>
              )}
            </>
          ) : totalResults === 0 ? (
            'No results'
          ) : (
            `Page ${currentPage}`
          )}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={onPrevious}
          disabled={!hasPrevious || isLoading}
        >
          <ChevronLeft className="h-4 w-4 mr-1" />
          Previous
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={onNext}
          disabled={!hasNext || isLoading}
        >
          Next
          <ChevronRight className="h-4 w-4 ml-1" />
        </Button>
      </div>
    </div>
  );
}

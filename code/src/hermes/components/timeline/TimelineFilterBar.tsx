"use client";

import { X, Search } from "lucide-react";
import { Button } from "@/components/ui/button";

type StatusFilter = "all" | "completed" | "pending" | "aborted";

interface TimelineFilterBarProps {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  statusFilter: StatusFilter;
  onStatusFilterChange: (status: StatusFilter) => void;
  resourceFilter: string | null;
  onClearResourceFilter: () => void;
}

const STATUS_OPTIONS: { value: StatusFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "completed", label: "Completed" },
  { value: "pending", label: "Pending" },
  { value: "aborted", label: "Aborted" },
];

export function TimelineFilterBar({
  searchQuery,
  onSearchChange,
  statusFilter,
  onStatusFilterChange,
  resourceFilter,
  onClearResourceFilter,
}: TimelineFilterBarProps) {
  return (
    <div className="flex-shrink-0 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
      <div className="px-4 sm:px-6 py-3 flex flex-col sm:flex-row items-start sm:items-center gap-3">
        {/* Search input */}
        <div className="relative w-full sm:w-auto sm:flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[var(--sg-text-dim)]" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Search by user, date, state, status, tags..."
            className="w-full pl-9 pr-8 py-2 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg text-sm text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:border-transparent transition-colors"
          />
          {searchQuery && (
            <button
              onClick={() => onSearchChange("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>

        {/* Status filter segmented control */}
        <div className="flex items-center gap-0.5 bg-[var(--sg-bg-1)] rounded-lg border border-[var(--sg-border)] p-1">
          {STATUS_OPTIONS.map((option) => (
            <button
              key={option.value}
              onClick={() => onStatusFilterChange(option.value)}
              className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
                statusFilter === option.value
                  ? "bg-[var(--sg-accent-button)] text-white"
                  : "text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)]"
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {/* Resource filter banner */}
      {resourceFilter && (
        <div className="px-4 sm:px-6 pb-3">
          <div className="flex flex-wrap items-center gap-2 min-w-0">
            <span className="text-xs font-medium text-[var(--sg-text)]">
              Filtering by resource:
            </span>
            <span className="inline-flex items-center gap-1.5 max-w-full min-w-0 text-xs font-mono text-[var(--sg-accent)] bg-[var(--sg-accent-bg)] px-2.5 py-1 rounded-full border border-[var(--sg-border)]">
              <span className="break-all min-w-0">{resourceFilter}</span>
              <Button
                variant="ghost"
                size="sm"
                onClick={onClearResourceFilter}
                className="h-4 w-4 p-0 ml-0.5 hover:bg-transparent"
              >
                <X className="h-3 w-3" />
              </Button>
            </span>
          </div>
        </div>
      )}
    </div>
  );
}

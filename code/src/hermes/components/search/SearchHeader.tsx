"use client";

import React from "react";
import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";

interface SearchHeaderProps {
  resultCount: number;
  executionTime?: number;
  currentQuery: string;
  onExportJSON: () => void;
}

export function SearchHeader({
  resultCount,
  executionTime,
  currentQuery: _currentQuery,
  onExportJSON,
}: SearchHeaderProps) {
  return (
    <div className="flex items-center justify-between pb-4 border-b border-[var(--sg-border)]">
      <div className="flex flex-col gap-1">
        <h3 className="sg-secondary-header">
          {resultCount === 0
            ? "No results"
            : `Showing ${resultCount.toLocaleString()} result${
                resultCount === 1 ? "" : "s"
              }`}
        </h3>
        {executionTime !== undefined && (
          <p className="sg-metadata">
            Executed in {executionTime.toFixed(0)}ms
          </p>
        )}
      </div>

      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={onExportJSON}
          disabled={resultCount === 0}
          className="gap-1.5"
        >
          <Download className="h-3.5 w-3.5" />
          Export JSON
        </Button>
      </div>
    </div>
  );
}

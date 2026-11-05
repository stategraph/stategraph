"use client";

import React from "react";
import { Search, FileSearch } from "lucide-react";
import { DeepLink } from "@/components/navigation";

interface EmptySearchStateProps {
  hasQuery: boolean;
}

export function EmptySearchState({ hasQuery }: EmptySearchStateProps) {
  if (hasQuery) {
    // No results for query
    return (
      <div className="flex flex-col items-center justify-center py-16 px-4">
        <FileSearch className="h-12 w-12 text-[var(--sg-text-dim)] mb-4" />
        <h3 className="text-lg font-medium text-[var(--sg-text)] mb-2">
          No resources found
        </h3>
        <p className="sg-metadata text-center max-w-md mb-4">
          No resources match your query. Try adjusting your filters or search
          terms.
        </p>
        <div className="flex flex-col gap-2 text-xs text-[var(--sg-text-dim)]">
          <p>Try searching for:</p>
          <ul className="list-disc list-inside space-y-1 font-mono">
            <li>type:aws_s3_bucket</li>
            <li>type:aws_lambda_function</li>
            <li>module:networking</li>
          </ul>
        </div>
      </div>
    );
  }

  // Landing state (no query yet)
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4">
      <Search className="h-16 w-16 text-[var(--sg-text-dim)] mb-6" />
      <h3 className="text-xl font-medium text-[var(--sg-text)] mb-3">
        Search your infrastructure
      </h3>
      <p className="sg-card-text text-center max-w-lg mb-6">
        Use the search bar above to find resources across all modules,
        providers, and types. You can use tag syntax like{" "}
        <code className="text-xs font-mono text-[var(--sg-accent)] bg-[var(--sg-accent-bg)] px-1 py-0.5 rounded">
          type:aws_s3_bucket
        </code>{" "}
        or{" "}
        <code className="text-xs font-mono text-[var(--sg-accent)] bg-[var(--sg-accent-bg)] px-1 py-0.5 rounded">
          module:networking
        </code>{" "}
        to filter results.
      </p>
      <div className="flex gap-3">
        <DeepLink
          href="/instances"
          className="px-4 py-2 text-sm bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded hover:bg-[var(--sg-bg-1)] hover:border-[var(--sg-accent)] transition-colors"
        >
          Browse all resources
        </DeepLink>
      </div>
    </div>
  );
}

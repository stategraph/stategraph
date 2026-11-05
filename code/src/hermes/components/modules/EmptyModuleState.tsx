"use client";

import { Box, Search } from "lucide-react";

interface EmptyModuleStateProps {
  hasQuery?: boolean;
}

export function EmptyModuleState({ hasQuery = false }: EmptyModuleStateProps) {
  if (hasQuery) {
    return (
      <div className="flex flex-col items-center justify-center py-16 px-4">
        <Search className="h-12 w-12 text-[var(--sg-text-dim)] mb-4" />
        <h3 className="sg-secondary-header mb-2">No Modules Found</h3>
        <p className="sg-metadata text-[var(--sg-text-muted)] text-center max-w-md mb-4">
          No modules match your current filters. Try adjusting your search query.
        </p>
        <div className="bg-[var(--sg-bg-1)] rounded-lg p-4 border border-[var(--sg-border)]">
          <div className="sg-metadata text-[var(--sg-text-dim)] mb-2">Example queries:</div>
          <ul className="space-y-1 sg-metadata text-[var(--sg-text-muted)] font-mono">
            <li>• vpc</li>
            <li>• module:networking</li>
            <li>• services</li>
          </ul>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center py-16 px-4">
      <Box className="h-12 w-12 text-[var(--sg-text-dim)] mb-4" />
      <h3 className="sg-secondary-header mb-2">No Modules</h3>
      <p className="sg-metadata text-[var(--sg-text-muted)] text-center max-w-md">
        This state doesn&apos;t contain any Terraform modules yet.
      </p>
    </div>
  );
}

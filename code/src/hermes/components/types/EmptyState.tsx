import { Package } from 'lucide-react';

interface EmptyStateProps {
  searchQuery?: string;
}

/**
 * EmptyState - Display when no resource types match the filter
 */
export function EmptyState({ searchQuery }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <Package className="h-12 w-12 text-[var(--sg-text-dim)] mb-4" />
      <div className="sg-secondary-header text-[var(--sg-text-muted)] mb-2">
        {searchQuery ? 'No resource types found' : 'No resource types available'}
      </div>
      <div className="sg-metadata text-[var(--sg-text-dim)] max-w-md">
        {searchQuery
          ? `No resource types match "${searchQuery}". Try adjusting your search.`
          : 'Import a Terraform state to see your resource types.'}
      </div>
    </div>
  );
}

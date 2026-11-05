"use client";

import { ResourceTypeData } from '@/app/(console)/types/loader';
import { TypeCard, TypeCardSkeleton } from './TypeCard';
import { EmptyState } from './EmptyState';

interface TypesGridProps {
  types: ResourceTypeData[];
  isLoading?: boolean;
  searchQuery?: string;
}

/**
 * TypesGrid - Grid layout for resource type cards
 */
export function TypesGrid({ types, isLoading = false, searchQuery }: TypesGridProps) {
  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {Array.from({ length: 12 }).map((_, i) => (
          <TypeCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  if (types.length === 0) {
    return <EmptyState searchQuery={searchQuery} />;
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      {types.map((type) => (
        <TypeCard key={type.type} resourceType={type} />
      ))}
    </div>
  );
}

export function MetricCardSkeleton() {
  return (
    <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg p-4 sg-fade-in">
      {/* Label skeleton */}
      <div className="h-4 w-24 mb-2 sg-skeleton-shimmer"></div>

      {/* Value skeleton */}
      <div className="h-8 w-20 mb-1 sg-skeleton-shimmer"></div>

      {/* Subtitle skeleton */}
      <div className="h-3 w-16 mt-2 sg-skeleton-shimmer"></div>
    </div>
  );
}

/**
 * Grid of metric card skeletons - use during initial load
 */
export function MetricGridSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="grid grid-cols-3 gap-4">
      {Array.from({ length: count }).map((_, i) => (
        <MetricCardSkeleton key={i} />
      ))}
    </div>
  );
}

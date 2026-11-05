/**
 * Uniform Suspense fallback for console pages and tabbed hubs — one shape
 * instead of a hand-rolled div per wrapper.
 */
export function PageLoading({ label }: { label?: string }) {
  return (
    <div className="flex items-center justify-center min-h-[40vh] p-8 text-sm text-[var(--sg-text-muted)]">
      {label ? `Loading ${label}…` : "Loading…"}
    </div>
  );
}

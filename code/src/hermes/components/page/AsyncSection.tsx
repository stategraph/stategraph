'use client';

import { ReactNode } from 'react';

/**
 * The loading / error / empty / content quartet every list screen needs,
 * extracted from the hand-rolled per-page pattern (canonical copy was
 * app/(console)/types/page.tsx). Purely presentational: the caller owns the
 * fetch (useState/useCallback/useEffect or a loader), this renders the state.
 */
export function AsyncSection({
  loading,
  error,
  empty,
  emptyState,
  onRetry,
  children,
}: {
  loading: boolean;
  error: string | null;
  /** True when the load succeeded but there is nothing to show. */
  empty?: boolean;
  /** Rendered when [empty]; defaults to a muted notice. */
  emptyState?: ReactNode;
  onRetry?: () => void;
  children: ReactNode;
}) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="text-[var(--sg-text-muted)]">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-16 gap-3">
        <div className="text-[var(--sg-error)] text-center max-w-md">
          <div className="font-semibold mb-1">Failed to load</div>
          <div className="text-sm">{error}</div>
        </div>
        {onRetry && (
          <button
            type="button"
            onClick={onRetry}
            className="text-sm underline text-[var(--sg-text-muted)] hover:text-[var(--sg-text)]"
          >
            Retry
          </button>
        )}
      </div>
    );
  }

  if (empty) {
    return (
      <>{emptyState ?? <div className="py-16 text-center text-[var(--sg-text-muted)]">Nothing here yet.</div>}</>
    );
  }

  return <>{children}</>;
}

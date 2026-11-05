'use client';

import { ReactNode } from 'react';
import { useAuth } from '@/components/auth/AuthProvider';

/**
 * The two auth gate states every console page hand-rolled (canonical copy was
 * app/(console)/types/page.tsx): a centered "initializing" notice while the
 * session loads, the error card when unauthenticated, otherwise the page.
 */
export function AuthGuard({ children }: { children: ReactNode }) {
  const { isLoading, isAuthenticated, error } = useAuth();

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen">
        <div className="text-[var(--sg-text-muted)]">Initializing authentication...</div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen">
        <div className="text-[var(--sg-error)] text-center max-w-md">
          <div className="text-xl font-semibold mb-2">Authentication Required</div>
          <div className="text-sm mb-4">{error || 'Not authenticated'}</div>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}

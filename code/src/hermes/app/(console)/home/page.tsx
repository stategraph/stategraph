"use client";

import { useSearchParams } from 'next/navigation';
import { useEffect, Suspense } from 'react';

function RedirectComponent() {
  const searchParams = useSearchParams();

  useEffect(() => {
    // Preserve query parameters when redirecting to root
    const params = searchParams.toString();
    const redirectUrl = params
      ? `/?${params}`
      : '/';

    window.location.href = redirectUrl;
  }, [searchParams]);

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="text-[var(--sg-text-muted)]">Redirecting...</div>
    </div>
  );
}

export default function HomeLegacyRedirect() {
  return (
    <Suspense fallback={
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-[var(--sg-text-muted)]">Loading...</div>
      </div>
    }>
      <RedirectComponent />
    </Suspense>
  );
}

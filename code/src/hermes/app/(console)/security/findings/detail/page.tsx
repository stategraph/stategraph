"use client";

import { Suspense } from "react";

import { SecurityFindingDetailClient } from "./SecurityFindingDetailClient";

export default function SecurityFindingDetailPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading finding…
        </div>
      }
    >
      <SecurityFindingDetailClient />
    </Suspense>
  );
}

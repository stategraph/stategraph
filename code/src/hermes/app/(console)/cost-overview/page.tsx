"use client";

import { Suspense } from "react";

import { CostOverviewClient } from "./CostOverviewClient";

export default function CostOverviewPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading cost overview…
        </div>
      }
    >
      <CostOverviewClient />
    </Suspense>
  );
}

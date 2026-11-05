"use client";

import { Suspense } from "react";

import { CostAnalysisClient } from "./CostAnalysisClient";

export default function CostAnalysisPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading cost analysis…
        </div>
      }
    >
      <CostAnalysisClient />
    </Suspense>
  );
}

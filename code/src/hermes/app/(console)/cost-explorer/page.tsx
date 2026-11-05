"use client";

import { Suspense } from "react";

import { CostExplorerClient } from "./CostExplorerClient";

export default function CostExplorerPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading cost explorer…
        </div>
      }
    >
      <CostExplorerClient />
    </Suspense>
  );
}

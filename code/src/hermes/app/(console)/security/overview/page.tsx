"use client";

import { Suspense } from "react";

import { SecurityPostureClient } from "./SecurityPostureClient";

export default function SecurityOverviewPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading security posture…
        </div>
      }
    >
      <SecurityPostureClient />
    </Suspense>
  );
}

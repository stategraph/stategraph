"use client";

import { Suspense } from "react";

import { SecurityFindingsClient } from "./SecurityFindingsClient";

export default function SecurityFindingsPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading security findings…
        </div>
      }
    >
      <SecurityFindingsClient />
    </Suspense>
  );
}

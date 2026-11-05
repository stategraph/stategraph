"use client";

import { Suspense } from "react";
import { PlanDetailClient } from "./PlanDetailClient";

export default function RunDetailPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-[var(--sg-text-muted)]">Loading run…</div>
        </div>
      }
    >
      <PlanDetailClient />
    </Suspense>
  );
}

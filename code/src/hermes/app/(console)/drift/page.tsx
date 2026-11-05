"use client";

import { Suspense } from "react";
import { DriftContent } from "./content";

export default function DriftPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading drift…
        </div>
      }
    >
      <DriftContent />
    </Suspense>
  );
}

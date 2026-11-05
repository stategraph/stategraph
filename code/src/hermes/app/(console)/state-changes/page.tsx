"use client";

import { Suspense } from "react";
import { StateChangesContent } from "./content";

export default function StateChangesPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading state changes…
        </div>
      }
    >
      <StateChangesContent />
    </Suspense>
  );
}

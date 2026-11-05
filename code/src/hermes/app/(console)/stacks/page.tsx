"use client";

import { Suspense } from "react";
import { StacksContent } from "./content";

export default function StacksPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
          Loading stacks…
        </div>
      }
    >
      <StacksContent />
    </Suspense>
  );
}

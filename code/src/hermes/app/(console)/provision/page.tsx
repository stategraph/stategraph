"use client";

import { Suspense } from "react";
import { ProvisionClient } from "./ProvisionClient";

export default function ProvisionPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-[var(--sg-text-muted)]">Loading…</div>
        </div>
      }
    >
      <ProvisionClient />
    </Suspense>
  );
}

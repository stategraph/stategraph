"use client";

import { Suspense } from "react";
import { StateDetailsClient } from "./StateDetailsClient";

export default function StateDetailsPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center min-h-screen"><div className="text-[var(--sg-text-muted)]">Loading state details...</div></div>}>
      <StateDetailsClient />
    </Suspense>
  );
}

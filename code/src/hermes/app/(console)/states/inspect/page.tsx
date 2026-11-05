"use client";

import { Suspense } from "react";
import { StateInspectClient } from "./StateInspectClient";

export default function StateInspectPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center min-h-screen"><div className="text-[var(--sg-text-muted)]">Loading state file...</div></div>}>
      <StateInspectClient />
    </Suspense>
  );
}

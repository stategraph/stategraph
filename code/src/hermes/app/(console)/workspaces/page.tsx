"use client";

import { Suspense } from "react";
import { WorkspacesContent } from "./content";

export default function WorkspacesPage() {
  return (
    <Suspense fallback={<div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading…</div>}>
      <WorkspacesContent />
    </Suspense>
  );
}

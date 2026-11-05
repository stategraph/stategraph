"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { GraphExplorerContent } from "./content";

export default function Page() {
  return (
    <Suspense
      fallback={<PageLoading label="graph explorer" />}
    >
      <GraphExplorerContent />
    </Suspense>
  );
}

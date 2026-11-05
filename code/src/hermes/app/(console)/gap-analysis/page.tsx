"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { GapAnalysisContent } from "./content";

export default function GapAnalysisPage() {
  return (
    <Suspense
      fallback={<PageLoading label="gap analysis" />}
    >
      <GapAnalysisContent />
    </Suspense>
  );
}

"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { BlastRadiusContent } from "./content";

export default function Page() {
  return (
    <Suspense
      fallback={<PageLoading label="blast radius" />}
    >
      <BlastRadiusContent />
    </Suspense>
  );
}

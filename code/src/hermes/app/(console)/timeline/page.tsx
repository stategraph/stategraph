"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { TimelineContent } from "./content";

export default function Page() {
  return (
    <Suspense
      fallback={<PageLoading label="timeline" />}
    >
      <TimelineContent />
    </Suspense>
  );
}

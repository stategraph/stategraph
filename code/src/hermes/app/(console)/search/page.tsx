"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { SearchContent } from "./content";

export default function Page() {
  return (
    <Suspense
      fallback={<PageLoading label="search" />}
    >
      <SearchContent />
    </Suspense>
  );
}

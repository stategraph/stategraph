"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { QueryContent } from "./content";

export default function Page() {
  return (
    <Suspense
      fallback={<PageLoading label="query" />}
    >
      <AuthGuard>
        <QueryContent />
      </AuthGuard>
    </Suspense>
  );
}

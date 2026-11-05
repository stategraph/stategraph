"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { ModulesContent } from "./content";

export default function Page() {
  return (
    <Suspense
      fallback={<PageLoading label="modules" />}
    >
      <AuthGuard>
        <ModulesContent />
      </AuthGuard>
    </Suspense>
  );
}

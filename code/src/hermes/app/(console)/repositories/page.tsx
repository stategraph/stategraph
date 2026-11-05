"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { RepositoriesContent } from "./content";

export default function RepositoriesPage() {
  return (
    <Suspense fallback={<PageLoading label="repositories" />}>
      <AuthGuard>
        <RepositoriesContent />
      </AuthGuard>
    </Suspense>
  );
}

"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { AuditContent } from "./content";

export default function AuditPage() {
  return (
    <Suspense fallback={<PageLoading label="audit" />}>
      <AuthGuard>
        <AuditContent />
      </AuthGuard>
    </Suspense>
  );
}

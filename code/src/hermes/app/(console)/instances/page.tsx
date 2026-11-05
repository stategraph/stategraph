"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { InstancesContent } from "./content";

export default function InstancesPage() {
  return (
    <Suspense
      fallback={<PageLoading />}
    >
      <AuthGuard>
        <InstancesContent />
      </AuthGuard>
    </Suspense>
  );
}

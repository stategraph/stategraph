"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { AuthGuard } from "@/components/auth";
import { PullRequestsContent } from "./content";

export default function PullRequestsPage() {
  return (
    <Suspense fallback={<PageLoading label="pull requests" />}>
      <AuthGuard>
        <PullRequestsContent />
      </AuthGuard>
    </Suspense>
  );
}

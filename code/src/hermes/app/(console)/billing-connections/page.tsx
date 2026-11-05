"use client";

import { Suspense } from "react";
import { PageLoading } from "@/components/page";
import { BillingConnectionsContent } from "./content";

export default function BillingConnectionsPage() {
  return (
    <Suspense fallback={<PageLoading />}>
      <BillingConnectionsContent />
    </Suspense>
  );
}

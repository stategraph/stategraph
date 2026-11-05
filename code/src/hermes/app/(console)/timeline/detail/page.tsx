"use client";

import { Suspense } from "react";
import { TransactionDetailClient } from "./TransactionDetailClient";

export default function TransactionDetailPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-[var(--sg-text-muted)]">
            Loading transaction details...
          </div>
        </div>
      }
    >
      <TransactionDetailClient />
    </Suspense>
  );
}

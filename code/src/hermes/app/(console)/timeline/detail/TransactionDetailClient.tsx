"use client";

import { useEffect, useState, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useDeepLinkRouter } from "@/hooks";
import { useAuth, AuthGuard } from "@/components/auth";
import { useTenant } from "@/contexts/TenantContext";
import { Button } from "@/components/ui/button";
import { ArrowLeft, ArrowRight } from "lucide-react";
import { TransactionDetail } from "@/components/timeline";
import { executeMQL } from "@/lib/api/client";
import { transactionByIdQuery } from "../mqlQueries";
import type { TransactionRow } from "@/lib/timeline/types";

function TransactionDetailClientContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const txId = searchParams.get("tx") || "";
  const resourceFilter = searchParams.get("resource") || undefined;

  // Redirect if no tx param
  useEffect(() => {
    if (!txId) {
      router.push("/timeline");
    }
  }, [txId, router]);

  const { isAuthenticated } = useAuth();
  const { currentTenant } = useTenant();

  const [transaction, setTransaction] = useState<TransactionRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    if (!currentTenant || !txId) {
      setTransaction(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Look the transaction up by id directly, so it resolves even for
      // transactions past the old fetch window.
      const result = await executeMQL(transactionByIdQuery(txId));
      const tx = (result.data as TransactionRow[])[0];
      if (!tx) {
        throw new Error("Transaction not found");
      }
      setTransaction(tx);
    } catch (e: unknown) {
      const message =
        e instanceof Error ? e.message : "Failed to load transaction";
      setError(message);
      console.error("[TransactionDetailPage] Error:", e);
    } finally {
      setLoading(false);
    }
  }, [currentTenant, txId]);

  useEffect(() => {
    if (isAuthenticated && currentTenant && txId) {
      loadData();
    }
  }, [isAuthenticated, currentTenant, txId, loadData]);


  if (!currentTenant) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen">
        <div className="text-[var(--sg-text-muted)] text-center max-w-md">
          <div className="text-xl font-semibold mb-2">No Tenant Selected</div>
          <div className="text-sm mb-4">
            Please select a tenant from the dropdown in the sidebar.
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between w-full px-4 sm:px-6 py-4 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-3 min-w-0">
          <Button
            variant="ghost"
            size="sm"
            {...router.nav("/timeline")}
            className="h-8 w-8 p-0 shrink-0"
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="flex flex-col gap-1 min-w-0">
            <h1 className="text-xl sm:text-2xl font-semibold text-[var(--sg-text)]">
              Transaction Detail
            </h1>
            <p className="text-sm text-[var(--sg-text-muted)] font-mono break-all">
              {txId}
            </p>
          </div>
        </div>
        <Button
          variant="outline"
          size="sm"
          {...router.nav(`/runs/detail?tx=${txId}`)}
          className="shrink-0"
        >
          Run detail
          <ArrowRight className="h-4 w-4 ml-1" />
        </Button>
      </div>

      {/* Error */}
      {error && (
        <div className="mx-4 sm:mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
          <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
            Failed to load transaction
          </div>
          <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {loading && (
          <div className="flex items-center justify-center py-12">
            <div className="text-[var(--sg-text-muted)]">
              Loading transaction details...
            </div>
          </div>
        )}
        {!loading && transaction && (
          <TransactionDetail
            transaction={transaction}
            resourceFilter={resourceFilter}
          />
        )}
      </div>
    </div>
  );
}

export function TransactionDetailClient() {
  return (
    <AuthGuard>
      <TransactionDetailClientContent />
    </AuthGuard>
  );
}

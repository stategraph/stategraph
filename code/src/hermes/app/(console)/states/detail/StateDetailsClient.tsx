"use client";

import { Fragment, useEffect, useState, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import {
  useDeepLinkRouter,
  usePublishSelectedState,
  useCostAvailability,
  useStateCosts,
  useSecurityAvailability,
  useStateSecurityFindings,
} from "@/hooks";
import { DeepLink } from "@/components/navigation";
import { useAuth, AuthGuard } from "@/components/auth";
import { useTenant } from "@/contexts/TenantContext";
import { Button } from "@/components/ui/button";
import { ArrowLeft, ExternalLink } from "lucide-react";
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
} from "@/components/ui/card";
import { StatusBadge } from "@/components/states/StatusBadge";
import { SEVERITY_ORDER, SeverityBadge, ScanButton } from "@/components/security";
import {
  executeMQL,
  type Transaction,
  type StateSummary,
  type State,
} from "@/lib/api/client";
import {
  stateSummaryQuery,
  stateTransactionsQuery,
  stateByIdQuery,
  type StateSummaryRow,
} from "../mqlQueries";
import { stateToDetail, type StateDetail } from "@/lib/states/adapter";

function StateDetailsClientContent() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();
  const stateId = searchParams.get('id') || '';

  // Redirect if no ID provided
  useEffect(() => {
    if (!stateId) {
      router.push('/states');
    }
  }, [stateId, router]);

  // Keep this state selected when navigating onward (Graph Explorer / Blast
  // Radius), overriding any stale `state` carried in from a previous page.
  usePublishSelectedState(stateId);

  const { isAuthenticated } = useAuth();
  const { currentTenant } = useTenant();

  // Cost is woven in only when the server can price (capability-gated) AND this
  // particular state has a priced snapshot. Otherwise we show a disabled label
  // instead of a dead-end link. Probe the per-state snapshot only once the
  // capability flag has settled, so we never hit a server that can't price.
  const { capability: costCapability, isLoading: capabilityLoading } =
    useCostAvailability();
  const costSupported = costCapability?.enabled === true;
  const { costs, isLoading: costsLoading } = useStateCosts(
    !capabilityLoading && costSupported ? stateId : null
  );
  const stateHasCosts = (costs?.priced_count ?? 0) > 0;
  // 404 (never priced) and a zero-priced snapshot both resolve to "no costs".
  const costsChecked = !capabilityLoading && !costsLoading;

  // Findings link mirrors Cost Analysis: capability-gated, then probed per
  // state. Only a state whose latest scan still reports findings gets the link;
  // the rest get a disabled label. The summary endpoint 404s for never-scanned
  // states, which (like a clean scan, total = 0) resolves to "no findings".
  const { capability: securityCapability, isLoading: securityCapLoading } =
    useSecurityAvailability();
  const securitySupported = securityCapability?.enabled === true;
  const {
    summary: findingsSummary,
    isLoading: findingsLoading,
    refetch: refetchFindings,
  } = useStateSecurityFindings(
    !securityCapLoading && securitySupported ? stateId : null
  );
  const stateHasFindings = (findingsSummary?.total ?? 0) > 0;
  const findingsChecked = !securityCapLoading && !findingsLoading;
  // Severity breakdown for the table, severest first, omitting empty buckets.
  const severityRows = SEVERITY_ORDER.map((severity) => ({
    severity,
    count: findingsSummary?.severity_breakdown?.[severity] ?? 0,
  })).filter((row) => row.count > 0);

  // State
  const [detail, setDetail] = useState<StateDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load data
  const loadData = useCallback(async () => {
    if (!currentTenant || !stateId) {
      setDetail(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // State metadata, summary counts, and this state's transactions — all via
      // MQL, in parallel. The single-state lookup is a direct `where id = …`
      // query (fixes #1063: the old getTenantStates().find() searched only the
      // default-20 page and hard-failed past 20 states).
      const [stateResult, summaryResult, txResult] = await Promise.all([
        executeMQL(stateByIdQuery(stateId)),
        executeMQL(stateSummaryQuery(stateId)),
        executeMQL(stateTransactionsQuery(stateId)),
      ]);

      const state = (stateResult.data[0] ?? null) as State | null;
      if (!state) {
        throw new Error("State not found");
      }

      // Summary counts from MQL, shaped to the state-summary type.
      const summaryRow = (summaryResult.data[0] ?? {}) as StateSummaryRow;
      const summary: StateSummary = {
        instances: Number(summaryRow.instances ?? 0),
        resources: Number(summaryRow.resources ?? 0),
        providers: Number(summaryRow.providers ?? 0),
        modules: Number(summaryRow.modules ?? 0),
        edges: Number(summaryRow.edges ?? 0),
      };

      // Transactions are already scoped to this state (via transaction_logs.state_id)
      // and newest-first, so no client-side filtering is needed — this replaces the
      // buggy `tx.state === stateId` filter (tx.state is a status, not a state id).
      const stateTxs = txResult.data as Transaction[];

      // Transform to detail format
      const stateDetail = stateToDetail(state, summary, stateTxs);
      setDetail(stateDetail);
    } catch (e: unknown) {
      const message =
        e instanceof Error ? e.message : "Failed to load state details";
      setError(message);
      console.error("[StateDetailsPage] Error:", e);
    } finally {
      setLoading(false);
    }
  }, [currentTenant, stateId]);

  // Load on mount and when tenant/stateId changes
  useEffect(() => {
    if (isAuthenticated && currentTenant && stateId) {
      loadData();
    }
  }, [isAuthenticated, currentTenant, stateId, loadData]);

  // Format timestamp
  const formatTimestamp = (timestamp?: string) => {
    if (!timestamp) return "—";
    const date = new Date(timestamp);
    return date.toLocaleString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };


  // Show no tenant selected
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
      <div className="flex items-center justify-between w-full px-6 py-4 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-3 min-w-0">
          <Button
            variant="ghost"
            size="sm"
            {...router.nav("/states")}
            className="h-8 w-8 p-0 flex-shrink-0"
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="flex flex-col gap-1 min-w-0">
            <div className="flex items-center gap-3 flex-wrap min-w-0">
              <h1 className="text-2xl font-semibold text-[var(--sg-text)] break-words min-w-0">
                {detail?.name ?? "Loading..."}
              </h1>
              {detail && <StatusBadge status={detail.status} className="flex-shrink-0" />}
            </div>
            <p className="text-sm text-[var(--sg-text-muted)]">
              State details and activity
            </p>
          </div>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
          <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
            Failed to load state details
          </div>
          <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-4">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-[var(--sg-text-muted)]">
              Loading state details...
            </div>
          </div>
        ) : detail ? (
          <div className="space-y-6 max-w-5xl">
            {/* Summary Section */}
            <Card>
              <CardHeader>
                <CardTitle>Summary</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      Created
                    </div>
                    <div className="text-sm font-medium">
                      {formatTimestamp(detail.createdAt)}
                    </div>
                  </div>
                  {detail.importedAt && (
                    <div>
                      <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                        Imported
                      </div>
                      <div className="text-sm font-medium">
                        {formatTimestamp(detail.importedAt)}
                      </div>
                    </div>
                  )}
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      Source
                    </div>
                    <div className="text-sm font-medium">{detail.source}</div>
                  </div>
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      Resource count
                    </div>
                    <div className="text-sm font-medium">
                      {detail.resourceCount.toLocaleString()}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      Workspace
                    </div>
                    <div className="text-sm font-medium font-mono break-all">
                      {detail.context.workspace || "default"}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      Group ID
                    </div>
                    <div className="text-sm font-medium font-mono break-all">
                      {detail.context.groupId || "—"}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      State ID
                    </div>
                    <div className="text-sm font-medium font-mono break-all">
                      {stateId || "—"}
                    </div>
                  </div>
                  <div>
                    {stateHasCosts ? (
                      <DeepLink
                        href={`/cost-analysis?state=${stateId}`}
                        className="inline-flex items-center text-sm font-medium text-[var(--sg-accent)] hover:underline"
                      >
                        Costs Analysis
                      </DeepLink>
                    ) : (
                      <>
                        <div className="text-sm font-medium text-[var(--sg-text-dim)]">
                          Cost Analysis
                        </div>
                        {costsChecked && (
                          <div className="text-xs text-[var(--sg-text-dim)] mt-1">
                            No costs associated to this state
                          </div>
                        )}
                      </>
                    )}
                  </div>
                  <div>
                    <div className="text-sm text-[var(--sg-text-dim)] mb-1">
                      Security
                    </div>
                    {stateHasFindings ? (
                      <div className="space-y-2">
                        <div className="grid grid-cols-[auto_auto] items-center justify-start gap-x-6 gap-y-1 text-sm">
                          {severityRows.map((row) => (
                            <Fragment key={row.severity}>
                              <SeverityBadge severity={row.severity} />
                              <div className="text-left font-medium tabular-nums">
                                {row.count}
                              </div>
                            </Fragment>
                          ))}
                        </div>
                        <DeepLink
                          href={`/security/findings?state=${stateId}`}
                          className="inline-flex items-center text-sm font-medium text-[var(--sg-accent)] hover:underline"
                        >
                          Findings
                        </DeepLink>
                      </div>
                    ) : (
                      findingsChecked && (
                        <div className="text-sm font-medium text-[var(--sg-text-dim)]">
                          No security findings associated to this state
                        </div>
                      )
                    )}
                    {securitySupported && (
                      <ScanButton
                        stateId={stateId}
                        onDone={refetchFindings}
                        className="mt-3"
                      />
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Quick Links Section */}
            <Card>
              <CardHeader>
                <CardTitle>Explore this state</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <DeepLink
                    href={`/states/inspect?id=${stateId}`}
                    className="flex items-center justify-between p-3 rounded-lg border border-[var(--sg-border)] hover:bg-[var(--sg-bg-2)] transition-colors"
                  >
                    <span className="text-sm font-medium text-[var(--sg-text-dim)]">
                      Inspect state
                    </span>
                    <ExternalLink className="h-4 w-4 text-[var(--sg-text-dim)]" />
                  </DeepLink>
                </div>
              </CardContent>
            </Card>
          </div>
        ) : null}
      </div>
    </div>
  );
}

export function StateDetailsClient() {
  return (
    <AuthGuard>
      <StateDetailsClientContent />
    </AuthGuard>
  );
}

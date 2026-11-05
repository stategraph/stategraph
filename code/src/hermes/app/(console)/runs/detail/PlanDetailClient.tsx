"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ChevronLeft, ChevronRight, XCircle } from "lucide-react";
import { useTenant } from "@/contexts/TenantContext";
import { useDeepLinkRouter } from "@/hooks";
import { useUrlSyncedParam } from "@/hooks/useUrlSyncedParam";
import {
  DEFAULT_TAB,
  DestroyWarning,
  FailedRunHint,
  PlanApplyView,
  PlanCostView,
  PlanImpactView,
  PlanTabs,
  PlanTextView,
  PlanTreeView,
  StateChip,
  TAB_IDS,
  type PlanTab,
} from "@/components/plans";
import { formatAbsoluteTime, formatRelativeTime } from "@/lib/utils/time";
import { effectiveCounts } from "@/lib/plan/op-meta";
import { isAwaitingApply, isRunning } from "@/lib/plan/state";
import {
  abortTransaction,
  getTenantTransactions,
  getTenantStates,
  getTxDetail,
  getUserDetail,
  type State,
  type Transaction,
  type TxDetailResponse,
  type TxPlanOperation,
  type UserDetailResponse,
} from "@/lib/api/client";
import { loadTxOutput, loadTxPlanOperations } from "@/lib/tx/load";
import type { TxOutput } from "@/lib/tx/output";
import { track } from "@/lib/analytics";

// Window of recent runs we pull for prev/next nav. Outside this window the
// arrows just disable rather than firing extra requests per click. Kept
// small: it is fetched on every run-detail open purely to power the arrows.
const NAV_WINDOW = 50;

function isPlanTab(v: string): v is PlanTab {
  return (TAB_IDS as readonly string[]).includes(v);
}

export function PlanDetailClient() {
  const searchParams = useSearchParams();
  const router = useDeepLinkRouter();
  const { currentTenant } = useTenant();
  const planId = searchParams.get("tx") ?? "";

  const [detail, setDetail] = useState<TxDetailResponse | null>(null);
  const [planOperations, setPlanOperations] = useState<TxPlanOperation[] | null>(null);
  const [applyOutput, setApplyOutput] = useState<TxOutput | null>(null);
  const [creator, setCreator] = useState<UserDetailResponse | null>(null);
  const [states, setStates] = useState<State[] | null>(null);
  const [siblings, setSiblings] = useState<Transaction[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [aborting, setAborting] = useState(false);
  // The active tab lives in ?view= (absent for the default tab).
  const [viewParam, setActiveTab] = useUrlSyncedParam("view", DEFAULT_TAB);
  const activeTab: PlanTab = isPlanTab(viewParam) ? viewParam : DEFAULT_TAB;

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!planId) {
        setError("Missing ?tx= query parameter.");
        setLoading(false);
        return;
      }
      setLoading(true);
      setError(null);

      // States and the siblings window only depend on the tenant, so start
      // them in parallel with the detail fetch instead of waiting.
      const statesPromise = currentTenant
        ? getTenantStates(currentTenant.id)
            .then((r) => !cancelled && setStates(r.results))
            .catch(() => null)
        : Promise.resolve();
      const siblingsPromise = currentTenant
        ? getTenantTransactions(currentTenant.id, { limit: NAV_WINDOW })
            .then((r) => !cancelled && setSiblings(r.results))
            .catch(() => null)
        : Promise.resolve();

      try {
        const d = await getTxDetail(planId);
        if (cancelled) return;
        setDetail(d);

        // Creator needs the tx in hand; fire it now and wait alongside the
        // side fetches. The plan operations and the apply output are paged
        // companions of the detail, walked to completion here.
        const creatorPromise = getUserDetail(d.tx.created_by)
          .then((u) => !cancelled && setCreator(u))
          .catch(() => null);
        const opsPromise = loadTxPlanOperations(planId).then(
          (ops) => !cancelled && setPlanOperations(ops),
        );
        const outputPromise = loadTxOutput(planId).then(
          (o) => !cancelled && setApplyOutput(o),
        );
        await Promise.all([
          creatorPromise,
          statesPromise,
          siblingsPromise,
          opsPromise,
          outputPromise,
        ]);
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : "Failed to load run");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [planId, currentTenant]);

  const stateLabels = useMemo(() => {
    if (!detail || !states) return null;
    const byId = new Map(states.map((s) => [s.id, s.name]));
    return detail.state_ids.map((id) => byId.get(id) ?? id);
  }, [detail, states]);

  // Prev/next nav over the recent-runs window. Siblings come back DESC by
  // created_at, so index 0 is newest and "older" means a higher index.
  const { olderTxId, newerTxId } = useMemo(() => {
    if (!siblings) return { olderTxId: null, newerTxId: null };
    const idx = siblings.findIndex((t) => t.id === planId);
    if (idx < 0) return { olderTxId: null, newerTxId: null };
    return {
      olderTxId: idx < siblings.length - 1 ? siblings[idx + 1].id : null,
      newerTxId: idx > 0 ? siblings[idx - 1].id : null,
    };
  }, [siblings, planId]);

  const goToTx = useCallback(
    (txId: string) => {
      const qs = activeTab === DEFAULT_TAB ? "" : `&view=${activeTab}`;
      router.push(`/runs/detail?tx=${txId}${qs}`);
    },
    [router, activeTab],
  );

  const onAbort = useCallback(async () => {
    if (!detail) return;
    const ok = window.confirm(
      "Abort this run? In-flight terraform work will be interrupted.",
    );
    if (!ok) return;
    setAborting(true);
    try {
      const updated = await abortTransaction(detail.tx.id);
      track("run_aborted");
      setDetail({ ...detail, tx: updated });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to abort run");
    } finally {
      setAborting(false);
    }
  }, [detail]);

  const canAbort =
    detail !== null &&
    (isRunning(detail.tx) || isAwaitingApply(detail.tx));

  if (loading) {
    return <div className="p-8 text-[var(--sg-text-muted)]">Loading run…</div>;
  }
  if (error || !detail || !planOperations) {
    return (
      <div className="p-8 text-[var(--sg-error)]">{error ?? "Run not found"}</div>
    );
  }

  // Prefer terraform's own instance-level "Plan: N to add..." counts when
  // we have plan_stdout — they match the CLI output and what'll actually
  // happen at apply. The tx-level fields count at the resource-block level
  // (count=3 → 1 replace, not 3) and mislead users in count/for_each cases.
  const { adds, changes, destroys } = effectiveCounts(detail, planOperations);
  const creatorName = creator?.name ?? creator?.email ?? detail.tx.created_by;

  const tabContent: Record<PlanTab, React.ReactNode> = {
    tree: <PlanTreeView planOperations={planOperations} />,
    changes: <PlanTextView planOperations={planOperations} />,
    apply: <PlanApplyView detail={detail} applyOutput={applyOutput} />,
    impact: <PlanImpactView detail={detail} planOperations={planOperations} />,
    cost: <PlanCostView detail={detail} />,
  };

  return (
    <div className="flex flex-col h-full">
      <header className="px-6 pt-6 pb-4 border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-3 mb-2">
          <h1 className="text-lg font-semibold text-[var(--sg-text)]">Run</h1>
          <StateChip state={detail.tx.state} />
          <span className="text-xs font-mono text-[var(--sg-text-muted)]">
            {detail.tx.id}
          </span>
          <div className="ml-auto flex items-center gap-1">
            <button
              type="button"
              onClick={() => olderTxId && goToTx(olderTxId)}
              disabled={!olderTxId}
              title="Older run"
              aria-label="Older run"
              className="p-1 rounded hover:bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              type="button"
              onClick={() => newerTxId && goToTx(newerTxId)}
              disabled={!newerTxId}
              title="Newer run"
              aria-label="Newer run"
              className="p-1 rounded hover:bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
            {canAbort && (
              <button
                type="button"
                onClick={() => void onAbort()}
                disabled={aborting}
                title="Abort this run"
                className="ml-2 inline-flex items-center gap-1 px-2 py-1 text-xs rounded text-[var(--sg-error)] hover:bg-[var(--sg-error-bg)] disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
              >
                <XCircle className="w-3.5 h-3.5" />
                {aborting ? "Aborting…" : "Abort run"}
              </button>
            )}
          </div>
        </div>
        <div className="flex flex-wrap gap-x-6 gap-y-1 text-xs text-[var(--sg-text-muted)]">
          <span className="font-mono">
            Plan:{" "}
            <span className="text-[var(--sg-op-create)]">{adds} to add</span>,{" "}
            <span className="text-[var(--sg-op-update)]">{changes} to change</span>,{" "}
            <span className="text-[var(--sg-op-destroy)]">{destroys} to destroy</span>
          </span>
          <span>
            By{" "}
            <strong className="text-[var(--sg-text)]" title={detail.tx.created_by}>
              {creatorName}
            </strong>
          </span>
          <span title={formatAbsoluteTime(detail.tx.created_at)}>
            {formatRelativeTime(detail.tx.created_at)}
          </span>
          <span>
            On{" "}
            <strong className="text-[var(--sg-text)]">
              {stateLabels ? stateLabels.join(", ") : `${detail.state_ids.length} state${detail.state_ids.length === 1 ? "" : "s"}`}
            </strong>
          </span>
        </div>
        {(detail.tx.state === "failed" || detail.tx.state === "failed-committed") && (
          <FailedRunHint applyOutput={applyOutput} onJumpToTab={setActiveTab} />
        )}
        {destroys >= 1 && detail.tx.state !== "aborted" && (
          <DestroyWarning destroys={destroys} />
        )}
      </header>
      <div className="px-6">
        <PlanTabs activeTab={activeTab} onTabChange={setActiveTab} />
      </div>
      <div className="flex-1 overflow-auto">{tabContent[activeTab]}</div>
    </div>
  );
}

"use client";

import { useEffect, useState, useMemo, useCallback } from "react";
import { useDeepLinkRouter, useCostAvailability } from "@/hooks";
import { DeepLink } from "@/components/navigation";
import { useAuth, AuthGuard } from "@/components/auth";
import { useTenant } from "@/contexts/TenantContext";
import { useStates } from "@/contexts";
import { PageHeader } from "@/components/page/PageHeader";
import { Button } from "@/components/ui/button";
import {
  RefreshCw,
  ArrowUpDown,
  FileJson,
  Trash2,
  Download,
} from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { StatusBadge } from "@/components/states/StatusBadge";
import {
  getStateSummary,
  getAllStateInstances,
  getTenantCosts,
  deleteState,
  executeMQL,
  type State,
  type TenantCosts,
  type TenantCostState,
} from "@/lib/api/client";
import {
  stateToTableRow,
  sortTableRows,
  type StateTableRow,
} from "@/lib/states/adapter";
import { statesListQuery } from "@/contexts/mqlQueries";
import {
  statesOverviewQuery,
  MAX_STATES,
  type StateOverviewRow,
} from "./mqlQueries";
import { constructTerraformState } from "@/lib/states/inspector";
import { formatCurrency, parseCost } from "@/lib/cost/format";
import { track } from "@/lib/analytics";

type SortColumn = "name" | "resourceCount" | "lastTransaction";
type SortDirection = "asc" | "desc";

function StatesPageContent() {
  const router = useDeepLinkRouter();
  const { isAuthenticated } = useAuth();
  const { currentTenant } = useTenant();
  const { refreshStates } = useStates();

  // State
  const [tableRows, setTableRows] = useState<StateTableRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sortColumn, setSortColumn] = useState<SortColumn>("name");
  const [sortDirection, setSortDirection] = useState<SortDirection>("asc");

  // Cost is woven in only when the server can price (gated on the capability).
  // We pull the tenant rollup once and index its per-state rows by state id.
  const { capability: costCapability } = useCostAvailability();
  const costSupported = costCapability?.enabled === true;
  const [costData, setCostData] = useState<TenantCosts | null>(null);
  const costByState = useMemo(
    () => new Map<string, TenantCostState>((costData?.states ?? []).map((s) => [s.state_id, s])),
    [costData]
  );
  // tenant-cost-state carries no currency of its own; use the rollup's (empty
  // string -> bare number for the mixed-currency case).
  const costCurrency = costData?.currency ?? "";
  const totalMonthly = parseCost(costData?.monthly_cost);

  // Multi-select
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  const toggleSelect = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAll = () => {
    if (selectedIds.size === sortedRows.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(sortedRows.map((r) => r.id)));
    }
  };

  const selectedRows = useMemo(
    () => tableRows.filter((r) => selectedIds.has(r.id)),
    [tableRows, selectedIds]
  );

  // Load data
  const loadData = useCallback(async () => {
    if (!currentTenant) {
      setTableRows([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // One MQL query returns per-state aggregates + the most-recent transaction
      // for every live state, replacing the old N+1 getStateSummary fan-out and
      // the buggy getTenantTransactions grouping (which keyed on tx.state — a
      // status, not a state id — so every row showed "No recorded activity").
      // The full State objects (name / workspace / group_id, and the raw object
      // the download path needs) and the overview aggregates both come from MQL.
      const [statesResult, overviewResult] = await Promise.all([
        executeMQL(statesListQuery(currentTenant.id)),
        executeMQL(statesOverviewQuery(currentTenant.id)),
      ]);
      const states = statesResult.data as State[];

      // The query carries an explicit LIMIT, so the endpoint default should
      // never engage; warn if it does, since states would then be missing.
      if (overviewResult.defaultLimitApplied !== null) {
        console.warn(
          `[StatesPage] Unexpected default limit (${overviewResult.defaultLimitApplied}) applied; some states may be missing.`
        );
      }
      const overviewRows = overviewResult.data as StateOverviewRow[];
      if (overviewRows.length === MAX_STATES) {
        console.warn(
          `[StatesPage] Hit MAX_STATES (${MAX_STATES}); some states may be omitted.`
        );
      }
      const overviewByState = new Map(
        overviewRows.map((r) => [r.state_id, r])
      );

      // Transform to table rows (states with no aggregate row -> zero counts).
      const rows = states.map((state) =>
        stateToTableRow(state, overviewByState.get(state.id))
      );

      setTableRows(rows);
      setSelectedIds(new Set());
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : "Failed to load states";
      setError(message);
      console.error("[StatesPage] Error:", e);
    } finally {
      setLoading(false);
    }
  }, [currentTenant]);

  // Load on mount and when tenant changes
  useEffect(() => {
    if (isAuthenticated && currentTenant) {
      loadData();
    }
  }, [isAuthenticated, currentTenant, loadData]);

  // Pull the tenant cost rollup for the cost column (capability-gated).
  useEffect(() => {
    const tenant = currentTenant;
    if (!tenant || !isAuthenticated || !costSupported) {
      setCostData(null);
      return;
    }
    let cancelled = false;
    async function loadCosts(tenantId: string) {
      try {
        const res = await getTenantCosts(tenantId);
        if (!cancelled) setCostData(res);
      } catch {
        if (!cancelled) setCostData(null);
      }
    }
    loadCosts(tenant.id);
    return () => {
      cancelled = true;
    };
  }, [isAuthenticated, currentTenant, costSupported]);

  // Sort rows
  const sortedRows = useMemo(() => {
    return sortTableRows(tableRows, sortColumn, sortDirection);
  }, [tableRows, sortColumn, sortDirection]);

  // Handle sort
  const handleSort = (column: SortColumn) => {
    if (column === sortColumn) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(column);
      setSortDirection("asc");
    }
  };

  // ---- Delete state ----
  const [deleteTargets, setDeleteTargets] = useState<StateTableRow[]>([]);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleteConfirmText, setDeleteConfirmText] = useState("");

  const deletePromptText = deleteTargets.length === 1
    ? deleteTargets[0].name
    : `delete ${deleteTargets.length} states`;

  const deleteConfirmed = deleteTargets.length > 0 && deleteConfirmText === deletePromptText;

  const openDeleteDialog = (rows: StateTableRow[]) => {
    setDeleteTargets(rows);
    setDeleteError(null);
    setDeleteConfirmText("");
  };

  const handleDeleteConfirm = async () => {
    if (!deleteConfirmed) return;
    setDeleting(true);
    setDeleteError(null);
    try {
      await Promise.all(deleteTargets.map((t) => deleteState(t.id)));
      track("states_deleted", { count: deleteTargets.length });
      setDeleteTargets([]);
      setSelectedIds(new Set());
      loadData();
      refreshStates();
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : "Failed to delete state(s)";
      setDeleteError(message);
    } finally {
      setDeleting(false);
    }
  };

  // ---- Download state ----
  const [downloading, setDownloading] = useState(false);

  const handleDownload = async (rows: StateTableRow[]) => {
    if (!currentTenant) return;
    setDownloading(true);
    try {
      // Fetch states list to get full state objects
      const statesResult = await executeMQL(statesListQuery(currentTenant.id));
      const statesMap = new Map((statesResult.data as State[]).map((s) => [s.id, s]));

      for (const row of rows) {
        const state = statesMap.get(row.id);
        if (!state) continue;

        const [allInstances, summary] = await Promise.all([
          getAllStateInstances(row.id),
          getStateSummary(row.id),
        ]);

        const stateFile = constructTerraformState(
          state,
          allInstances,
          summary
        );

        const json = JSON.stringify(stateFile, null, 2);
        const blob = new Blob([json], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `${row.name}.tfstate`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    } catch (e) {
      console.error("[StatesPage] Download error:", e);
    } finally {
      setDownloading(false);
    }
  };

  // Handle row click
  const handleRowClick = (row: StateTableRow) => {
    router.push(`/states/detail?id=${row.id}`);
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
      <PageHeader
        title="States"
        subtitle="Browse Terraform state files"
      >
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={loadData}
            disabled={loading}
          >
            <RefreshCw
              className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`}
            />
            Refresh
          </Button>
        </div>
      </PageHeader>

      {/* Bulk action bar */}
      {selectedIds.size > 0 && (
        <div className="flex-shrink-0 px-6 py-2 border-b border-[var(--sg-border)] bg-[var(--sg-accent)]/5">
          <div className="flex items-center gap-3 flex-wrap">
            <span className="text-sm font-medium text-[var(--sg-text)]">
              {selectedIds.size} selected
            </span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleDownload(selectedRows)}
              disabled={downloading}
            >
              <Download className="h-3.5 w-3.5 mr-1.5" />
              {downloading ? "Downloading..." : "Download"}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => openDeleteDialog(selectedRows)}
              className="text-[var(--sg-error)] border-[var(--sg-error)]/30 hover:bg-[var(--sg-error)]/10"
            >
              <Trash2 className="h-3.5 w-3.5 mr-1.5" />
              Delete
            </Button>
            <button
              onClick={() => setSelectedIds(new Set())}
              className="text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors ml-auto"
            >
              Clear selection
            </button>
          </div>
        </div>
      )}

      {/* Stats Bar */}
      {!loading && tableRows.length > 0 && selectedIds.size === 0 && (
        <div className="flex-shrink-0 px-6 py-3 border-b border-[var(--sg-border)] bg-[var(--sg-bg-0)]">
          <div className="flex items-center gap-4 flex-wrap gap-y-1 sg-metadata text-[var(--sg-text-dim)]">
            <div>
              <span className="font-semibold text-[var(--sg-text)]">
                {tableRows.length.toLocaleString()}
              </span>{" "}
              states
            </div>
            <div className="text-[var(--sg-text-dim)]">·</div>
            <div>
              <span className="font-semibold text-[var(--sg-text)]">
                {tableRows
                  .reduce((sum, row) => sum + row.resourceCount, 0)
                  .toLocaleString()}
              </span>{" "}
              total resources
            </div>
            {costSupported && totalMonthly !== null && (
              <>
                <div className="text-[var(--sg-text-dim)]">·</div>
                <div>
                  <span className="font-semibold text-[var(--sg-text)] font-mono">
                    {formatCurrency(totalMonthly, costCurrency)}
                  </span>{" "}
                  /mo
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="mx-6 mt-4 p-4 bg-[var(--sg-error)]/10 border border-[var(--sg-error)] rounded-lg">
          <div className="sg-secondary-header text-[var(--sg-error)] mb-1">
            Failed to load states
          </div>
          <div className="sg-metadata text-[var(--sg-error)]">{error}</div>
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-6 py-4">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-[var(--sg-text-muted)]">Loading states...</div>
          </div>
        ) : tableRows.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12">
            <div className="text-[var(--sg-text-muted)] text-center max-w-md">
              <div className="text-lg font-semibold mb-2">No States Found</div>
              <div className="text-sm mb-4">
                This tenant has no Terraform states yet.
              </div>
            </div>
          </div>
        ) : (
          <>
          {/* Desktop: full table */}
          <div className="hidden lg:block rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-10">
                    <input
                      type="checkbox"
                      checked={selectedIds.size === sortedRows.length && sortedRows.length > 0}
                      onChange={toggleSelectAll}
                      className="accent-[var(--sg-accent)] cursor-pointer"
                    />
                  </TableHead>
                  <TableHead>
                    <button
                      onClick={() => handleSort("name")}
                      className="flex items-center gap-1 hover:text-[var(--sg-text)] transition-colors"
                    >
                      State name
                      {sortColumn === "name" && (
                        <ArrowUpDown className="h-3 w-3" />
                      )}
                    </button>
                  </TableHead>
                  <TableHead>Workspace</TableHead>
                  <TableHead>Group</TableHead>
                  <TableHead>
                    <button
                      onClick={() => handleSort("resourceCount")}
                      className="flex items-center gap-1 hover:text-[var(--sg-text)] transition-colors"
                    >
                      Resource count
                      {sortColumn === "resourceCount" && (
                        <ArrowUpDown className="h-3 w-3" />
                      )}
                    </button>
                  </TableHead>
                  <TableHead>
                    <button
                      onClick={() => handleSort("lastTransaction")}
                      className="flex items-center gap-1 hover:text-[var(--sg-text)] transition-colors"
                    >
                      Last transaction
                      {sortColumn === "lastTransaction" && (
                        <ArrowUpDown className="h-3 w-3" />
                      )}
                    </button>
                  </TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Blast radius</TableHead>
                  {costSupported && <TableHead>Monthly cost</TableHead>}
                  {costSupported && <TableHead>Coverage</TableHead>}
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {sortedRows.map((row) => {
                  const cost = costByState.get(row.id);
                  const monthly = parseCost(cost?.monthly_cost);
                  return (
                  <TableRow
                    key={row.id}
                    onClick={() => handleRowClick(row)}
                    className={`cursor-pointer hover:bg-[var(--sg-bg-2)] transition-colors ${selectedIds.has(row.id) ? "bg-[var(--sg-accent)]/5" : ""}`}
                  >
                    <TableCell onClick={(e) => toggleSelect(row.id, e)}>
                      <input
                        type="checkbox"
                        checked={selectedIds.has(row.id)}
                        readOnly
                        className="accent-[var(--sg-accent)] cursor-pointer"
                      />
                    </TableCell>
                    <TableCell className="font-medium">{row.name}</TableCell>
                    <TableCell className="text-[var(--sg-text-dim)] font-mono text-xs">
                      {row.workspace}
                    </TableCell>
                    <TableCell className="text-[var(--sg-text-dim)] font-mono text-xs">
                      {row.groupId}
                    </TableCell>
                    <TableCell className="text-[var(--sg-text)] font-mono tabular-nums">
                      {row.resourceCount.toLocaleString()}
                    </TableCell>
                    <TableCell className="text-[var(--sg-text-dim)]">
                      {row.lastTransaction ? (
                        <div className="flex flex-col">
                          <span className="text-[var(--sg-text)]">
                            {row.lastTransaction.type}
                          </span>
                          <span className="text-xs">
                            {row.lastTransaction.relativeTime}
                          </span>
                        </div>
                      ) : (
                        <span className="text-xs">No recorded activity</span>
                      )}
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={row.status} />
                    </TableCell>
                    <TableCell className="text-[var(--sg-text-dim)]">
                      <div className="flex flex-col">
                        <span className="text-[var(--sg-text)]">
                          {row.blastRadius.size}
                        </span>
                        <span className="text-xs">
                          {row.blastRadius.count} edges
                        </span>
                      </div>
                    </TableCell>
                    {costSupported && (
                      <TableCell
                        className="font-mono text-xs"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {monthly !== null ? (
                          <DeepLink
                            href={`/cost-analysis?state=${row.id}`}
                            className="text-[var(--sg-accent)] hover:underline"
                          >
                            {formatCurrency(monthly, costCurrency)}
                          </DeepLink>
                        ) : (
                          <span className="text-[var(--sg-text-dim)]">—</span>
                        )}
                      </TableCell>
                    )}
                    {costSupported && (
                      <TableCell className="font-mono text-xs text-[var(--sg-text-dim)]">
                        {monthly !== null && typeof cost?.coverage_percent === "number"
                          ? `${cost.coverage_percent.toFixed(0)}%`
                          : "—"}
                      </TableCell>
                    )}
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center gap-3">
                        <DeepLink
                          href={`/states/inspect?id=${row.id}`}
                          className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
                        >
                          <FileJson className="h-3 w-3" />
                          Inspect
                        </DeepLink>
                        <button
                          onClick={() => handleDownload([row])}
                          className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
                        >
                          <Download className="h-3 w-3" />
                          Download
                        </button>
                        <button
                          onClick={() => openDeleteDialog([row])}
                          className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-error)] transition-colors"
                        >
                          <Trash2 className="h-3 w-3" />
                          Delete
                        </button>
                      </div>
                    </TableCell>
                  </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>

          {/* Mobile/tablet: stacked cards (same rows + handlers as the table) */}
          <div className="lg:hidden space-y-3">
            {sortedRows.map((row) => {
              const cost = costByState.get(row.id);
              const monthly = parseCost(cost?.monthly_cost);
              return (
                <div
                  key={row.id}
                  onClick={() => handleRowClick(row)}
                  className={`rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-3 cursor-pointer hover:bg-[var(--sg-bg-2)] transition-colors ${selectedIds.has(row.id) ? "bg-[var(--sg-accent)]/5" : ""}`}
                >
                  <div className="flex items-start gap-2.5">
                    <input
                      type="checkbox"
                      checked={selectedIds.has(row.id)}
                      readOnly
                      onClick={(e) => toggleSelect(row.id, e)}
                      className="accent-[var(--sg-accent)] cursor-pointer mt-1 flex-shrink-0"
                    />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <span className="font-medium text-[var(--sg-text)] break-all min-w-0">
                          {row.name}
                        </span>
                        <StatusBadge status={row.status} className="flex-shrink-0" />
                      </div>

                      <dl className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1.5 text-xs">
                        <div className="min-w-0">
                          <dt className="text-[var(--sg-text-dim)]">Workspace</dt>
                          <dd className="font-mono text-[var(--sg-text)] break-all">
                            {row.workspace}
                          </dd>
                        </div>
                        <div className="min-w-0">
                          <dt className="text-[var(--sg-text-dim)]">Group</dt>
                          <dd className="font-mono text-[var(--sg-text)] break-all">
                            {row.groupId}
                          </dd>
                        </div>
                        <div className="min-w-0">
                          <dt className="text-[var(--sg-text-dim)]">Resources</dt>
                          <dd className="text-[var(--sg-text)]">
                            {row.resourceCount.toLocaleString()}
                          </dd>
                        </div>
                        <div className="min-w-0">
                          <dt className="text-[var(--sg-text-dim)]">Blast radius</dt>
                          <dd className="text-[var(--sg-text)]">
                            {row.blastRadius.size} · {row.blastRadius.count} edges
                          </dd>
                        </div>
                        <div className="min-w-0 col-span-2">
                          <dt className="text-[var(--sg-text-dim)]">Last transaction</dt>
                          <dd className="text-[var(--sg-text)]">
                            {row.lastTransaction
                              ? `${row.lastTransaction.type} · ${row.lastTransaction.relativeTime}`
                              : "No recorded activity"}
                          </dd>
                        </div>
                        {costSupported && (
                          <div className="min-w-0">
                            <dt className="text-[var(--sg-text-dim)]">Monthly cost</dt>
                            <dd
                              className="font-mono text-[var(--sg-text)]"
                              onClick={(e) => e.stopPropagation()}
                            >
                              {monthly !== null ? (
                                <DeepLink
                                  href={`/cost-analysis?state=${row.id}`}
                                  className="text-[var(--sg-accent)] hover:underline"
                                >
                                  {formatCurrency(monthly, costCurrency)}
                                </DeepLink>
                              ) : (
                                <span className="text-[var(--sg-text-dim)]">—</span>
                              )}
                            </dd>
                          </div>
                        )}
                        {costSupported && (
                          <div className="min-w-0">
                            <dt className="text-[var(--sg-text-dim)]">Coverage</dt>
                            <dd className="font-mono text-[var(--sg-text-dim)]">
                              {monthly !== null && typeof cost?.coverage_percent === "number"
                                ? `${cost.coverage_percent.toFixed(0)}%`
                                : "—"}
                            </dd>
                          </div>
                        )}
                      </dl>

                      <div
                        className="mt-3 flex items-center gap-4 flex-wrap"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <DeepLink
                          href={`/states/inspect?id=${row.id}`}
                          className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
                        >
                          <FileJson className="h-3 w-3" />
                          Inspect
                        </DeepLink>
                        <button
                          onClick={() => handleDownload([row])}
                          className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-text)] transition-colors"
                        >
                          <Download className="h-3 w-3" />
                          Download
                        </button>
                        <button
                          onClick={() => openDeleteDialog([row])}
                          className="inline-flex items-center gap-1 text-xs text-[var(--sg-text-dim)] hover:text-[var(--sg-error)] transition-colors"
                        >
                          <Trash2 className="h-3 w-3" />
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
          </>
        )}
      </div>

      {/* Delete confirmation dialog */}
      <Dialog open={deleteTargets.length > 0} onOpenChange={(open) => { if (!open) setDeleteTargets([]); }}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>
              Delete {deleteTargets.length === 1 ? "state" : `${deleteTargets.length} states`}
            </DialogTitle>
            <DialogDescription>
              {deleteTargets.length === 1 ? (
                <>
                  This action cannot be easily undone. Type{" "}
                  <span className="font-mono font-semibold text-[var(--sg-text)]">{deleteTargets[0].name}</span>{" "}
                  to confirm.
                </>
              ) : (
                <>
                  This will delete {deleteTargets.length} states:{" "}
                  {deleteTargets.map((t) => t.name).join(", ")}.
                  Type{" "}
                  <span className="font-mono font-semibold text-[var(--sg-text)]">{deletePromptText}</span>{" "}
                  to confirm.
                </>
              )}
            </DialogDescription>
          </DialogHeader>

          <div className="flex flex-col gap-4">
            <input
              type="text"
              value={deleteConfirmText}
              onChange={(e) => setDeleteConfirmText(e.target.value)}
              placeholder={`Type "${deletePromptText}" to confirm`}
              className="w-full px-3 py-2 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-0)] text-[var(--sg-text)] text-sm placeholder:text-[var(--sg-text-dim)] focus:outline-none focus:ring-1 focus:ring-[var(--sg-accent)]"
              autoFocus
            />

            {deleteError && (
              <div className="p-2 rounded text-sm bg-[var(--sg-error)]/10 text-[var(--sg-error)] border border-[var(--sg-error)]">
                {deleteError}
              </div>
            )}
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setDeleteTargets([])}
              disabled={deleting}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              size="sm"
              onClick={handleDeleteConfirm}
              disabled={!deleteConfirmed || deleting}
            >
              {deleting
                ? "Deleting..."
                : `Delete${deleteTargets.length > 1 ? ` ${deleteTargets.length} states` : " state"}`}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default function StatesPage() {
  return (
    <AuthGuard>
      <StatesPageContent />
    </AuthGuard>
  );
}
